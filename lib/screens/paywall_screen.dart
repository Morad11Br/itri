import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../l10n/hardcoded_localizations.dart';
import '../services/subscription_service.dart';
import '../theme.dart';

class PaywallScreen extends StatefulWidget {
  /// Called when the screen should be dismissed. If null, uses Navigator.pop.
  final VoidCallback? onClose;
  const PaywallScreen({super.key, this.onClose});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offerings? _offerings;
  Package? _selectedPackage;
  bool _loading = true;
  bool _purchasing = false;
  bool _restoring = false;
  String? _errorMessage;

  // True = yearly selected, false = monthly
  bool _yearlySelected = true;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await SubscriptionService.instance.getOfferings();
      if (!mounted) return;
      final packages = offerings.current?.availablePackages ?? [];
      if (packages.isEmpty) {
        setState(() {
          _errorMessage = context.t('Could not load subscription options.');
          _loading = false;
        });
        return;
      }
      final yearly = packages.firstWhere(
        (p) => p.storeProduct.identifier.contains('yearly'),
        orElse: () => packages.first,
      );
      setState(() {
        _offerings = offerings;
        _selectedPackage = yearly;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[RevenueCat] offerings error: $e');
      setState(() {
        _errorMessage = context.t('Could not load subscription options.');
        _loading = false;
      });
    }
  }

  Package? get _yearlyPackage {
    return _offerings?.current?.availablePackages.firstWhere(
      (p) => p.storeProduct.identifier.contains('yearly'),
      orElse: () => _offerings!.current!.availablePackages.first,
    );
  }

  Package? get _monthlyPackage {
    return _offerings?.current?.availablePackages.firstWhere(
      (p) => p.storeProduct.identifier.contains('monthly'),
      orElse: () => _offerings!.current!.availablePackages.last,
    );
  }

  void _dismiss() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _purchase() async {
    final package = _selectedPackage;
    if (package == null) return;
    setState(() => _purchasing = true);
    try {
      await SubscriptionService.instance.purchasePackage(package);
      if (!mounted) return;
      _dismiss();
    } on PurchasesErrorCode catch (e) {
      if (!mounted) return;
      if (e != PurchasesErrorCode.purchaseCancelledError) {
        setState(
          () => _errorMessage = context.t('Purchase failed. Please try again.'),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage = context.t('Purchase failed. Please try again.'),
      );
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    try {
      final info = await SubscriptionService.instance.restorePurchases();
      if (!mounted) return;
      final isPro = info.entitlements.active.containsKey('Itri Pro');
      if (isPro) {
        Navigator.of(context).pop(true);
      } else {
        setState(
          () => _errorMessage = context.t('No active subscription found.'),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage = context.t('Restore failed. Please try again.'),
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: const Color(0xFF1A0A04),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kGold))
            : _errorMessage != null && _offerings == null
            ? _buildError()
            : _buildContent(isRtl),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: kGold, size: 48),
            const SizedBox(height: 16),
            Text(
              context.t('Could not load subscription options.'),
              textAlign: TextAlign.center,
              style: arabicStyle(fontSize: 15, color: Colors.white),
            ),
            const SizedBox(height: 24),
            _goldButton(
              label: context.t('Try Again'),
              onTap: () {
                setState(() {
                  _loading = true;
                  _errorMessage = null;
                });
                _loadOfferings();
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _dismiss,
              child: Text(
                context.t('Close'),
                style: arabicStyle(fontSize: 14, color: kSand),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isRtl) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildFeatures(),
                const SizedBox(height: 24),
                _buildPlanToggle(),
                const SizedBox(height: 12),
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: arabicStyle(fontSize: 12, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildCta(),
                const SizedBox(height: 16),
                _buildRestoreButton(),
                const SizedBox(height: 8),
                _buildLegalNote(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E1008), Color(0xFF1A0A04)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [kGoldLight, kGold],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: kGoldShadow,
                ),
                child: const Center(
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: kOud,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.t('Itri Pro'),
                style: arabicStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: kGold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.t('Unlock the full fragrance experience'),
                textAlign: TextAlign.center,
                style: arabicStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white54),
            onPressed: _dismiss,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatures() {
    final features = [
      (
        Icons.auto_awesome_rounded,
        context.t('AI-powered scent recommendations'),
      ),
      (
        Icons.manage_search_rounded,
        context.t('Unlimited dupe finder searches'),
      ),
      (Icons.grid_view_rounded, context.t('Unlimited collection tracking')),
      (Icons.bar_chart_rounded, context.t('Advanced collection analytics')),
      (Icons.star_rounded, context.t('Priority access to new features')),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: features.map((f) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kGold.withValues(alpha: 0.15),
                  ),
                  child: Icon(f.$1, color: kGold, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    f.$2,
                    style: arabicStyle(fontSize: 13, color: Colors.white),
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: kGold, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlanToggle() {
    final yearly = _yearlyPackage;
    final monthly = _monthlyPackage;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _planCard(
                package: yearly,
                isYearly: true,
                isSelected: _yearlySelected,
                badge: context.t('Best Value'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _planCard(
                package: monthly,
                isYearly: false,
                isSelected: !_yearlySelected,
              ),
            ),
          ],
        ),
        if (_yearlySelected && yearly != null && monthly != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildSavingsBadge(yearly, monthly),
          ),
      ],
    );
  }

  Widget _planCard({
    required Package? package,
    required bool isYearly,
    required bool isSelected,
    String? badge,
  }) {
    if (package == null) return const SizedBox.shrink();

    final price = package.storeProduct.priceString;
    final period = isYearly ? context.t('/ year') : context.t('/ month');
    final title = isYearly ? context.t('Yearly') : context.t('Monthly');

    return GestureDetector(
      onTap: () => setState(() {
        _yearlySelected = isYearly;
        _selectedPackage = package;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF2E1A00), Color(0xFF1A0A04)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? kGold : Colors.white24,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kGoldLight, kGold]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: arabicStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: kOud,
                  ),
                ),
              ),
            Text(
              title,
              style: arabicStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? kGold : Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: arabicStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            Text(
              period,
              style: arabicStyle(fontSize: 10, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsBadge(Package yearly, Package monthly) {
    final yearlyMonthlyPrice = yearly.storeProduct.price / 12;
    final monthlyPrice = monthly.storeProduct.price;
    if (monthlyPrice <= 0) return const SizedBox.shrink();
    final savingsPct = ((1 - yearlyMonthlyPrice / monthlyPrice) * 100).round();
    if (savingsPct <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: kGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withValues(alpha: 0.3)),
      ),
      child: Text(
        context.t('Save {pct}% vs monthly').replaceAll('{pct}', '$savingsPct'),
        style: arabicStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: kGold,
        ),
      ),
    );
  }

  Widget _buildCta() {
    final label = _purchasing
        ? context.t('Processing...')
        : context.t('Start Itri Pro');

    return _goldButton(
      label: label,
      onTap: _purchasing ? null : _purchase,
      loading: _purchasing,
    );
  }

  Widget _goldButton({
    required String label,
    VoidCallback? onTap,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: onTap != null
              ? const LinearGradient(colors: [kGoldLight, kGold])
              : null,
          color: onTap == null ? Colors.white24 : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap != null ? kGoldShadow : null,
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: kOud, strokeWidth: 2),
                ),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                style: arabicStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kOud,
                ),
              ),
      ),
    );
  }

  Widget _buildRestoreButton() {
    return TextButton(
      onPressed: _restoring ? null : _restore,
      child: _restoring
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: kSand, strokeWidth: 2),
            )
          : Text(
              context.t('Restore Purchases'),
              style: arabicStyle(fontSize: 13, color: kSand),
            ),
    );
  }

  Widget _buildLegalNote() {
    return Text(
      context.t(
        'Subscription renews automatically. Cancel anytime in Settings.',
      ),
      textAlign: TextAlign.center,
      style: arabicStyle(fontSize: 10, color: Colors.white30),
    );
  }
}
