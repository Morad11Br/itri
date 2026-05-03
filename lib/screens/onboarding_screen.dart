import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _startTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOud,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A0A04),
              Color(0xFF3D2314),
              Color(0xFF6B3A1F),
              Color(0xFF2C1810),
            ],
            stops: [0.0, 0.4, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Ambient glow top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          kGold.withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Bottle illustration
              FadeTransition(
                opacity: _fade,
                child: Align(
                  alignment: const Alignment(0, -0.55),
                  child: _buildBottleSVG(),
                ),
              ),
              // Particles
              ..._buildParticles(),
              // Skip
              Positioned(
                top: 8,
                right: 16,
                child: TextButton(
                  onPressed: widget.onDone,
                  child: Text(
                    AppLocalizations.of(context).skip,
                    style: arabicStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              // Content bottom
              Align(
                alignment: Alignment.bottomCenter,
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: _buildContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottleSVG() {
    return SizedBox(
      width: 120,
      height: 220,
      child: CustomPaint(painter: _OnboardingBottlePainter()),
    );
  }

  List<Widget> _buildParticles() {
    final positions = [
      [0.15, 0.28],
      [0.72, 0.22],
      [0.08, 0.45],
      [0.88, 0.38],
      [0.32, 0.18],
      [0.62, 0.35],
      [0.45, 0.52],
      [0.78, 0.48],
    ];
    return positions
        .map(
          (p) => Positioned(
            left: MediaQuery.of(context).size.width * p[0],
            top: MediaQuery.of(context).size.height * p[1],
            child: Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kGold.withValues(alpha: 0.5),
              ),
            ),
          ),
        )
        .toList();
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFE8C84A), Color(0xFFC9A227), Color(0xFFA07C1A)],
            ).createShader(bounds),
            child: Text(
              AppLocalizations.of(context).appTitle,
              style: arabicStyle(
                fontSize: 56,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).onboardingTitle1,
            textAlign: TextAlign.center,
            style: arabicStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.7,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: kGold,
                foregroundColor: kOud,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: kGold.withValues(alpha: 0.4),
              ),
              child: Text(
                AppLocalizations.of(context).collection,
                style: arabicStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: kOud,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onDone,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: kGold.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                AppLocalizations.of(context).perfumes,
                style: arabicStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context).onboardingDesc1,
            style: arabicStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingBottlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final gold = const Color(0xFFC9A227);

    // Neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.40, h * 0.02, w * 0.20, h * 0.08),
        const Radius.circular(4),
      ),
      Paint()
        ..color = gold.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.33, h * 0.10, w * 0.33, h * 0.04),
        const Radius.circular(2),
      ),
      Paint()
        ..color = gold.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill,
    );

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.17, h * 0.14, w * 0.67, h * 0.77),
        const Radius.circular(22),
      ),
      Paint()
        ..color = gold.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.17, h * 0.14, w * 0.67, h * 0.77),
        const Radius.circular(22),
      ),
      Paint()
        ..color = gold.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Liquid
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.52, w * 0.63, h * 0.38),
        const Radius.circular(10),
      ),
      Paint()
        ..color = gold.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );

    // Shine
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.23, h * 0.19, w * 0.13, h * 0.42),
        const Radius.circular(8),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_OnboardingBottlePainter old) => false;
}
