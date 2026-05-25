import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// ═══════════════════════════════════════════════════════════════
// RevenueCatService — subscriptions & entitlements
// ═══════════════════════════════════════════════════════════════

class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  static const androidApiKey = 'YOUR_ANDROID_REVENUECAT_API_KEY';
  static const iosApiKey = 'YOUR_IOS_REVENUECAT_API_KEY';
  static const premiumEntitlementId = 'premium';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) return;

    await Purchases.setLogLevel(LogLevel.error); // Silenced for emulator

    final apiKey = Platform.isAndroid ? androidApiKey : iosApiKey;
    await Purchases.configure(PurchasesConfiguration(apiKey));
    _initialized = true;
  }

  Future<Offerings?> fetchOfferings() async {
    await initialize();
    return Purchases.getOfferings();
  }

  Future<CustomerInfo> purchasePackage(Package package) async {
    await initialize();
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo;
  }

  Future<CustomerInfo> restorePurchases() async {
    await initialize();
    return Purchases.restorePurchases();
  }

  Future<CustomerInfo?> getCustomerInfo() async {
    await initialize();
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      debugPrint('RevenueCat getCustomerInfo failed: $e');
      return null;
    }
  }

  bool isPremiumActive(CustomerInfo info) {
    final entitlement = info.entitlements.all[premiumEntitlementId];
    if (entitlement?.isActive == true) return true;
    return info.entitlements.active.isNotEmpty;
  }
}
