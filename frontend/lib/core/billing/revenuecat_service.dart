import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  RevenueCatService._();

  static const String _androidPublicKey = String.fromEnvironment(
    'REVENUECAT_PUBLIC_KEY_ANDROID',
    defaultValue: '',
  );

  static String? _lastConfiguredUserId;

  static bool get _canUseRevenueCat =>
      !kIsWeb && Platform.isAndroid && _androidPublicKey.trim().isNotEmpty;

  static Future<void> initializeFromJwt(String? token) async {
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
    if (normalizedUserId.isEmpty || !_canUseRevenueCat) {
      return;
    }
    if (_lastConfiguredUserId == normalizedUserId) {
      return;
    }

    try {
      final configuration = PurchasesConfiguration(_androidPublicKey)
        ..appUserID = normalizedUserId;
      await Purchases.configure(configuration);
      _lastConfiguredUserId = normalizedUserId;
    } on PlatformException catch (e) {
      final code = e.code.toLowerCase();
      if (code.contains('configured')) {
        await Purchases.logIn(normalizedUserId);
        _lastConfiguredUserId = normalizedUserId;
        return;
      }
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
