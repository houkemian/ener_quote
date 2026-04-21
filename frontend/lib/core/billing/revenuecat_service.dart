import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/app_config_service.dart';

class RevenueCatService {
  RevenueCatService._();

  static String? _lastConfiguredUserId;
  static bool _isConfigured = false;

  static bool get _canUseRevenueCat =>
      !kIsWeb &&
      Platform.isAndroid &&
      AppConfigService.revenueCatPublicKeyAndroid.isNotEmpty;

  static Future<void> ensureInitialized() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    final publicKey = AppConfigService.revenueCatPublicKeyAndroid;
    if (publicKey.isEmpty) {
      if (kDebugMode) {
        debugPrint('[RevenueCat] Android public key is empty, skip configure.');
      }
      return;
    }
    if (_isConfigured) {
      return;
    }
    await Purchases.setLogLevel(LogLevel.debug);
    try {
      final configuration = PurchasesConfiguration(publicKey);
      await Purchases.configure(configuration);
      _isConfigured = true;
    } on PlatformException catch (e) {
      final code = e.code.toLowerCase();
      if (code.contains('configured')) {
        _isConfigured = true;
        return;
      }
      rethrow;
    }
  }

  static Future<void> initializeFromJwt(String? token) async {
    await ensureInitialized();
    if (token == null || token.trim().isEmpty) {
      return;
    }
    final appUserId = _extractUserIdFromJwt(token);
    if (appUserId == null || appUserId.isEmpty) {
      return;
    }
    await initializeForAppUser(appUserId);
  }

  static Future<void> initializeForAppUser(String appUserId) async {
    final normalizedUserId = appUserId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }
    await ensureInitialized();
    if (!_canUseRevenueCat) {
      return;
    }
    if (_lastConfiguredUserId == normalizedUserId) {
      return;
    }

    try {
      await Purchases.logIn(normalizedUserId);
      _lastConfiguredUserId = normalizedUserId;
    } on PlatformException {
      rethrow;
    }
  }

  static String? _extractUserIdFromJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final payloadMap = jsonDecode(payload);
      if (payloadMap is Map<String, dynamic>) {
        final sub = payloadMap['sub']?.toString().trim();
        if (sub != null && sub.isNotEmpty) {
          return sub;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
