import 'dart:async';

import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/hardcoded_localizations.dart';
import '../theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  Package? _monthlyPackage;
  bool _loadingOfferings = true;
  bool _purchasing = false;
  String? _purchaseError;

  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (!mounted) return;
      final current = offerings.current;
      setState(() {
        _monthlyPackage = current?.monthly ?? current?.annual;
        _loadingOfferings = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingOfferings = false);
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
        await _markComplete();
        widget.onDone();
      } else {
        setState(() => _purchaseError = context.t('Purchase failed. Please try again.'));
      }
    } on PurchasesErrorCode catch (e) {
      if (!mounted) return;
      if (e != PurchasesErrorCode.purchaseCancelledError) {
        setState(() => _purchaseError = context.t('Purchase failed. Please try again.'));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _purchaseError = context.t('Purchase failed. Please try again.'));
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
  }

  void _onSkip() {
    unawaited(_markComplete());
    widget.onDone();
  }

  void _onNext() {
    if (_currentPage < 3) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 16, 0),
                child: TextButton(
                  onPressed: _onSkip,
                  child: Text(
                    context.t('Skip'),
                    style: arabicStyle(
                      fontSize: 14,
                      color: kWarmGray,
                    ),
                  ),
                ),
              ),
            ),
            // PageView
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                  _slideCtrl.forward(from: 0);
                },
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildFeaturePage(
                    icon: Icons.camera_alt_rounded,
                    iconGradient: const [Color(0xFFE8C84A), kGold],
                    title: context.t('Scan any perfume and know its details'),
                    subtitle: context.t(
                      'AI recognizes the perfume and gives you all the information',
                    ),
                  ),
                  _buildFeaturePage(
                    icon: Icons.compare_arrows_rounded,
                    iconGradient: const [Color(0xFF059669), Color(0xFF10B981)],
                    title: context.t('Discover perfumes with the same taste'),
                    subtitle: context.t(
                      'Accurate match percentage with alternatives that fit your budget',
                    ),
                  ),
                  _buildFeaturePage(
                    icon: Icons.auto_awesome_rounded,
                    iconGradient: const [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                    title: context.t('The perfect perfume for every occasion'),
                    subtitle: context.t(
                      'Let AI choose for you based on weather and occasion',
                    ),
                  ),
                  _buildPaywallPage(),
                ],
              ),
            ),
            // Bottom controls
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePage({
    required IconData icon,
    required List<Color> iconGradient,
    required String title,
    required String subtitle,
  }) {
    return SlideTransition(
      position: _slide,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            // Decorative icon circle
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: iconGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: iconGradient.last.withValues(alpha: 0.35),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(icon, size: 56, color: Colors.white),
            ),
            const SizedBox(height: 48),
            Text(
              title,
              textAlign: TextAlign.center,
              style: arabicStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: kOud,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: arabicStyle(
                fontSize: 15,
                color: kWarmGray,
                height: 1.6,
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildPaywallPage() {
    final features = [
      context.t('Unlimited perfume scans'),
      context.t('Smart alternatives for every perfume'),
      context.t('AI occasion recommendations'),
      context.t('Track your full collection'),
    ];

    return SlideTransition(
      position: _slide,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 1),
            // Premium icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [kGoldLight, kGold],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: kGoldShadow,
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                size: 40,
                color: kOud,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              context.t('Try Atari Premium for free'),
              textAlign: TextAlign.center,
              style: arabicStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: kOud,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.t('A full week without limits'),
              textAlign: TextAlign.center,
              style: arabicStyle(
                fontSize: 15,
                color: kWarmGray,
              ),
            ),
            const SizedBox(height: 32),
            // Features list
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: kCardShadow,
              ),
              child: Column(
                children: features.map((f) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
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
                            style: arabicStyle(
                              fontSize: 14,
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
            const SizedBox(height: 24),
            if (_purchaseError != null)
              Text(
                _purchaseError!,
                textAlign: TextAlign.center,
                style: arabicStyle(fontSize: 12, color: Colors.redAccent),
              ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLast = _currentPage == 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: active ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: active
                      ? kGold
                      : kSand.withValues(alpha: 0.35),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // CTA button
          if (isLast) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _purchasing || _loadingOfferings || _monthlyPackage == null ? null : _purchase,
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
            const SizedBox(height: 12),
            TextButton(
              onPressed: _onSkip,
              child: Text(
                context.t('Skip'),
                style: arabicStyle(fontSize: 14, color: kWarmGray),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.t('After trial: 19.99 SAR/month'),
              textAlign: TextAlign.center,
              style: arabicStyle(
                fontSize: 11,
                color: kSand,
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onNext,
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
                child: Text(
                  context.t('Next'),
                  style: arabicStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kOud,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
