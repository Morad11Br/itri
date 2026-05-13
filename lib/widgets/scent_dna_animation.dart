import 'dart:math';
import 'package:flutter/material.dart';
import '../models/perfume.dart';
import '../theme.dart';
import 'bottle_icon.dart';
import 'perfume_image.dart';

/// Cinematic "Scent DNA" animation for AI dupe finding.
///
/// When [isLoading] is true and the main animation finishes, the widget
/// enters an idle "breathing" state so it never looks frozen.
class ScentDnaAnimation extends StatefulWidget {
  final Perfume sourcePerfume;
  final Perfume? matchedPerfume;
  final VoidCallback? onComplete;
  final VoidCallback? onTapReplay;
  final double size;

  /// When true and the main animation is done, the final frame gently
  /// pulses so the screen never looks static while waiting for results.
  final bool isLoading;

  const ScentDnaAnimation({
    super.key,
    required this.sourcePerfume,
    this.matchedPerfume,
    this.onComplete,
    this.onTapReplay,
    this.size = 320,
    this.isLoading = true,
  });

  @override
  State<ScentDnaAnimation> createState() => _ScentDnaAnimationState();
}

class _ScentDnaAnimationState extends State<ScentDnaAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _breatheCtrl;

  late final Animation<double> _sourceFade;
  late final Animation<double> _sourceScale;
  late final Animation<double> _sourceGlow;
  late final Animation<double> _notesPop;
  late final Animation<double> _analyze;
  late final Animation<double> _reconstruct;
  late final Animation<double> _targetScale;
  late final Animation<double> _liquidFill;
  late final Animation<double> _resultFade;

  List<FragranceNote> get _notes {
    final all = [
      ...widget.sourcePerfume.topNotes,
      ...widget.sourcePerfume.heartNotes,
      ...widget.sourcePerfume.baseNotes,
    ];
    if (all.isEmpty) {
      return const [
        FragranceNote(id: '1', name: 'ورد', color: kRose),
        FragranceNote(id: '2', name: 'عنبر', color: kGold),
        FragranceNote(id: '3', name: 'عود', color: kOud),
        FragranceNote(id: '4', name: 'مسك', color: kSand),
      ];
    }
    return all.take(5).toList();
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _sourceFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.00, 0.28, curve: Curves.easeOutQuad),
    );
    _sourceScale = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.00, 0.25, curve: Curves.easeOutBack),
    );
    _sourceGlow = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.05, 0.35, curve: Curves.easeOut),
    );

    _notesPop = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.12, 0.48, curve: Curves.elasticOut),
    );
    _analyze = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.30, 0.80, curve: Curves.easeInOut),
    );
    _reconstruct = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.62, 0.92, curve: Curves.easeInOutCubic),
    );
    _targetScale = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.68, 1.00, curve: Curves.elasticOut),
    );
    _liquidFill = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.74, 1.00, curve: Curves.easeOutExpo),
    );
    _resultFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.88, 1.00, curve: Curves.easeOut),
    );

    _ctrl.forward().whenComplete(_onMainAnimationDone);
  }

  void _onMainAnimationDone() {
    widget.onComplete?.call();
    if (widget.isLoading && mounted) {
      _breatheCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant ScentDnaAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isLoading && widget.isLoading && _ctrl.isCompleted) {
      _breatheCtrl.repeat(reverse: true);
    }
    if (oldWidget.isLoading && !widget.isLoading) {
      _breatheCtrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _breatheCtrl.dispose();
    super.dispose();
  }

  void _replay() {
    if (_ctrl.isCompleted || _ctrl.isDismissed) {
      _breatheCtrl.stop();
      _ctrl.reset();
      _ctrl.forward().whenComplete(_onMainAnimationDone);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTapReplay != null
            ? () {
                widget.onTapReplay!();
                _replay();
              }
            : _replay,
        child: SizedBox(
          width: widget.size,
          height: widget.size * 1.3,
          child: AnimatedBuilder(
            animation: Listenable.merge([_ctrl, _breatheCtrl]),
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  const _DarkBackground(),

                  if (_ctrl.value > 0.25 && _ctrl.value < 0.85)
                    _SparkleField(
                      analyzeValue: _analyze.value,
                      size: widget.size,
                    ),

                  _RevealRing(reconstruct: _reconstruct.value),

                  _SourceImage(
                    perfume: widget.sourcePerfume,
                    fade: _sourceFade.value,
                    scale: _sourceScale.value,
                    glow: _sourceGlow.value,
                  ),

                  ..._buildNoteChips(),

                  _AiPulse(value: _analyze.value),

                  _TargetImage(
                    scale: _targetScale.value,
                    fill: _liquidFill.value,
                    breathe: _breatheCtrl.value,
                    perfume: widget.matchedPerfume,
                  ),

                  _SourceNameText(
                    perfume: widget.sourcePerfume,
                    fade: _sourceFade.value,
                  ),

                  _ResultOverlay(
                    fade: _resultFade.value,
                    breathe: _breatheCtrl.value,
                    perfume: widget.matchedPerfume,
                    canvasWidth: widget.size,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNoteChips() {
    final notes = _notes;
    final orbitRadius = widget.size * 0.30;
    final centerX = widget.size / 2;
    final centerY = widget.size * 0.42;

    return notes.asMap().entries.map((e) {
      final index = e.key;
      final note = e.value;
      final angle = (index / notes.length) * 2 * pi - pi / 2;
      return _NoteChip(
        note: note,
        index: index,
        total: notes.length,
        angle: angle,
        orbitRadius: orbitRadius,
        centerX: centerX,
        centerY: centerY,
        pop: _notesPop.value,
        analyze: _analyze.value,
        reconstruct: _reconstruct.value,
        controllerValue: _ctrl.value,
      );
    }).toList();
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Background & Atmosphere
// ═══════════════════════════════════════════════════════════════════

class _DarkBackground extends StatelessWidget {
  const _DarkBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.9,
          colors: [
            Color(0xFF2A1F16),
            Color(0xFF0D0A07),
          ],
        ),
      ),
    );
  }
}

class _SparkleField extends StatelessWidget {
  final double analyzeValue;
  final double size;

  const _SparkleField({required this.analyzeValue, required this.size});

  @override
  Widget build(BuildContext context) {
    final sparkles = [
      (dx: 0.15, dy: 0.20, phase: 0.0, color: kGoldLight),
      (dx: 0.80, dy: 0.25, phase: 1.2, color: kGold),
      (dx: 0.25, dy: 0.70, phase: 2.1, color: Colors.white),
      (dx: 0.75, dy: 0.65, phase: 0.7, color: kGoldPale),
      (dx: 0.50, dy: 0.15, phase: 3.0, color: kGoldLight),
      (dx: 0.10, dy: 0.55, phase: 1.8, color: Colors.white),
    ];

    return Stack(
      children: sparkles.map((s) {
        final twinkle = sin((analyzeValue * pi * 4) + s.phase);
        final opacity = (0.4 + twinkle * 0.4).clamp(0.0, 1.0);
        final sparkleSize = (2.5 + twinkle * 1.5).clamp(1.0, 4.0);
        return Positioned(
          left: size * s.dx,
          top: size * s.dy,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: sparkleSize,
              height: sparkleSize,
              decoration: BoxDecoration(
                color: s.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: s.color.withValues(alpha: 0.8),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RevealRing extends StatelessWidget {
  final double reconstruct;
  const _RevealRing({required this.reconstruct});

  @override
  Widget build(BuildContext context) {
    if (reconstruct <= 0.01) return const SizedBox.shrink();
    final radius = 40 + 160 * reconstruct;
    return Container(
      width: radius,
      height: radius,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: kGold.withValues(alpha: 0.4 * (1.0 - reconstruct)),
          width: 2.5,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Source Image
// ═══════════════════════════════════════════════════════════════════

class _SourceImage extends StatelessWidget {
  final Perfume perfume;
  final double fade;
  final double scale;
  final double glow;

  const _SourceImage({
    required this.perfume,
    required this.fade,
    required this.scale,
    required this.glow,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = fade.clamp(0.0, 1.0);
    final bottleScale = 0.75 + 0.25 * scale;
    if (opacity < 0.01) return const SizedBox.shrink();

    return Transform.scale(
      scale: bottleScale,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: kGold.withValues(
                  alpha: 0.25 * glow.clamp(0.0, 1.0),
                ),
                blurRadius: 50,
                spreadRadius: 15,
              ),
            ],
          ),
          child: _PerfumeBottleImage(perfume: perfume, size: 100),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Target Image + liquid sheen + breathe pulse
// ═══════════════════════════════════════════════════════════════════

class _TargetImage extends StatelessWidget {
  final double scale;
  final double fill;
  final double breathe;
  final Perfume? perfume;

  const _TargetImage({
    required this.scale,
    required this.fill,
    required this.breathe,
    required this.perfume,
  });

  @override
  Widget build(BuildContext context) {
    final s = scale.clamp(0.0, 1.0);
    if (s < 0.01) return const SizedBox.shrink();

    final pulseScale = 1.0 + breathe * 0.04;
    final glowAlpha = 0.35 + breathe * 0.15;

    return Transform.scale(
      scale: s * pulseScale,
      child: Opacity(
        opacity: s,
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: kGold.withValues(alpha: glowAlpha),
                blurRadius: 50,
                spreadRadius: 15,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              _PerfumeBottleImage(
                perfume: perfume,
                size: 100,
                fallbackColor: kGold,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                  child: Container(
                    height: 100 * fill.clamp(0.0, 1.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          kGold.withValues(alpha: 0.55),
                          kGold.withValues(alpha: 0.20),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(top: 2),
                        height: 2,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(1),
                          boxShadow: [
                            BoxShadow(
                              color: kGoldLight.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Source name (separate, below center, fades out early)
// ═══════════════════════════════════════════════════════════════════

class _SourceNameText extends StatelessWidget {
  final Perfume perfume;
  final double fade;

  const _SourceNameText({required this.perfume, required this.fade});

  @override
  Widget build(BuildContext context) {
    final opacity = fade.clamp(0.0, 1.0);
    if (opacity < 0.01) return const SizedBox.shrink();

    return Positioned(
      top: 200,
      left: 20,
      right: 20,
      child: Opacity(
        opacity: opacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              perfume.name,
              style: arabicStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kCream,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              perfume.brand,
              style: serifStyle(
                fontSize: 11,
                italic: true,
                color: kSand.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Shared perfume image helper
// ═══════════════════════════════════════════════════════════════════

class _PerfumeBottleImage extends StatelessWidget {
  final Perfume? perfume;
  final double size;
  final Color fallbackColor;

  const _PerfumeBottleImage({
    this.perfume,
    required this.size,
    this.fallbackColor = kGold,
  });

  @override
  Widget build(BuildContext context) {
    final p = perfume;
    if (p != null &&
        (p.imageUrl != null || p.fallbackImageUrl != null)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: PerfumeImage(
          primaryUrl: p.imageUrl ?? '',
          fallbackUrl: p.fallbackImageUrl,
          fallbackColor: fallbackColor,
          width: size,
          height: size * 1.2,
          fit: BoxFit.contain,
          iconSize: size * 0.4,
        ),
      );
    }
    return BottleIcon(size: size, color: fallbackColor);
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Note Chips
// ═══════════════════════════════════════════════════════════════════

class _NoteChip extends StatelessWidget {
  final FragranceNote note;
  final int index;
  final int total;
  final double angle;
  final double orbitRadius;
  final double centerX;
  final double centerY;
  final double pop;
  final double analyze;
  final double reconstruct;
  final double controllerValue;

  const _NoteChip({
    required this.note,
    required this.index,
    required this.total,
    required this.angle,
    required this.orbitRadius,
    required this.centerX,
    required this.centerY,
    required this.pop,
    required this.analyze,
    required this.reconstruct,
    required this.controllerValue,
  });

  @override
  Widget build(BuildContext context) {
    final stagger = index * 0.07;
    final adjustedPop = ((pop - stagger) / (1.0 - stagger * 0.5)).clamp(0.0, 1.0);

    double distance;
    if (controllerValue < 0.48) {
      distance = orbitRadius * adjustedPop;
    } else if (controllerValue < 0.72) {
      final bob = sin((controllerValue * pi * 4) + index * 1.3) * 7.0;
      distance = orbitRadius + bob;
    } else {
      distance = orbitRadius * (1.0 - reconstruct);
    }

    final x = centerX + cos(angle) * distance - 40;
    final y = centerY + sin(angle) * distance - 16;

    double chipScale;
    if (controllerValue < 0.48) {
      chipScale = adjustedPop;
    } else if (controllerValue < 0.74) {
      chipScale = 1.0;
    } else {
      chipScale = 1.0 - reconstruct * 0.6;
    }

    double chipOpacity;
    if (controllerValue < 0.48) {
      chipOpacity = adjustedPop;
    } else if (controllerValue < 0.74) {
      chipOpacity = 1.0;
    } else {
      chipOpacity = 1.0 - reconstruct;
    }

    return Positioned(
      left: x,
      top: y,
      child: Opacity(
        opacity: chipOpacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: chipScale.clamp(0.0, 1.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1610),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: note.color.withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: note.color.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: note.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: note.color.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  note.name,
                  style: arabicStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: kCream,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  AI Pulse Core
// ═══════════════════════════════════════════════════════════════════

class _AiPulse extends StatelessWidget {
  final double value;
  const _AiPulse({required this.value});

  @override
  Widget build(BuildContext context) {
    if (value <= 0.05 || value >= 0.95) return const SizedBox.shrink();

    final pulse = sin(value * pi * 3);
    final size = 28 + pulse * 8;
    final opacity = 0.35 + pulse * 0.25;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kGold.withValues(alpha: opacity.clamp(0.0, 1.0)),
        border: Border.all(
          color: kGoldLight.withValues(alpha: 0.7),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: kGold.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          'AI',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: kCream.withValues(alpha: 0.95),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Result Overlay (with breathe pulse)
// ═══════════════════════════════════════════════════════════════════

class _ResultOverlay extends StatelessWidget {
  final double fade;
  final double breathe;
  final Perfume? perfume;
  final double canvasWidth;

  const _ResultOverlay({
    required this.fade,
    required this.breathe,
    required this.perfume,
    required this.canvasWidth,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = fade.clamp(0.0, 1.0);
    if (opacity < 0.01) return const SizedBox.shrink();

    final name = perfume?.name ?? 'البديل المثالي';
    final brand = perfume?.brand ?? 'AI Match';
    final badgeScale = 1.0 + breathe * 0.03;

    return Positioned(
      bottom: 16,
      left: 20,
      right: 20,
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, 14 * (1.0 - opacity)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: arabicStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kCream,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                brand,
                style: serifStyle(
                  fontSize: 12,
                  italic: true,
                  color: kSand,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Transform.scale(
                scale: badgeScale,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kGold, kGoldLight],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: kGold.withValues(alpha: 0.35 + breathe * 0.2),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    'تطابق 94%',
                    style: arabicStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: kOud,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
