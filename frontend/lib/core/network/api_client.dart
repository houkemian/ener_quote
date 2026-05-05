import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart'; // 🌟 引入 UI 库
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../../main.dart'; // 🌟 引入全局钥匙
import '../../screens/login_screen.dart'; // 🌟 引入登录页
import '../../l10n/app_localizations.dart'; // 👈 新增这行
import '../auth/token_manager.dart';

class SendOtpResponse {
  final int ttlSeconds;
  const SendOtpResponse({required this.ttlSeconds});
}

class VerifyOtpRegisterResponse {
  final String accessToken;
  final String? tier;
  const VerifyOtpRegisterResponse({required this.accessToken, this.tier});
}

class ProjectItem {
  final String id;
  final String userId;
  final String projectName;
  final String? clientName;
  final String? location;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectItem({
    required this.id,
    required this.userId,
    required this.projectName,
    required this.clientName,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectItem.fromJson(Map<String, dynamic> json) {
    return ProjectItem(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      projectName: json['project_name'] as String? ?? '',
      clientName: json['client_name'] as String?,
      location: json['location'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ProjectCalculationItem {
  final String id;
  final String projectId;
  final String versionName;
  final Map<String, dynamic> parameters;
  final Map<String, dynamic> results;
  final DateTime createdAt;

  const ProjectCalculationItem({
    required this.id,
    required this.projectId,
    required this.versionName,
    required this.parameters,
    required this.results,
    required this.createdAt,
  });

  factory ProjectCalculationItem.fromJson(Map<String, dynamic> json) {
    return ProjectCalculationItem(
      id: json['id'] as String,
      projectId: json['project_id'] as String? ?? '',
      versionName: json['version_name'] as String? ?? '',
      parameters: (json['parameters'] as Map?)?.cast<String, dynamic>() ?? const {},
      results: (json['results'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class PaywallGateException implements Exception {
  final String message;
  const PaywallGateException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  // 1. 单例模式：确保全局只生成一个 ApiClient 实例
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio dio;

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  ApiClient._internal() {
    // 2. 统一基础配置 (Base URL)
    BaseOptions options = BaseOptions(
      // 🌟 统一切换开关：
      // 模拟器用：http://10.0.2.2:8000/api/v1
      // 真机用：http://192.168.x.x:8000/api/v1 (你的电脑局域网 IP)
      // baseUrl: 'http://10.1.50.211:8000/api/v1',
      // 🌟 核心修改：枪口一致对外，直连 API 子域
      baseUrl: 'https://api.dothings.one/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    );

    dio = Dio(options);
    bool isAuthEndpoint(String path) {
      final normalized = path.toLowerCase();
      return normalized.contains('/auth/') || normalized.startsWith('auth/');
    }


    final l10n = AppLocalizations.of(globalNavigatorKey.currentContext!)!;


    // 3. 🌟 核心魔法：全局拦截器 (Interceptor)
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 登录态同步接口不需要已有 Token
        final p = options.path.toLowerCase();
        if (p.contains('/auth/login') || p.contains('/auth/firebase')) {
          return handler.next(options);
        }

        // ⚠️ 其他所有接口：自动去本地掏出 Token，悄悄塞进请求头！
        final token = await TokenManager.getAccessToken();

        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        // 放行请求，带着 Token 飞向后端
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // 🌟 全局 401 拦截：Token 过期或被篡改，自动踢回登录页！
        final path = e.requestOptions.path;
        final hasAuthHeader = e.requestOptions.headers.keys.any(
          (key) => key.toString().toLowerCase() == 'authorization',
        );
        if (e.response?.statusCode == 401 &&
            hasAuthHeader &&
            !isAuthEndpoint(path)) {
          _debugLog("Auth token expired, forcing logout.");


          // 1. 彻底撕毁本地所有缓存
          await TokenManager.clearAccessToken();
          final prefs = await SharedPreferences.getInstance();
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

  /// Paddle Billing：创建交易并返回托管结账页 URL（后端字段仍为 `checkout_url`）。
  Future<String?> getPaddleCheckoutUrl() async {
    try {
      final response = await dio.post('/payment/checkout');
      if (response.statusCode == 200 && response.data != null) {
        return response.data['checkout_url'] as String?;
      }
      return null;
    } catch (e) {
      _debugLog("Failed to fetch checkout URL.");
      rethrow;
    }
  }
// 🌟 Firebase token 无需后端 refresh；改为拉取最新 tier
  Future<String?> refreshUserToken() async {
    try {
      final response = await dio.get('/settings/me');
      if (response.statusCode == 200) {
        final newTier = response.data['tier'] as String?;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_tier', newTier ?? 'FREE');

        return newTier;
      }
      return null;
    } catch (e) {
      _debugLog("Failed to refresh user token.");
      return null;
    }
  }

  /// 支付完成后短轮询刷新权限，避免 webhook 落库稍有延迟导致误判 pending。
  Future<String?> refreshUserTierWithRetry({
    int maxAttempts = 6,
    Duration retryInterval = const Duration(seconds: 2),
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      final tier = await refreshUserToken();
      if (tier == "PRO") {
        return tier;
      }
      if (i < maxAttempts - 1) {
        await Future.delayed(retryInterval);
      }
    }
    return "FREE";
  }

  // 🌟 动态拉取云端城市列表
  Future<List<dynamic>> getSupportedCities() async {
    try {
      final response = await dio.get('/locations/cities');
      return response.data as List<dynamic>;
    } catch (e) {
      _debugLog("Failed to fetch city list.");
      return [];
    }
  }

  // 请求重置密码验证码
  Future<bool> requestPasswordReset(String email, String langCode) async {

    try {
      await dio.post('/auth/forgot-password', data: {"email": email, "language":langCode});
      return true; // 不管后端返回什么，前端都展示发送成功
    } catch (e) {
      _debugLog("Failed to request password reset.");
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
      _debugLog("Failed to reset password.");
      return false;
    }
  }

  Future<SendOtpResponse> sendRegisterOtp(String email, String langCode) async {
    final response = await dio.post(
      '/auth/send-otp',
      data: {
        "email": email,
        "language": langCode,
      },
    );
    final ttl = response.data is Map<String, dynamic>
        ? (response.data['ttl_seconds'] as int? ?? 300)
        : 300;
    return SendOtpResponse(ttlSeconds: ttl);
  }

  Future<VerifyOtpRegisterResponse> verifyOtpAndRegister({
    required String email,
    required String password,
    required String otpCode,
  }) async {
    final response = await dio.post(
      '/auth/verify-otp-and-register',
      data: {
        "email": email,
        "password": password,
        "otp_code": otpCode,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return VerifyOtpRegisterResponse(
      accessToken: data['access_token'] as String,
      tier: data['tier'] as String?,
    );
  }

  /// Google / Microsoft：将 Firebase ID token 同步到后端账号体系。
  Future<Map<String, dynamic>> authenticateWithFirebaseIdToken({
    required String firebaseIdToken,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/firebase',
      data: {'firebase_id_token': firebaseIdToken},
    );
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        error: 'Empty Firebase auth response',
      );
    }
    return data;
  }

  Future<void> deleteAccount() async {
    await dio.delete('/auth/logout');
  }

  Future<List<ProjectItem>> getProjects() async {
    final response = await dio.get<List<dynamic>>('/projects');
    final list = response.data ?? const [];
    return list
        .whereType<Map>()
        .map((e) => ProjectItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<ProjectItem> createProject({
    required String projectName,
    String? clientName,
    String? location,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userTier = prefs.getString('user_tier') ?? 'FREE';
    if (userTier != 'PRO') {
      final projects = await getProjects();
      if (projects.length >= 2) {
        throw const PaywallGateException(
          "You've reached the free limit of 2 projects. Upgrade to Pro to manage your entire sales pipeline.",
        );
      }
    }
    final response = await dio.post<Map<String, dynamic>>(
      '/projects',
      data: {
        'project_name': projectName,
        'client_name': clientName,
        'location': location,
      },
    );
    return ProjectItem.fromJson(response.data ?? const {});
  }

  Future<ProjectItem> updateProject({
    required String projectId,
    String? projectName,
    String? clientName,
    String? location,
  }) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '/projects/$projectId',
      data: {
        if (projectName != null) 'project_name': projectName,
        if (clientName != null) 'client_name': clientName,
        if (location != null) 'location': location,
      },
    );
    return ProjectItem.fromJson(response.data ?? const {});
  }

  Future<List<ProjectCalculationItem>> getProjectCalculations(String projectId) async {
    final response = await dio.get<List<dynamic>>('/projects/$projectId/calculations');
    final list = response.data ?? const [];
    return list
        .whereType<Map>()
        .map((e) => ProjectCalculationItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<ProjectCalculationItem> createProjectCalculation({
    required String projectId,
    required String versionName,
    required Map<String, dynamic> parameters,
    required Map<String, dynamic> results,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/projects/$projectId/calculations',
      data: {
        'version_name': versionName,
        'parameters': parameters,
        'results': results,
      },
    );
    return ProjectCalculationItem.fromJson(response.data ?? const {});
  }

  Future<void> deleteProjectCalculation({
    required String projectId,
    required String calculationId,
  }) async {
    await dio.delete('/projects/$projectId/calculations/$calculationId');
  }

}