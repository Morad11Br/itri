import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../l10n/app_localizations.dart';
import '../l10n/hardcoded_localizations.dart';
import '../theme.dart';
import 'settings/privacy_screen.dart';
import 'settings/terms_screen.dart';

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
      final offerings = await Purchases.getOfferings();
      if (!mounted) return;

      final current = offerings.current;
      if (current == null) {
        setState(() {
          _errorMessage = context.t('Could not load subscription options.');
          _loading = false;
        });
        return;
      }

      final monthly = current.monthly;
      final yearly = current.annual;

      if (monthly == null && yearly == null) {
        setState(() {
          _errorMessage = context.t('Could not load subscription options.');
          _loading = false;
        });
        return;
      }

      setState(() {
        _offerings = offerings;
        _selectedPackage = yearly ?? monthly;
        _yearlySelected = yearly != null;
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

  Package? get _yearlyPackage => _offerings?.current?.annual;

  Package? get _monthlyPackage => _offerings?.current?.monthly;

  void _dismiss() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _purchase() async {
    final package = _selectedPackage;
    if (package == null) return false;

    setState(() => _purchasing = true);
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      if (!mounted) return false;

      final isActive =
          customerInfo.entitlements.active.containsKey('Itri Pro');
      if (isActive) {
        _dismiss();
        return true;
      }

      setState(
        () => _errorMessage = context.t('Purchase failed. Please try again.'),
      );
      return false;
    } on PurchasesErrorCode catch (e) {
      if (!mounted) return false;
      if (e != PurchasesErrorCode.purchaseCancelledError) {
        setState(
          () => _errorMessage = context.t('Purchase failed. Please try again.'),
        );
      }
      return false;
    } catch (e) {
      if (!mounted) return false;
      setState(
        () => _errorMessage = context.t('Purchase failed. Please try again.'),
      );
      return false;
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    try {
      final info = await Purchases.restorePurchases();
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
                context.t('Try Premium for free'),
                style: arabicStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: kGold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.t('7 days free, then subscription starts\nCancel anytime'),
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
      context.t('All perfume alternatives'),
      context.t('Detailed comparisons'),
      context.t('Save favorites'),
      context.t('Daily updates'),
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
                const Icon(
                  Icons.check_circle_rounded,
                  color: kSuccess,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    f,
                    style: arabicStyle(fontSize: 13, color: Colors.white),
                  ),
                ),
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
      ],
    );
  }

  Widget _planCard({
    required Package? package,
    required bool isYearly,
    required bool isSelected,
  }) {
    if (package == null) return const SizedBox.shrink();

    final price = package.storeProduct.priceString;
    final period = isYearly ? context.t('/ year') : context.t('/ month');
    final title = isYearly ? context.t('Yearly') : context.t('Monthly');
    const selectedBlue = Color(0xFF3B82F6);

    return GestureDetector(
      onTap: () => setState(() {
        _yearlySelected = isYearly;
        _selectedPackage = package;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? selectedBlue : Colors.white24,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: arabicStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
                if (isYearly)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: kSuccess.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: kSuccess.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      context.t('Save 38%'),
                      style: arabicStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: kSuccess,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
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
              style: arabicStyle(fontSize: 11, color: Colors.white54),
            ),
            if (isYearly) ...[
              const SizedBox(height: 6),
              Text(
                context.t('7 days free'),
                style: arabicStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kGold,
                ),
              ),
            ],
          ],
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
                  child: CircularProgressIndicator(
                    color: kOud,
                    strokeWidth: 2,
                  ),
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
              child: CircularProgressIndicator(
                color: kSand,
                strokeWidth: 2,
              ),
            )
          : Text(
              context.t('Restore Purchases'),
              style: arabicStyle(fontSize: 13, color: kSand),
            ),
    );
  }

  Widget _buildLegalNote() {
    return Column(
      children: [
        Text(
          context.t(
            'Subscription renews automatically. You can cancel anytime.',
          ),
          textAlign: TextAlign.center,
          style: arabicStyle(fontSize: 10, color: Colors.white30),
        ),
        const SizedBox(height: 8),
        _buildLegalLinks(),
      ],
    );
  }

  Widget _buildLegalLinks() {
    final style = arabicStyle(fontSize: 10, color: kSand);
    final tapStyle = arabicStyle(
      fontSize: 10,
      color: kGold,
      fontWeight: FontWeight.w600,
    );

    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TermsScreen()),
            );
          },
          child: Text(
            AppLocalizations.of(context).termsOfUse,
            style: tapStyle,
          ),
        ),
        Text('  •  ', style: style),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyScreen()),
            );
          },
          child: Text(
            AppLocalizations.of(context).privacyPolicy,
            style: tapStyle,
          ),
        ),
      ],
    );
  }
}
