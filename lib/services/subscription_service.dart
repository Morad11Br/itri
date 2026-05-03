import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Singleton that wraps the RevenueCat SDK.
///
/// Lifecycle:
///   1. Call [configure] once at app startup (before runApp or right after).
///   2. Call [logIn] whenever a Supabase user signs in (links RevenueCat
///      anonymous user to your backend user ID).
///   3. Call [logOut] when the user signs out.
///
/// Entitlement identifier on RevenueCat dashboard: "Itri Pro"
/// Product identifiers: "itri_premium_yearly", "itri_premium_monthly"
class SubscriptionService {
  SubscriptionService._();
  static final instance = SubscriptionService._();

  static const _entitlement = 'Itri Pro';

  // Replace these with your actual platform API keys from the RevenueCat
  // dashboard (Project → API Keys). Both are set to the test key for now.
  static const _apiKeyIos = 'appl_XLxfVCkOrxUdRWGWYfgwHWzrjJc';
  static const _apiKeyAndroid = 'test_ZLAULtObRNQGESrdgyRpvTwjHuk';

  /// `true` when the current user has an active "Itri Pro" entitlement.
  final ValueNotifier<bool> isPro = ValueNotifier(false);

  bool get _isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isMacOS);

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Initialise the SDK. Call once from [main] after Supabase is ready.
  Future<void> configure() async {
    if (!_isSupported) return;

    if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);

    final apiKey = Platform.isAndroid ? _apiKeyAndroid : _apiKeyIos;
    await Purchases.configure(PurchasesConfiguration(apiKey));

    // Keep [isPro] in sync whenever the SDK receives updated CustomerInfo
    // (e.g. from a webhook, subscription renewal, or refund).
    Purchases.addCustomerInfoUpdateListener(_apply);

    await _refresh();
  }

  /// Link the RevenueCat anonymous user to the authenticated Supabase user.
  /// Call every time the user signs in.
  Future<void> logIn(String userId) async {
    if (!_isSupported) return;
    try {
      final result = await Purchases.logIn(userId);
      _apply(result.customerInfo);
    } catch (e) {
      if (kDebugMode) debugPrint('[RevenueCat] logIn error: $e');
    }
  }

  /// Unlink the user on sign-out.
  Future<void> logOut() async {
    if (!_isSupported) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      if (kDebugMode) debugPrint('[RevenueCat] logOut error: $e');
    }
    isPro.value = false;
  }

  // ── Purchases ────────────────────────────────────────────────────────────

  /// Fetch the current offerings configured on the RevenueCat dashboard.
  Future<Offerings> getOfferings() => Purchases.getOfferings();

  /// Purchase [package] and return updated [CustomerInfo].
  /// Throws [PurchasesErrorCode] on failure (except user cancellation).
  Future<CustomerInfo> purchasePackage(Package package) async {
    final info = await Purchases.purchasePackage(package);
    _apply(info);
    return info;
  }

  /// Restore previous purchases (required by App Store / Play Store rules).
  Future<CustomerInfo> restorePurchases() async {
    final info = await Purchases.restorePurchases();
    _apply(info);
    return info;
  }

  /// Latest cached [CustomerInfo] from RevenueCat.
  Future<CustomerInfo> getCustomerInfo() => Purchases.getCustomerInfo();

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<void> _refresh() async {
    try {
      _apply(await Purchases.getCustomerInfo());
    } catch (e) {
      if (kDebugMode) debugPrint('[RevenueCat] status refresh error: $e');
    }
  }

  void _apply(CustomerInfo info) {
    isPro.value = info.entitlements.active.containsKey(_entitlement);
  }
}
