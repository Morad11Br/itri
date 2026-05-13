import 'package:flutter/material.dart';
import '../theme.dart';
import '../l10n/hardcoded_localizations.dart';

/// Elegant animated match-score pill.
///
/// Counts up from 0 to [score] over 700 ms with an ease-out curve.
/// Uses a soft gold gradient background so it feels premium without
/// screaming for attention.
class MatchScoreBadge extends StatelessWidget {
  final int score;

  const MatchScoreBadge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFDF8EC), Color(0xFFF5ECD8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: kGold.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: score),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) {
              return Text(
                '$value%',
                style: arabicStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kGold,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          Text(
            context.t('Match'),
            style: arabicStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: kWarmGray,
            ),
          ),
        ],
      ),
    );
  }
}
