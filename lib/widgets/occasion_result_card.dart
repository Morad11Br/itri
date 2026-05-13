import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/perfume.dart';
import '../l10n/hardcoded_localizations.dart';
import 'bottle_icon.dart';
import 'perfume_image.dart';
import 'match_score_badge.dart';

/// Premium occasion-result card with press feedback, match-score badge,
/// metadata chips, and a larger curated image.
class OccasionResultCard extends StatefulWidget {
  final Perfume perfume;
  final String? aiReason;
  final int matchScore;
  final List<String> metadataChips;
  final VoidCallback? onTap;

  const OccasionResultCard({
    super.key,
    required this.perfume,
    this.aiReason,
    required this.matchScore,
    required this.metadataChips,
    this.onTap,
  });

  @override
  State<OccasionResultCard> createState() => _OccasionResultCardState();
}

class _OccasionResultCardState extends State<OccasionResultCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _entranceController;
  late final Animation<double> _entranceAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    // Slight delay so the user notices the transition
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.perfume;
    final isAi = widget.aiReason != null && widget.aiReason!.isNotEmpty;

    return FadeTransition(
      opacity: _entranceAnimation,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: kEspresso.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: kEspresso.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image ──────────────────────────────────────────────
                _buildImage(p),
                const SizedBox(width: 14),
                // ── Content ────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand
                      Text(
                        p.brand,
                        style: serifStyle(
                          fontSize: 11,
                          color: kSand,
                          italic: true,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Name
                      Text(
                        p.name,
                        style: arabicStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kEspresso,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      // AI reason / fallback description
                      Text(
                        widget.aiReason ?? _recommendationText(context, p),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: arabicStyle(
                          fontSize: 11,
                          color: isAi ? kGold : kWarmGray,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Metadata chips
                      if (widget.metadataChips.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.metadataChips
                              .map((c) => _buildChip(context, c))
                              .toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // ── Right column: match score + rating ────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MatchScoreBadge(score: widget.matchScore),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: kGold.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          p.rating.toStringAsFixed(1),
                          style: arabicStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: kSand,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(Perfume p) {
    final imageUrl = p.imageUrl ?? p.fallbackImageUrl;
    return Container(
      width: 72,
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: p.accent.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: p.accent.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          color: kGoldPale,
          child: imageUrl == null
              ? Center(
                  child: BottleIcon(color: p.accent, size: 32),
                )
              : PerfumeImage(
                  primaryUrl: imageUrl,
                  fallbackUrl: p.fallbackImageUrl,
                  fallbackColor: p.accent,
                  width: 72,
                  height: 90,
                  fit: BoxFit.cover,
                  iconSize: 32,
                ),
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kCream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5DDD4)),
      ),
      child: Text(
        label,
        style: arabicStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: kWarmGray,
        ),
      ),
    );
  }

  String _recommendationText(BuildContext context, Perfume perfume) {
    final notes = [
      ...perfume.topNotes,
      ...perfume.heartNotes,
      ...perfume.baseNotes,
    ].take(3).map((note) => context.t(note.name)).join('، ');
    if (notes.isEmpty) {
      return context.t('Picked from FragDB data by rating and popularity');
    }
    return ht(context, 'Featured notes: {notes}', {'notes': notes});
  }
}
