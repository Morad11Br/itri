import 'dart:async';

import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../l10n/hardcoded_localizations.dart';
import '../theme.dart';

/// Reusable paywall bottom sheet shown when a free user hits a usage limit.
///
/// Call [show] to display the sheet. Returns `true` if the user successfully
/// purchased/subscribed, `false` otherwise.
class PaywallBottomSheet {
  static Future<bool> show(
    BuildContext context, {
    required String message,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaywallSheetBody(message: message),
    );
    return result ?? false;
  }
}

class _PaywallSheetBody extends StatefulWidget {
  final String message;
  const _PaywallSheetBody({required this.message});

  @override
  State<_PaywallSheetBody> createState() => _PaywallSheetBodyState();
}

class _PaywallSheetBodyState extends State<_PaywallSheetBody> {
  Package? _monthlyPackage;
  bool _loading = true;
  bool _purchasing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (!mounted) return;
      final current = offerings.current;
      setState(() {
        _monthlyPackage = current?.monthly ?? current?.annual;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _purchase() async {
    final package = _monthlyPackage;
    if (package == null) return;
    setState(() => _purchasing = true);
    try {
      final info = await Purchases.purchasePackage(package);
      if (!mounted) return;
      final isActive = info.entitlements.active.containsKey('Itri Pro');
      if (isActive) {
        Navigator.of(context).pop(true);
      } else {
        setState(
          () => _error = context.t('Purchase failed. Please try again.'),
        );
      }
    } on PurchasesErrorCode catch (e) {
      if (!mounted) return;
      if (e != PurchasesErrorCode.purchaseCancelledError) {
        setState(
          () => _error = context.t('Purchase failed. Please try again.'),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = context.t('Purchase failed. Please try again.'),
      );
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final features = [
      context.t('Unlimited perfume scans'),
      context.t('Smart alternatives for every perfume'),
      context.t('AI occasion recommendations'),
      context.t('Track your full collection'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: kCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kSand.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Lock icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [kGoldLight, kGold],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: kGoldShadow,
              ),
              child: const Icon(Icons.lock_rounded, color: kOud, size: 28),
            ),
            const SizedBox(height: 16),
            // Message
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: arabicStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: kOud,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            // Features
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: kCardShadow,
              ),
              child: Column(
                children: features.map((f) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: kSuccess,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f,
                            style: arabicStyle(
                              fontSize: 13,
                              color: kEspresso,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: arabicStyle(fontSize: 12, color: Colors.redAccent),
              ),
            // CTA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _purchasing || _loading || _monthlyPackage == null
                    ? null
                    : _purchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: kOud,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 6,
                  shadowColor: kGold.withValues(alpha: 0.4),
                ),
                child: _purchasing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: kOud,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        context.t('Start free trial - one week free'),
                        style: arabicStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kOud,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                context.t('Later'),
                style: arabicStyle(fontSize: 14, color: kWarmGray),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.t('After trial: 19.99 SAR/month'),
              textAlign: TextAlign.center,
              style: arabicStyle(fontSize: 10, color: kSand),
            ),
          ],
        ),
      ),
    );
  }
}
