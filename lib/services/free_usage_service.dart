import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks free premium usage for non-Pro users.
///
/// Each feature starts with [kTotalFreeUses] credits. Once exhausted,
/// the user must upgrade to Pro to continue using that feature.
/// Credits are stored locally via SharedPreferences so they survive
/// app restarts and work in offline mode.
class FreeUsageService {
  FreeUsageService._();
  static final instance = FreeUsageService._();

  static const kTotalFreeUses = 3;
  static const kFreeCollectionLimit = 5;

  static const _keyAiOccasion = 'free_usage_ai_occasion';
  static const _keyDupeFinder = 'free_usage_dupe_finder';
  static const _keyReview     = 'free_usage_review';
  static const _keyAiScan     = 'free_usage_ai_scan';

  final ValueNotifier<int> aiOccasionLeft = ValueNotifier(kTotalFreeUses);
  final ValueNotifier<int> dupeFinderLeft = ValueNotifier(kTotalFreeUses);
  final ValueNotifier<int> reviewLeft     = ValueNotifier(kTotalFreeUses);
  final ValueNotifier<int> aiScanLeft     = ValueNotifier(kTotalFreeUses);

  SharedPreferences? _prefs;

  /// Call once at app startup (e.g. in [main] after WidgetsFlutterBinding).
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    aiOccasionLeft.value = _read(_keyAiOccasion);
    dupeFinderLeft.value = _read(_keyDupeFinder);
    reviewLeft.value     = _read(_keyReview);
    aiScanLeft.value     = _read(_keyAiScan);
  }

  /// Returns `true` if a credit was consumed, `false` if none remain.
  bool consumeAiOccasion() => _consume(_keyAiOccasion, aiOccasionLeft);
  bool consumeDupeFinder() => _consume(_keyDupeFinder, dupeFinderLeft);
  bool consumeReview()     => _consume(_keyReview,     reviewLeft);
  bool consumeAiScan()     => _consume(_keyAiScan,     aiScanLeft);

  /// Peek at remaining credits without consuming.
  int peekAiScanLeft() => aiScanLeft.value;
  int peekDupeFinderLeft() => dupeFinderLeft.value;

  /// Reset all counters back to [kTotalFreeUses].
  /// Useful for testing or when a subscription lapses.
  Future<void> resetAll() async {
    await _prefs?.setInt(_keyAiOccasion, kTotalFreeUses);
    await _prefs?.setInt(_keyDupeFinder, kTotalFreeUses);
    await _prefs?.setInt(_keyReview,     kTotalFreeUses);
    await _prefs?.setInt(_keyAiScan,     kTotalFreeUses);
    aiOccasionLeft.value = kTotalFreeUses;
    dupeFinderLeft.value = kTotalFreeUses;
    reviewLeft.value     = kTotalFreeUses;
    aiScanLeft.value     = kTotalFreeUses;
  }

  int _read(String key) {
    final v = _prefs?.getInt(key);
    if (v == null || v < 0 || v > kTotalFreeUses) return kTotalFreeUses;
    return v;
  }

  bool _consume(String key, ValueNotifier<int> notifier) {
    final current = notifier.value;
    if (current <= 0) return false;
    final next = current - 1;
    _prefs?.setInt(key, next);
    notifier.value = next;
    return true;
  }
}
