import 'dart:async';

import 'package:flutter/material.dart';
import '../theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _pulseController;
  late final AnimationController _exitController;
  Timer? _completeTimer;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<double> _taglineFade;
  late final Animation<double> _pulse;
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    // Main entrance animation — 1.4 s
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
    );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    // Continuous glow pulse on logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Exit fade-out — 400 ms
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );

    _mainController.forward();

    // After 2.6 s, fade out then complete
    _completeTimer = Timer(const Duration(milliseconds: 2600), () async {
      if (!mounted) return;
      await _exitController.forward();
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _completeTimer?.cancel();
    _mainController.dispose();
    _pulseController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitFade,
      builder: (context, child) => Opacity(
        opacity: _exitFade.value,
        child: child,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A0402), Color(0xFF1E0C06), Color(0xFF2C1208)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Background ornament — faint top arc
              Positioned(
                top: -120,
                left: -120,
                child: AnimatedBuilder(
                  animation: _logoFade,
                  builder: ( ctx, child) => Opacity(
                    opacity: _logoFade.value * 0.12,
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [kGold, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -80,
                right: -80,
                child: AnimatedBuilder(
                  animation: _logoFade,
                  builder: ( ctx, child) => Opacity(
                    opacity: _logoFade.value * 0.08,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [kGold, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Main content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo with glow pulse
                    AnimatedBuilder(
                      animation: Listenable.merge([_logoScale, _logoFade, _pulse]),
                      builder: ( ctx, child) => Opacity(
                        opacity: _logoFade.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer glow ring
                              Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: kGold.withValues(
                                        alpha: _pulse.value * 0.45,
                                      ),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              // Middle ring
                              Container(
                                width: 108,
                                height: 108,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: kGold.withValues(
                                      alpha: _pulse.value * 0.3,
                                    ),
                                    width: 1,
                                  ),
                                ),
                              ),
                              // Main circle
                              Container(
                                width: 90,
                                height: 90,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [kGoldLight, kGold, Color(0xFFAA8820)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Color(0xFF2C1208),
                                    size: 42,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // App name in Arabic
                    AnimatedBuilder(
                      animation: _textFade,
                      builder: ( ctx, child) => Opacity(
                        opacity: _textFade.value,
                        child: Text(
                          'عطري',
                          style: arabicStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: kGold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // English name
                    AnimatedBuilder(
                      animation: _textFade,
                      builder: ( ctx, child) => Opacity(
                        opacity: _textFade.value * 0.7,
                        child: Text(
                          'ITRI',
                          style: arabicStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w300,
                            color: kGold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Divider ornament
                    AnimatedBuilder(
                      animation: _taglineFade,
                      builder: ( ctx, child) => Opacity(
                        opacity: _taglineFade.value,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 0.5,
                              color: kGold.withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.spa_rounded,
                              size: 12,
                              color: kGold.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 40,
                              height: 0.5,
                              color: kGold.withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tagline
                    AnimatedBuilder(
                      animation: _taglineFade,
                      builder: ( ctx, child) => Opacity(
                        opacity: _taglineFade.value,
                        child: Text(
                          'عالم العطور في يدك',
                          style: arabicStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
