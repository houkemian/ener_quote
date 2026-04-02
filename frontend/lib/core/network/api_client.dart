import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart'; // 🌟 引入 UI 库
import '../../main.dart'; // 🌟 引入全局钥匙
import '../../screens/login_screen.dart'; // 🌟 引入登录页
import '../../l10n/app_localizations.dart'; // 👈 新增这行

class ApiClient {
  // 1. 单例模式：确保全局只生成一个 ApiClient 实例
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio dio;

  ApiClient._internal() {
    // 2. 统一基础配置 (Base URL)
    BaseOptions options = BaseOptions(
      // 🌟 统一切换开关：
      // 模拟器用：http://10.0.2.2:8000/api/v1
      // 真机用：http://192.168.x.x:8000/api/v1 (你的电脑局域网 IP)
      // baseUrl: 'http://10.1.50.211:8000/api/v1',
      // 🌟 核心修改：枪口一致对外，直连 AWS 生产服务器！
      baseUrl: 'https://dothings.one/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    );

    dio = Dio(options);

    final l10n = AppLocalizations.of(globalNavigatorKey.currentContext!)!;


    // 3. 🌟 核心魔法：全局拦截器 (Interceptor)
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 如果是登录接口，不需要 Token，直接放行
        if (options.path.contains('/auth/login')) {
          print("/auth/login");
          return handler.next(options);
        }

        // ⚠️ 其他所有接口：自动去本地掏出 Token，悄悄塞进请求头！
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwt_token');

        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        // 放行请求，带着 Token 飞向后端
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // 🌟 全局 401 拦截：Token 过期或被篡改，自动踢回登录页！
        if (e.response?.statusCode == 401) {
          print("🔒 [全局拦截] Token 无效或已过期！强制登出...");


          // 1. 彻底撕毁本地所有缓存
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('jwt_token');
          await prefs.remove('user_tier');

          // 2. 使用万能钥匙跨层级操作 UI
          if (globalNavigatorKey.currentContext != null) {
            // 弹出无情警告
            ScaffoldMessenger.of(globalNavigatorKey.currentContext!).showSnackBar(
              SnackBar(
                content: Text(l10n.sessionExpired),
                backgroundColor: Colors.redAccent,
              ),
            );
            // 摧毁所有历史路由，强制押送回登录页
            globalNavigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
            );
          }
        }
        return handler.next(e);
      },
    ));
  }

  // 🌟 呼叫云端印钞机：获取 Stripe 专属支付链接
  Future<String?> getStripeCheckoutUrl() async {
    try {
      // 这里的 dio 就是你代码里已经初始化的那个实例
      final response = await dio.post('/payment/checkout');
      if (response.statusCode == 200 && response.data != null) {
        return response.data['checkout_url']; // 拿到那条神圣的 URL
      }
      return null;
    } catch (e) {
      print("❌ 获取支付链接失败: $e");
      rethrow;
    }
  }
// 🌟 刷新本地门禁卡
  Future<String?> refreshUserToken() async {
    try {
      final response = await dio.post('/auth/refresh');
      if (response.statusCode == 200) {
        final newToken = response.data['access_token'];
        final newTier = response.data['tier'];

        // 瞬间替换本地缓存，完成无感升级
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', newToken);
        await prefs.setString('user_tier', newTier);

        return newTier;
      }
      return null;
    } catch (e) {
      print("❌ Token 刷新失败: $e");
      return null;
    }
  }

  // 🌟 动态拉取云端城市列表
  Future<List<dynamic>> getSupportedCities() async {
    try {
      final response = await dio.get('/locations/cities');
      return response.data as List<dynamic>;
    } catch (e) {
      print("❌ 获取城市列表失败: $e");
      return [];
    }
  }

  // 请求重置密码验证码
  Future<bool> requestPasswordReset(String email, String langCode) async {

    try {
      await dio.post('/auth/forgot-password', data: {"email": email, "language":langCode});
      return true; // 不管后端返回什么，前端都展示发送成功
    } catch (e) {
      print("发送验证码失败: $e");
      return false;
    }
  }

  // 提交新密码
  Future<bool> resetPassword(String email, String code, String newPassword) async {
    try {
      final response = await dio.post('/auth/reset-password', data: {
        "email": email,
        "reset_code": code,
        "new_password": newPassword
      });
      return response.statusCode == 200;
    } catch (e) {
      print("重置密码失败: $e");
      return false;
    }
  }

}