import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:purchases_flutter/purchases_flutter.dart';

import 'revenuecat_service.dart';

/// Android Google Play 订阅 **升级 / 降级 / 换套餐** 时必须带上「从哪个旧 SKU 替换」以及 Proration，
/// 否则 Play 会拒绝并可能出现 “unable to change your subscription plan”。
///
/// RevenueCat 侧通过 [PurchaseParams.package] 的 [GoogleProductChangeInfo] 传入
/// `googleOldProductIdentifier`（对应 Play 侧基于当前订阅解析 purchase token，无需手写 token）。
class RevenueCatPurchaseHelper {
  RevenueCatPurchaseHelper._();

  /// 若用户已有生效订阅且目标 SKU 与当前不同，则构造换购参数；否则返回 null（首次订阅）。
  static GoogleProductChangeInfo? googleProductChangeInfoIfNeeded({
    required CustomerInfo customerInfo,
    required Package package,
  }) {
    if (kIsWeb || !Platform.isAndroid) {
      return null;
    }
    final targetProductId = package.storeProduct.identifier;
    final oldProductId = _resolveOldSubscriptionProductId(
      customerInfo,
      targetProductId,
    );
    if (oldProductId == null || oldProductId.isEmpty) {
      return null;
    }
    return GoogleProductChangeInfo(
      oldProductId,
      prorationMode: GoogleProrationMode.immediateWithTimeProration,
    );
  }

  /// 优先使用 `pro` entitlement 对应的商品 ID（与后台解锁权限的 SKU 一致），否则使用 [CustomerInfo.activeSubscriptions]。
  static String? _resolveOldSubscriptionProductId(
    CustomerInfo info,
    String targetProductId,
  ) {
    final proEntitlement = info.entitlements.all['pro'];
    if (proEntitlement != null &&
        proEntitlement.isActive &&
        proEntitlement.productIdentifier.isNotEmpty &&
        proEntitlement.productIdentifier != targetProductId) {
      return proEntitlement.productIdentifier;
    }

    for (final id in info.activeSubscriptions) {
      if (id.isNotEmpty && id != targetProductId) {
        return id;
      }
    }
    return null;
  }

  /// 使用 [Purchases.purchase] + 可选 [GoogleProductChangeInfo]，替换原先直接调用封装购买 API 的路径。
  static Future<PurchaseResult> purchasePackage(Package package) async {
    await RevenueCatService.ensureInitialized();
    final customerInfo = await Purchases.getCustomerInfo();
    final change = googleProductChangeInfoIfNeeded(
      customerInfo: customerInfo,
      package: package,
    );
    if (kDebugMode) {
      if (change != null) {
        debugPrint(
          '[RevenueCat] Play subscription update: oldProductId=${change.oldProductIdentifier} '
          '-> new=${package.storeProduct.identifier} '
          'proration=${change.prorationMode}',
        );
      } else {
        debugPrint(
          '[RevenueCat] Play purchase (new or same SKU): ${package.storeProduct.identifier}',
        );
      }
    }
    return Purchases.purchase(
      PurchaseParams.package(
        package,
        googleProductChangeInfo: change,
      ),
    );
  }
}
