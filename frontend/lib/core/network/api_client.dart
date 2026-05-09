import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart'; // 🌟 引入 UI 库
import 'package:flutter/foundation.dart' show debugPrint;
import '../../main.dart'; // 🌟 引入全局钥匙
import '../../screens/login_screen.dart'; // 🌟 引入登录页
import '../../l10n/app_localizations.dart'; // 👈 新增这行
import '../auth/token_manager.dart';

const String _kApiBaseUrl = 'https://api.dothings.one/api/v1';

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

class FinanceResult {
  final double? projectIrr;
  final double? projectNpv;
  final double? projectPaybackYears;
  final double? equityIrr;
  final double? equityNpv;
  final double? equityPaybackYears;
  final List<Map<String, dynamic>> cashFlowStatement;

  const FinanceResult({
    required this.projectIrr,
    required this.projectNpv,
    required this.projectPaybackYears,
    required this.equityIrr,
    required this.equityNpv,
    required this.equityPaybackYears,
    required this.cashFlowStatement,
  });

  factory FinanceResult.fromJson(Map<String, dynamic> json) {
    final statement = (json['cash_flow_statement'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList();
    final projectIrr = (json['project_irr'] as num?)?.toDouble() ?? (json['irr'] as num?)?.toDouble();
    final projectNpv = (json['project_npv'] as num?)?.toDouble() ?? (json['npv'] as num?)?.toDouble();
    final projectPayback = (json['project_payback_years'] as num?)?.toDouble() ??
        (json['payback_period_years'] as num?)?.toDouble();
    return FinanceResult(
      projectIrr: projectIrr,
      projectNpv: projectNpv,
      projectPaybackYears: projectPayback,
      // Backward compatibility: if backend still returns old single-set KPIs,
      // keep Equity card populated instead of showing blanks.
      equityIrr: (json['equity_irr'] as num?)?.toDouble() ?? projectIrr,
      equityNpv: (json['equity_npv'] as num?)?.toDouble() ?? projectNpv,
      equityPaybackYears: (json['equity_payback_years'] as num?)?.toDouble() ?? projectPayback,
      cashFlowStatement: statement,
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
    debugPrint(message);
    print(message);
  }

  void _sanitizeSimulationPayload(RequestOptions options) {
    final path = options.path.toLowerCase();
    if (!path.contains('/simulate')) {
      return;
    }
    final data = options.data;
    if (data is! Map) {
      return;
    }

    final root = data.cast<dynamic, dynamic>();
    final physicsParamsRaw = root['physics_params'];
    final financialParamsRaw = root['financial_params'];
    if (physicsParamsRaw is! Map || financialParamsRaw is! Map) {
      return;
    }

    final physicsParams = physicsParamsRaw.cast<dynamic, dynamic>();
    final financialParams = financialParamsRaw.cast<dynamic, dynamic>();
    final envRaw = physicsParams['env'];
    if (envRaw is! Map) {
      return;
    }
    final env = envRaw.cast<dynamic, dynamic>();

    // Hard guardrail: disable VoLL and outage assumptions before /simulate request.
    financialParams['voll_price'] = 0.0;
    env['grid_status_8760'] = List<int>.filled(8760, 1);
    _debugLog(
      '[SIM-GUARD] force financial_params.voll_price=0.0, '
      'physics_params.env.grid_status_8760=List.filled(8760,1)',
    );
  }

  ApiClient._internal() {
    // 2. 统一基础配置 (Base URL)
    BaseOptions options = BaseOptions(
      // 可由 --dart-define=API_BASE_URL 覆盖。
      // Android 模拟器本地后端可用 http://10.0.2.2:8000/api/v1
      // 真机可用 http://<你的局域网IP>:8000/api/v1
      baseUrl: _kApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    );

    dio = Dio(options);
    _debugLog('[ApiClient] baseUrl=${dio.options.baseUrl}');
    bool isAuthEndpoint(String path) {
      final normalized = path.toLowerCase();
      return normalized.contains('/auth/') || normalized.startsWith('auth/');
    }


    final l10n = AppLocalizations.of(globalNavigatorKey.currentContext!)!;


    // 3. 🌟 核心魔法：全局拦截器 (Interceptor)
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        _sanitizeSimulationPayload(options);
        _debugLog(
          '[HTTP] ${options.method} ${options.baseUrl}${options.path}',
        );
        // 登录态同步接口（仅 Firebase 同步）不需要已有 Token
        final p = options.path.toLowerCase();
        if (p.contains('/auth/firebase')) {
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
        _debugLog(
          '[HTTP-ERR] ${e.requestOptions.method} ${e.requestOptions.baseUrl}${e.requestOptions.path} '
          'status=${e.response?.statusCode} detail=${e.response?.data}',
        );
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

  /// Email/Google/Microsoft：将 Firebase ID token 同步到后端账号体系。
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

  /// Dev only: backend signs a real JWT for local testing.
  Future<Map<String, dynamic>> devLogin({
    required String email,
    required String firebaseUid,
    required String tier,
    required String proExpireDate,
    required bool isActive,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/dev-login',
      data: {
        'email': email,
        'firebase_uid': firebaseUid,
        'tier': tier,
        'pro_expire_date': proExpireDate,
        'is_active': isActive,
      },
    );
    return response.data ?? const {};
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

  Future<ProjectCalculationItem> updateProjectCalculation({
    required String projectId,
    required String calculationId,
    required String versionName,
    required Map<String, dynamic> parameters,
    required Map<String, dynamic> results,
  }) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '/projects/$projectId/calculations/$calculationId',
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