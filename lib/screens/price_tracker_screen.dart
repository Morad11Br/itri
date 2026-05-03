import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/hardcoded_localizations.dart';
import '../theme.dart';
import '../widgets/bottle_icon.dart';

class PriceTrackerScreen extends StatelessWidget {
  const PriceTrackerScreen({super.key});

  static const _watchlist = [
    {
      'name': 'Aventus',
      'brand': 'Creed',
      'current': 1200,
      'target': 950,
      'change': -15,
      'accent': 0xFF6B8E23,
    },
    {
      'name': 'Cambodian Oud',
      'brand': 'Amouage',
      'current': 2400,
      'target': 2000,
      'change': 5,
      'accent': 0xFF8B4513,
    },
  ];

  static const _deals = [
    {
      'store': 'Golden Scent',
      'deal': '20% off Creed this Friday only',
      'badge': 'Today only',
      'color': 0xFF1a6b3a,
    },
    {
      'store': 'Amazon.sa',
      'deal': 'Deal of the Day — Maison Margiela',
      'badge': '36% off',
      'color': 0xFFFF9900,
    },
    {
      'store': 'Riyadh Perfume Expo',
      'deal': 'Up to 50% off sets',
      'badge': '3 days',
      'color': 0xFF3D2314,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: kCream,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    AppLocalizations.of(context).priceTracker,
                    style: arabicStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context).watchlist,
                        style: arabicStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _buildWatchItem(context, _watchlist[i]),
                  ),
                  childCount: _watchlist.length,
                ),
              ),
              SliverToBoxAdapter(child: _buildAddAlert(context)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    AppLocalizations.of(context).activeDeals,
                    style: arabicStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _buildDealCard(context, _deals[i]),
                  ),
                  childCount: _deals.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWatchItem(BuildContext context, Map<String, Object> w) {
    final down = (w['change'] as int) < 0;
    final accent = Color(w['accent'] as int);
    final trendColor = down ? kSuccess : kAmber;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: kCardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(colors: [kGoldPale, Colors.white]),
            ),
            child: Center(child: BottleIcon(color: accent, size: 26)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w['brand'] as String,
                            style: serifStyle(fontSize: 11, italic: true),
                          ),
                          Text(
                            w['name'] as String,
                            style: arabicStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${w['current']} ${AppLocalizations.of(context).sar}',
                          style: arabicStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: trendColor,
                          ),
                        ),
                        Text(
                          '${down ? '↓' : '↑'} ${(w['change'] as int).abs()}%',
                          style: arabicStyle(
                            fontSize: 11,
                            color: trendColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: CustomPaint(
                    size: const Size(double.infinity, 36),
                    painter: _MiniChartPainter(color: trendColor),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ht(context, 'Target: {price} SAR', {
                        'price': w['target'],
                      }),
                      style: arabicStyle(fontSize: 11, color: kSand),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: kGoldPale,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kGold.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        context.t('Edit alert'),
                        style: arabicStyle(
                          fontSize: 11,
                          color: kGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddAlert(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kGoldPale,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: kGold.withValues(alpha: 0.4),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Text(
            context.t('Add a perfume to watch'),
            style: arabicStyle(fontSize: 13, color: kWarmGray),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kGoldLight, kGold]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              context.t('+ Add perfume'),
              style: arabicStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kOud,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDealCard(BuildContext context, Map<String, Object> d) {
    final color = Color(d['color'] as int);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: kCardShadow,
        border: Border(right: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.t(d['store'] as String),
                      style: arabicStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        context.t(d['badge'] as String),
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  context.t(d['deal'] as String),
                  style: arabicStyle(fontSize: 13, color: kWarmGray),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kGoldLight, kGold]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              context.t('View'),
              style: arabicStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kOud,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  final Color color;
  const _MiniChartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(0, h * 0.78)
      ..cubicTo(w * 0.15, h * 0.67, w * 0.3, h * 0.83, w * 0.4, h * 0.56)
      ..cubicTo(w * 0.5, h * 0.28, w * 0.65, h * 0.42, w * 0.8, h * 0.22)
      ..cubicTo(w * 0.9, h * 0.11, w * 0.95, h * 0.33, w, h * 0.17);

    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, w, h))
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Target dashed line
    final dashPaint = Paint()
      ..color = kGold.withValues(alpha: 0.6)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    double x = 0;
    const dashLen = 4.0;
    const gapLen = 3.0;
    while (x < w) {
      canvas.drawLine(
        Offset(x, h * 0.61),
        Offset(x + dashLen, h * 0.61),
        dashPaint,
      );
      x += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_MiniChartPainter old) => old.color != color;
}
