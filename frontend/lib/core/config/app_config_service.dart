import 'dart:convert';

import 'package:flutter/services.dart';

class AppConfigService {
  AppConfigService._();

  static const String _configAssetPath = 'assets/config/app_config.json';
  static Map<String, dynamic> _config = const <String, dynamic>{};
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) {
      return;
    }
    try {
      final raw = await rootBundle.loadString(_configAssetPath);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _config = decoded;
      }
    } catch (e) {
      print(
        '[AppConfig] Failed to load $_configAssetPath. '
        'Falling back to empty config. Error: $e',
      );
    } finally {
      _loaded = true;
    }
  }

  static String get revenueCatPublicKeyAndroid {
    final value = _config['REVENUECAT_PUBLIC_KEY_ANDROID'];
    return value?.toString().trim() ?? '';
  }
}
