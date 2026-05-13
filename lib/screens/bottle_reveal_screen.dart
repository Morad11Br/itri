// lib/screens/bottle_reveal_screen.dart
//
// Full animated "Bottle Reveal" flow: Scanning → Reveal → Results.
// Accepts real dupe-search data; scanning animation syncs with the live future.
// Dark glamour: black canvas, gold/amber light, theatrical reveal. RTL Arabic.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:google_fonts/google_fonts.dart';
import '../models/perfume.dart';
import '../theme.dart';
import '../widgets/perfume_image.dart';
import '../widgets/bottle_icon.dart';
import '../l10n/hardcoded_localizations.dart';

// ─────────────────────────────────────────────────────────────
// Public data class — returned by the caller's dupesFuture
// ─────────────────────────────────────────────────────────────
class BottleDupeResult {
  final Perfume perfume;
  final double matchPct;   // 0–100
  final String reason;     // AI reason text, may be empty
  final String? priceRangeSar; // e.g. "285" or "150-300"

  const BottleDupeResult({
    required this.perfume,
    required this.matchPct,
    this.reason = '',
    this.priceRangeSar,
  });
}

// ─────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────


TextStyle _arabic({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = kOud,
  double? letterSpacing,
}) =>
    GoogleFonts.ibmPlexSansArabic(
        fontSize: size, fontWeight: weight, color: color, letterSpacing: letterSpacing);

TextStyle _serif({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = kOud,
  bool italic = false,
}) =>
    GoogleFonts.cormorantGaramond(
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal);

TextStyle _inter({
  double size = 12,
  FontWeight weight = FontWeight.w400,
  Color color = kOud,
  double? letterSpacing,
}) =>
    GoogleFonts.inter(
        fontSize: size, fontWeight: weight, color: color, letterSpacing: letterSpacing);

// ─────────────────────────────────────────────────────────────
// Color helpers — derive ring and body tones from accent
// ─────────────────────────────────────────────────────────────
Color _bodyFromColor(Color c) {
  final h = HSLColor.fromColor(c);
  return h.withSaturation(0.30).withLightness(0.20).toColor();
}

// Parse midpoint SAR price from strings like "285" or "150-300"
int? _parseMidPrice(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split('-');
  final low = int.tryParse(parts.first.trim()) ?? 0;
  if (low <= 0) return null;
  final high = parts.length > 1 ? (int.tryParse(parts.last.trim()) ?? low) : low;
  return ((low + high) / 2).round();
}

// ─────────────────────────────────────────────────────────────
// Phase enum
// ─────────────────────────────────────────────────────────────
enum _Phase { scanning, reveal, results }

// ─────────────────────────────────────────────────────────────
// BottleRevealScreen
// ─────────────────────────────────────────────────────────────
class BottleRevealScreen extends StatefulWidget {
  /// The perfume being analysed (shown in the source pill).
  final Perfume reference;

  /// The AI/Jaccard search; scanned concurrently with the animation.
  final Future<List<BottleDupeResult>> dupesFuture;

  /// The user-entered reference price in SAR (used to calculate savings).
  final int? referencePriceSar;

  /// Called when the user taps a result card.
  final void Function(Perfume)? onPerfumeTap;

  const BottleRevealScreen({
    super.key,
    required this.reference,
    required this.dupesFuture,
    this.referencePriceSar,
    this.onPerfumeTap,
  });

  @override
  State<BottleRevealScreen> createState() => _BottleRevealScreenState();
}

class _BottleRevealScreenState extends State<BottleRevealScreen> {
  _Phase _phase = _Phase.scanning;
  int _runId = 0;
  List<BottleDupeResult> _results = [];

  void _onScanComplete(List<BottleDupeResult> results) {
    if (!mounted) return;
    setState(() {
      _results = results;
      _phase = results.isEmpty ? _Phase.results : _Phase.reveal;
    });
  }

  void _setPhase(_Phase p) => setState(() => _phase = p);

  void _restart() => setState(() {
        _phase = _Phase.scanning;
        _runId++;
        // _results kept — reused by the recycled future
      });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: kCream,
        body: SafeArea(
            child: Column(
              children: [
                _PageHeader(phase: _phase, onBack: _restart),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey(_runId),
                    child: _PhaseRouter(
                      phase: _phase,
                      reference: widget.reference,
                      dupesFuture: widget.dupesFuture,
                      results: _results,
                      referencePriceSar: widget.referencePriceSar,
                      onScanComplete: _onScanComplete,
                      onRevealContinue: () => _setPhase(_Phase.results),
                      onPerfumeTap: widget.onPerfumeTap,
                    ),
                  ),
                ),
                _PhaseDots(current: _phase, onTap: _setPhase),
              ],
            ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Phase router
// ─────────────────────────────────────────────────────────────
class _PhaseRouter extends StatelessWidget {
  final _Phase phase;
  final Perfume reference;
  final Future<List<BottleDupeResult>> dupesFuture;
  final List<BottleDupeResult> results;
  final int? referencePriceSar;
  final void Function(List<BottleDupeResult>) onScanComplete;
  final VoidCallback onRevealContinue;
  final void Function(Perfume)? onPerfumeTap;

  const _PhaseRouter({
    required this.phase,
    required this.reference,
    required this.dupesFuture,
    required this.results,
    required this.referencePriceSar,
    required this.onScanComplete,
    required this.onRevealContinue,
    this.onPerfumeTap,
  });

  @override
  Widget build(BuildContext context) {
    return switch (phase) {
      _Phase.scanning => _ScanningScreen(
          reference: reference,
          dupesFuture: dupesFuture,
          onComplete: onScanComplete,
        ),
      _Phase.reveal => _RevealScreen(
          reference: reference,
          result: results.first,
          onContinue: onRevealContinue,
        ),
      _Phase.results => _ResultsScreen(
          reference: reference,
          results: results,
          referencePriceSar: referencePriceSar,
          onPerfumeTap: onPerfumeTap,
        ),
    };
  }
}

// ─────────────────────────────────────────────────────────────
// Page header
// ─────────────────────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  final _Phase phase;
  final VoidCallback onBack;

  const _PageHeader({required this.phase, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final label = switch (phase) {
      _Phase.scanning => context.t('· Analyzing ·'),
      _Phase.reveal   => context.t('· The Ideal Alternative ·'),
      _Phase.results  => context.t('· Results ·'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                onBack();
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kGoldPale,
                shape: BoxShape.circle,
                border: Border.all(color: kGold.withValues(alpha: 0.25), width: 0.5),
              ),
              child: const Icon(Icons.chevron_right, color: kOud, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(label,
                    style: _inter(size: 11, weight: FontWeight.w500, color: kGold, letterSpacing: 1.2)),
                const SizedBox(height: 6),
                Text(context.t('Dupe Finder'),
                    style: _arabic(size: 26, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(context.t('Find a similar perfume for less'),
                    style: _arabic(size: 13, color: kWarmGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Source pill — shows the reference perfume
// ─────────────────────────────────────────────────────────────
class _SourcePill extends StatelessWidget {
  final Perfume reference;

  const _SourcePill({required this.reference});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold.withValues(alpha: 0.25), width: 0.5),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(context.t('Source'),
                    style: _inter(size: 10, color: kWarmGray, letterSpacing: 1.0)),
                const SizedBox(height: 2),
                Text(reference.name,
                    style: _inter(size: 14, weight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text(reference.brand,
                    style: _serif(size: 11, color: kWarmGray, italic: true)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 44,
              height: 44,
              color: reference.accent.withValues(alpha: 0.10),
              child: _PerfumeImageDisplay(perfume: reference, size: 44),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Scanning Screen
// ─────────────────────────────────────────────────────────────
class _ScanningScreen extends StatefulWidget {
  final Perfume reference;
  final Future<List<BottleDupeResult>> dupesFuture;
  final void Function(List<BottleDupeResult>) onComplete;

  const _ScanningScreen({
    required this.reference,
    required this.dupesFuture,
    required this.onComplete,
  });

  @override
  State<_ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<_ScanningScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progressCtrl;
  late final AnimationController _radarCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _waveCtrl;
  late final List<double> _wavePhases;

  bool _animDone = false;
  bool _dataDone = false;
  List<BottleDupeResult> _results = [];
  bool _extended = false; // true after anim completes but still waiting for data

  List<String> _statuses(BuildContext context) => [
    context.t('Extracting fragrance notes…'),
    context.t('Matching amber and oud base…'),
    context.t('Comparing 12,400 perfumes…'),
    context.t('Identifying the ideal alternative…'),
  ];

  @override
  void initState() {
    super.initState();

    final rnd = math.Random(42);
    _wavePhases = List.generate(26, (i) => i * 0.04 + rnd.nextDouble() * 0.3);

    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() => _extended = _dataDone == false);
          _animDone = true;
          _tryAdvance();
        }
      });

    _radarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();
    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();

    _progressCtrl.forward();

    widget.dupesFuture.then((results) {
      if (!mounted) return;
      _results = results;
      _dataDone = true;
      _tryAdvance();
    }).catchError((_) {
      if (!mounted) return;
      _dataDone = true;
      _tryAdvance();
    });
  }

  void _tryAdvance() {
    if (_animDone && _dataDone && mounted) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) widget.onComplete(_results);
      });
    }
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _radarCtrl.dispose();
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SourcePill(reference: widget.reference),
        Expanded(
          child: AnimatedBuilder(
            animation: Listenable.merge([_radarCtrl, _pulseCtrl]),
            builder: (context, _) => Center(
              child: SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(260, 260),
                      painter: _RadarPainter(
                        sweepAngle: _radarCtrl.value * 2 * math.pi,
                        pulseT: _pulseCtrl.value,
                      ),
                    ),
                    CustomPaint(
                      size: const Size(260, 260),
                      painter: _OrbitDotsPainter(
                          angle: _radarCtrl.value * 2 * math.pi),
                    ),
                    _ScanCenterElement(
                      reference: widget.reference,
                      pulseT: _pulseCtrl.value,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _waveCtrl,
                builder: (context, _) =>
                    _WaveformBars(t: _waveCtrl.value, phases: _wavePhases),
              ),
              const SizedBox(height: 18),
              AnimatedBuilder(
                animation: _progressCtrl,
                builder: (context, _) {
                  final p = _progressCtrl.value;
                  final statuses = _statuses(context);
                  final idx = (p * statuses.length)
                      .floor()
                      .clamp(0, statuses.length - 1);
                  return Column(
                    children: [
                      _GoldProgressBar(value: _extended ? 1.0 : p),
                      const SizedBox(height: 14),
                      Text(
                        _extended
                            ? context.t('Analyzing results…')
                            : statuses[idx],
                        style: _arabic(size: 13, color: kOud.withValues(alpha: 0.75)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _extended ? '%100' : '${(p * 100).round()}%',
                        style: _inter(size: 11, color: kGold.withValues(alpha: 0.7), letterSpacing: 1.0),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Radar painter
// ─────────────────────────────────────────────────────────────
class _RadarPainter extends CustomPainter {
  final double sweepAngle;
  final double pulseT;

  const _RadarPainter({required this.sweepAngle, required this.pulseT});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final R = size.width / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = kGold.withValues(alpha: 0.14);
    for (final r in [R * 0.62, R * 0.77, R]) {
      canvas.drawCircle(center, r, ringPaint);
    }

    for (int i = 0; i < 3; i++) {
      final t = ((pulseT + i / 3.0) % 1.0);
      final opacity = (1 - t) * 0.26;
      if (opacity > 0.005) {
        canvas.drawCircle(center, R * (0.3 + t), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = kGold.withValues(alpha: opacity));
      }
    }

    canvas.drawCircle(center, R, Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle,
        endAngle: sweepAngle + math.pi * 2,
        colors: [
          kGoldLight.withValues(alpha: 0.65),
          kGold.withValues(alpha: 0.35),
          Colors.transparent,
          Colors.transparent,
        ],
        stops: const [0.0, 0.06, 0.22, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: R)));
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      sweepAngle != old.sweepAngle || pulseT != old.pulseT;
}

// ─────────────────────────────────────────────────────────────
// Orbiting dots painter
// ─────────────────────────────────────────────────────────────
class _OrbitDotsPainter extends CustomPainter {
  final double angle;

  const _OrbitDotsPainter({required this.angle});

  static const _orbits = [
    (r: 80.0, speed: 1.0),
    (r: 100.0, speed: 0.75),
    (r: 130.0, speed: 0.60),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 260;
    final glowPaint = Paint()
      ..color = kGoldLight
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (final o in _orbits) {
      final a = angle * o.speed;
      canvas.drawCircle(
        Offset(center.dx + o.r * scale * math.cos(a),
               center.dy + o.r * scale * math.sin(a)),
        3.0 * scale,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitDotsPainter old) => angle != old.angle;
}

// ─────────────────────────────────────────────────────────────
// Scanning centre — reference perfume image in a breathing circle
// ─────────────────────────────────────────────────────────────
class _ScanCenterElement extends StatelessWidget {
  final Perfume reference;
  final double pulseT; // 0..1 repeating, drives the glow breath

  const _ScanCenterElement({required this.reference, required this.pulseT});

  @override
  Widget build(BuildContext context) {
    final glow = 0.18 + 0.18 * math.sin(pulseT * math.pi);
    final blur = 16.0 + 8.0 * math.sin(pulseT * math.pi);
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: kGold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: kGold.withValues(alpha: glow),
            blurRadius: blur,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: _PerfumeImageDisplay(perfume: reference, size: 82),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Waveform bars
// ─────────────────────────────────────────────────────────────
class _WaveformBars extends StatelessWidget {
  final double t;
  final List<double> phases;

  const _WaveformBars({required this.t, required this.phases});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        textDirection: TextDirection.ltr,
        children: List.generate(phases.length, (i) {
          final wave = (t + phases[i]) % 1.0;
          final scale = 0.25 + 0.75 * math.pow(math.sin(wave * math.pi), 2);
          return Container(
            width: 2,
            height: (24 * scale).clamp(4.0, 24.0),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [kGold, kGoldLight]),
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Gold progress bar
// ─────────────────────────────────────────────────────────────
class _GoldProgressBar extends StatelessWidget {
  final double value;

  const _GoldProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      return Stack(children: [
        Container(
          height: 3,
          decoration: BoxDecoration(
              color: kGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(1.5)),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 3,
          width: constraints.maxWidth * value,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kGoldLight, kGold]),
            borderRadius: BorderRadius.circular(1.5),
            boxShadow: [BoxShadow(color: kGold.withValues(alpha: 0.6), blurRadius: 6)],
          ),
        ),
      ]);
    });
  }
}

// ─────────────────────────────────────────────────────────────
// Reveal Screen
// ─────────────────────────────────────────────────────────────
class _RevealScreen extends StatefulWidget {
  final Perfume reference;
  final BottleDupeResult result;
  final VoidCallback onContinue;

  const _RevealScreen({
    required this.reference,
    required this.result,
    required this.onContinue,
  });

  @override
  State<_RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<_RevealScreen>
    with TickerProviderStateMixin {
  late final AnimationController _dropCtrl;
  late final AnimationController _pctCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _glowRingCtrl;
  int _revealPhase = 0;

  @override
  void initState() {
    super.initState();

    // Slightly shorter drop for snappiness; easeOutBack gives a premium bounce
    _dropCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));

    _pctCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() => _revealPhase = 2);
          // Fire the expanding glow ring on counter completion
          _glowRingCtrl.forward(from: 0);
        }
      });

    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3500))
      ..repeat();

    // Single-shot glow ring that expands + fades when match % lands
    _glowRingCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      setState(() => _revealPhase = 1);
      _dropCtrl.forward();
      HapticFeedback.mediumImpact();
    });
    Future.delayed(const Duration(milliseconds: 950), () {
      if (mounted) _pctCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _revealPhase = 3);
    });
  }

  @override
  void dispose() {
    _dropCtrl.dispose();
    _pctCtrl.dispose();
    _particleCtrl.dispose();
    _glowRingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // easeOutBack gives a subtle premium overshoot on the bottle entry
    final dropCurve =
        CurvedAnimation(parent: _dropCtrl, curve: Curves.easeOutBack);
    final targetPct = widget.result.matchPct.round().clamp(0, 100);
    final pctAnim = Tween<double>(begin: 0, end: targetPct.toDouble())
        .animate(CurvedAnimation(parent: _pctCtrl, curve: Curves.easeOut));

    return Column(
      children: [
        _SourcePill(reference: widget.reference),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                opacity: _revealPhase >= 1 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 900),
                child: const _SpotlightEffect(intensity: 0.95),
              ),
              if (_revealPhase >= 1)
                AnimatedBuilder(
                  animation: _particleCtrl,
                  builder: (context, _) =>
                      _ParticleSystem(progress: _particleCtrl.value),
                ),
              AnimatedOpacity(
                opacity: _revealPhase >= 1 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: const _LightBeam(),
              ),
              // Expanding glow ring fired when match % counter finishes
              AnimatedBuilder(
                animation: _glowRingCtrl,
                builder: (context, _) {
                  final t = _glowRingCtrl.value;
                  if (t == 0.0) return const SizedBox.shrink();
                  return IgnorePointer(
                    child: Container(
                      width: 180 + 80 * t,
                      height: 180 + 80 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: kGold.withValues(alpha: (1 - t) * 0.55),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: dropCurve,
                builder: (context, _) {
                  final t = _dropCtrl.value; // linear 0→1
                  final curve = dropCurve.value; // easeOutBack
                  return Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -28 * (1 - curve)),
                      child: Transform.scale(
                        scale: (0.82 + 0.18 * curve).clamp(0.0, 1.08),
                        child: _PerfumeImageDisplay(
                          perfume: widget.result.perfume,
                          size: 200,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        AnimatedOpacity(
          opacity: _revealPhase >= 1 ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 800),
          child: AnimatedSlide(
            offset: _revealPhase >= 1 ? Offset.zero : const Offset(0, 0.12),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
              child: Column(
                children: [
                  Text(context.t('AI MATCH'),
                      style: _serif(size: 12, color: kGold, italic: true)),
                  const SizedBox(height: 6),
                  Text(widget.result.perfume.name,
                      style: _arabic(size: 22, weight: FontWeight.w700, color: kOud),
                      textAlign: TextAlign.center),
                  Text(widget.result.perfume.brand,
                      style: _serif(size: 13, color: kWarmGray, italic: true)),
                  if (widget.result.priceRangeSar != null) ...[
                    const SizedBox(height: 2),
                    Text('~${widget.result.priceRangeSar} ${context.t('SAR')}',
                        style: _inter(size: 13, weight: FontWeight.w600, color: kGold)),
                  ],
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: pctAnim,
                    builder: (context, _) =>
                        _MatchCounter(value: pctAnim.value.round()),
                  ),
                  const SizedBox(height: 14),
                  _CtaButton(
                    armed: _revealPhase >= 3,
                    onTap: widget.onContinue,
                    label: context.t('Explore alternatives ←'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Spotlight, light beam, particles, match counter, CTA
// ─────────────────────────────────────────────────────────────
class _SpotlightEffect extends StatelessWidget {
  final double intensity;

  const _SpotlightEffect({this.intensity = 1.0});

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -1),
              radius: 0.8,
              colors: [
                kGoldLight.withValues(alpha: 0.32 * intensity),
                kGold.withValues(alpha: 0.13 * intensity),
                Colors.transparent,
              ],
              stops: const [0.0, 0.35, 0.7],
            ),
          ),
        ),
      ),
      Container(
        width: 220,
        height: 200,
        decoration: BoxDecoration(
          gradient: RadialGradient(colors: [
            kGold.withValues(alpha: 0.32 * intensity),
            kGold.withValues(alpha: 0.10 * intensity),
            Colors.transparent,
          ], stops: const [0.0, 0.35, 0.65]),
        ),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: 180,
          height: 50,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [kGold.withValues(alpha: 0.24 * intensity), Colors.transparent],
            ),
          ),
        ),
      ),
    ]);
  }
}

class _LightBeam extends StatelessWidget {
  const _LightBeam();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: 4,
        height: 110,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              kGoldLight.withValues(alpha: 0.33),
              kGold.withValues(alpha: 0.53),
              Colors.transparent,
            ],
            stops: const [0.0, 0.35, 0.80, 1.0],
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Particle {
  final double x, y, size, delay, drift;
  const _Particle({required this.x, required this.y, required this.size, required this.delay, required this.drift});
}

final _kParticles = () {
  final rnd = math.Random(99);
  return List.generate(28, (_) => _Particle(
    x: rnd.nextDouble(),
    y: 0.25 + rnd.nextDouble() * 0.65,
    size: 1.0 + rnd.nextDouble() * 2.5,
    delay: rnd.nextDouble(),
    drift: -12.0 + rnd.nextDouble() * 24.0,
  ));
}();

class _ParticleSystem extends StatelessWidget {
  final double progress;

  const _ParticleSystem({required this.progress});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      return Stack(
        clipBehavior: Clip.none,
        children: _kParticles.map((p) {
          final t = ((progress - p.delay) % 1.0 + 1.0) % 1.0;
          final yOff = t * 140.0 - 10.0;
          final opacity = t < 0.15 ? t / 0.15 : t > 0.85 ? (1.0 - t) / 0.15 : 1.0;
          return Positioned(
            left: (p.x * w + p.drift * t).clamp(0, w - p.size),
            top: (p.y * h - yOff).clamp(0, h - p.size),
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Container(
                width: p.size,
                height: p.size,
                decoration: BoxDecoration(
                  color: kGoldLight,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: kGoldLight, blurRadius: p.size * 2.5)],
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

class _MatchCounter extends StatelessWidget {
  final int value;

  const _MatchCounter({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(context.t('Match'),
            style: _inter(size: 11, color: kWarmGray, letterSpacing: 1.5)),
        const SizedBox(width: 12),
        RichText(
          text: TextSpan(children: [
            TextSpan(text: '$value', style: _serif(size: 48, weight: FontWeight.w500, color: kOud)),
            TextSpan(text: '%', style: _serif(size: 22, weight: FontWeight.w400, color: kGold)),
          ]),
        ),
      ],
    );
  }
}

class _CtaButton extends StatefulWidget {
  final bool armed;
  final VoidCallback onTap;
  final String label;

  const _CtaButton(
      {required this.armed, required this.onTap, required this.label});

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(period: const Duration(milliseconds: 2800));
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.armed) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: kGold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Center(
          child: Text(widget.label,
              style: _arabic(size: 15, weight: FontWeight.w600, color: kWarmGray)),
        ),
      );
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (context, _) {
            return Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kGoldLight, kGold],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: kGold.withValues(alpha: _pressed ? 0.25 : 0.45),
                    blurRadius: _pressed ? 10 : 20,
                    offset: Offset(0, _pressed ? 3 : 7),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Stack(
                  children: [
                    // Shimmer sweep
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment(
                            -1.6 + 3.2 * _shimmerCtrl.value, 0),
                        child: Container(
                          width: 70,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.28),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        widget.label,
                        style: _arabic(
                          size: 15,
                          weight: FontWeight.w700,
                          color: const Color(0xFF1A1208),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AI insight card — shown below the hero match
// ─────────────────────────────────────────────────────────────
class _AiInsightCard extends StatelessWidget {
  final BottleDupeResult match;

  const _AiInsightCard({required this.match});

  String _insight(BuildContext context) {
    if (match.reason.isNotEmpty) return match.reason;
    final pct = match.matchPct;
    if (pct >= 90) {
      return context.t('Exceptional match in fragrance signature — same woody and warm notes, at a much lower price.');
    } else if (pct >= 80) {
      return context.t('Similar to the original in core notes. An ideal choice if you are looking for the same feel on a smaller budget.');
    } else if (pct >= 65) {
      return context.t('Close in fragrance spirit, with slight differences in longevity and projection. Worth trying.');
    }
    return context.t('Acceptable alternative — shares some characteristics of the original at a more economical price.');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
              decoration: BoxDecoration(
                color: kGoldPale,
                border: Border.all(color: kGold.withValues(alpha: 0.15), width: 0.5),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: kGold,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('AI',
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5)),
                            ),
                            const SizedBox(width: 6),
                            Text(context.t('Why this alternative?'),
                                style: _inter(
                                    size: 11,
                                    weight: FontWeight.w600,
                                    color: kGold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(_insight(context),
                            style: _arabic(
                                size: 12,
                                color: kOud.withValues(alpha: 0.82)),
                            textAlign: TextAlign.right),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Gold accent bar on the right edge
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: Container(width: 3, color: kGold),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Perfume image — real photo if available, drawn bottle as fallback
// ─────────────────────────────────────────────────────────────
class _PerfumeImageDisplay extends StatelessWidget {
  final Perfume perfume;
  final double size;

  const _PerfumeImageDisplay({required this.perfume, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = perfume.imageUrl ?? perfume.fallbackImageUrl;
    if (url != null) {
      return SizedBox(
        width: size,
        height: size,
        child: PerfumeImage(
          primaryUrl: url,
          fallbackUrl: perfume.fallbackImageUrl,
          fallbackColor: perfume.accent,
          width: size,
          height: size,
          fit: BoxFit.contain,
          iconSize: size * 0.5,
        ),
      );
    }
    return BottleIcon(color: perfume.accent, size: size * 0.6);
  }
}


// ─────────────────────────────────────────────────────────────
// Results Screen
// ─────────────────────────────────────────────────────────────
class _ResultsScreen extends StatelessWidget {
  final Perfume reference;
  final List<BottleDupeResult> results;
  final int? referencePriceSar;
  final void Function(Perfume)? onPerfumeTap;

  const _ResultsScreen({
    required this.reference,
    required this.results,
    this.referencePriceSar,
    this.onPerfumeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Column(children: [
        _SourcePill(reference: reference),
        Expanded(
          child: Center(
            child: Text(
              context.t('No alternatives found for this perfume.'),
              style: _arabic(size: 14, color: kWarmGray),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ]);
    }

    return Column(
      children: [
        _SourcePill(reference: reference),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _HeroMatchCard(
                  match: results.first,
                  referencePriceSar: referencePriceSar,
                  onTap: onPerfumeTap),
              _AiInsightCard(match: results.first),
              if (results.length > 1) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Text(context.t('Other alternatives'),
                          style: _inter(size: 11, color: kGold, letterSpacing: 1.5)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Container(height: 0.5, color: kGold.withValues(alpha: 0.20))),
                    ],
                  ),
                ),
                ...results.skip(1).map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AltMatchCard(
                          match: m,
                          referencePriceSar: referencePriceSar,
                          onTap: onPerfumeTap),
                    )),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Hero match card
// ─────────────────────────────────────────────────────────────
class _HeroMatchCard extends StatelessWidget {
  final BottleDupeResult match;
  final int? referencePriceSar;
  final void Function(Perfume)? onTap;

  const _HeroMatchCard({required this.match, this.referencePriceSar, this.onTap});

  String get _notes {
    if (match.reason.isNotEmpty) return match.reason;
    final accords = match.perfume.accords.take(3).toList();
    return accords.isNotEmpty ? accords.join(' · ') : '';
  }

  @override
  Widget build(BuildContext context) {
    final midPrice = _parseMidPrice(match.priceRangeSar);
    final savings = (referencePriceSar != null && midPrice != null && midPrice < referencePriceSar!)
        ? ((referencePriceSar! - midPrice) / referencePriceSar! * 100).round()
        : null;

    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(match.perfume),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kGold.withValues(alpha: 0.20), width: 0.5),
          boxShadow: kCardShadow,
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: [
            Row(
              textDirection: TextDirection.rtl,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.t('The ideal alternative'),
                    style: _serif(size: 11, color: kGold, italic: true)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [kGoldLight, kGold]),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [BoxShadow(color: kGold.withValues(alpha: 0.33), blurRadius: 12)],
                  ),
                  child: Text('${match.matchPct.round()}% ${context.t('MATCH')}',
                      style: _inter(size: 10, weight: FontWeight.w600,
                          color: const Color(0xFF1A1208), letterSpacing: 0.5)),
                ),
              ],
            ),
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const _SpotlightEffect(intensity: 0.55),
                  _ParticleSystem(progress: 0.5),
                  _PerfumeImageDisplay(
                      perfume: match.perfume,
                      size: 140),
                ],
              ),
            ),
            Text(match.perfume.name,
                style: _arabic(size: 22, weight: FontWeight.w700, color: kOud)),
            const SizedBox(height: 2),
            Text(match.perfume.brand,
                style: _serif(size: 13, color: kWarmGray, italic: true)),
            if (_notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: kGoldPale,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: kGold.withValues(alpha: 0.25), width: 0.5),
                ),
                child: Text(_notes,
                    style: _arabic(size: 11, weight: FontWeight.w500, color: kOud),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: kGoldPale,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kGold.withValues(alpha: 0.20), width: 0.5),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (referencePriceSar != null)
                        Text('$referencePriceSar ${context.t('SAR')}',
                            style: _inter(size: 9, color: kWarmGray)
                                .copyWith(decoration: TextDecoration.lineThrough,
                                    decorationColor: kWarmGray)),
                      if (match.priceRangeSar != null)
                        RichText(
                          text: TextSpan(children: [
                            TextSpan(text: '~${match.priceRangeSar} ',
                                style: _inter(size: 16, weight: FontWeight.w600, color: kOud)),
                            TextSpan(text: context.t('SAR'), style: _inter(size: 10, color: kGold)),
                          ]),
                        )
                      else
                        Text(match.perfume.rating.toStringAsFixed(1),
                            style: _inter(size: 14, weight: FontWeight.w600, color: kGoldLight)),
                      if (savings != null)
                        Text('${context.t('Save money')} $savings%',
                            style: _inter(size: 9, color: kGoldLight)),
                    ],
                  ),
                  GestureDetector(
                    onTap: onTap == null ? null : () => onTap!(match.perfume),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [kGoldLight, kGold]),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [BoxShadow(color: kGold.withValues(alpha: 0.27), blurRadius: 12)],
                      ),
                      child: Text(context.t('Add to collection'),
                          style: _arabic(size: 12, weight: FontWeight.w600,
                              color: const Color(0xFF1A1208))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Alt match card
// ─────────────────────────────────────────────────────────────
class _AltMatchCard extends StatelessWidget {
  final BottleDupeResult match;
  final int? referencePriceSar;
  final void Function(Perfume)? onTap;

  const _AltMatchCard({required this.match, this.referencePriceSar, this.onTap});

  String get _notes {
    if (match.reason.isNotEmpty) return match.reason;
    final accords = match.perfume.accords.take(3).toList();
    return accords.isNotEmpty ? accords.join(' · ') : '';
  }

  @override
  Widget build(BuildContext context) {
    final body = _bodyFromColor(match.perfume.accent);
    final midPrice = _parseMidPrice(match.priceRangeSar);
    final savings = (referencePriceSar != null && midPrice != null && midPrice < referencePriceSar!)
        ? ((referencePriceSar! - midPrice) / referencePriceSar! * 100).round()
        : null;

    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(match.perfume),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: kCardShadow,
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              width: 64,
              height: 80,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                    center: const Alignment(0, -0.4),
                    radius: 0.8,
                    colors: [body, const Color(0xFF08070A)]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kGold.withValues(alpha: 0.15), width: 0.5),
              ),
              child: Center(
                child: _PerfumeImageDisplay(perfume: match.perfume, size: 56),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    textDirection: TextDirection.rtl,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(match.perfume.name,
                                style: _serif(size: 16, weight: FontWeight.w500, color: kOud),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(match.perfume.brand,
                                style: _inter(size: 10, color: kWarmGray),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kGold.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: kGold.withValues(alpha: 0.27), width: 0.5),
                        ),
                        child: Text('${match.matchPct.round()}%',
                            style: _inter(size: 10, weight: FontWeight.w600, color: kGoldLight)),
                      ),
                    ],
                  ),
                  if (_notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(_notes,
                        style: _arabic(size: 10, color: kWarmGray),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      if (match.priceRangeSar != null) ...[
                        RichText(
                          text: TextSpan(children: [
                            TextSpan(text: '~${match.priceRangeSar} ',
                                style: _inter(size: 13, weight: FontWeight.w600, color: kOud)),
                            TextSpan(text: context.t('SAR'), style: _inter(size: 9, color: kGold)),
                          ]),
                        ),
                        if (referencePriceSar != null) ...[
                          const SizedBox(width: 8),
                          Text('$referencePriceSar',
                              style: _inter(size: 9, color: kWarmGray)
                                  .copyWith(decoration: TextDecoration.lineThrough,
                                      decorationColor: kWarmGray)),
                        ],
                        if (savings != null) ...[
                          const SizedBox(width: 8),
                          Text('−$savings%', style: _inter(size: 9, color: kGoldLight)),
                        ],
                      ] else
                        Text('${match.perfume.rating.toStringAsFixed(1)} ★',
                            style: _inter(size: 12, weight: FontWeight.w600, color: kGoldLight)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Phase dots
// ─────────────────────────────────────────────────────────────
class _PhaseDots extends StatelessWidget {
  final _Phase current;
  final void Function(_Phase) onTap;

  const _PhaseDots({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _Phase.values.map((p) {
          final active = p == current;
          return GestureDetector(
            onTap: () => onTap(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              width: active ? 18 : 6,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: active ? kGold : kGold.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(2),
                boxShadow: active ? [BoxShadow(color: kGold, blurRadius: 8)] : [],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

