import 'package:flutter/material.dart';
import '../theme.dart';

/// A smart, elegantly-styled recommendation summary that appears above
/// the occasion results list. Generates dynamic Arabic copy based on the
/// user's selected filters so the app feels personalised and intelligent.
class PerfumeIntelligenceHeader extends StatelessWidget {
  final String occasion;
  final String season;
  final String style;
  final String intensity;

  const PerfumeIntelligenceHeader({
    super.key,
    required this.occasion,
    required this.season,
    required this.style,
    required this.intensity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: kGold,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _headline,
                  style: arabicStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kOud,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _subheadline,
                  style: arabicStyle(
                    fontSize: 12,
                    color: kWarmGray,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _headline {
    // Compose a headline that mixes season + style
    final seasonArabic = _seasonMap[season] ?? season;
    final styleArabic = _styleMap[style] ?? style;
    return 'أفضل الخيارات لذوقك $seasonArabic $styleArabic';
  }

  String get _subheadline {
    // Compose a subheadline that mixes intensity + occasion
    final intensityDesc = _intensityDesc[intensity] ?? '';
    final occasionDesc = _occasionDesc[occasion] ?? '';
    if (intensityDesc.isNotEmpty && occasionDesc.isNotEmpty) {
      return 'عطور $intensityDesc $occasionDesc';
    }
    return 'تم اختيار هذه العطور بناءً على تفضيلاتك';
  }

  static const _seasonMap = {
    'Summer': 'الصيفي',
    'Winter': 'الشتوي',
    'Spring': 'الربيعي',
    'Autumn': 'الخريفي',
  };

  static const _styleMap = {
    'Classic': 'الكلاسيكي',
    'Modern': 'العصري',
    'Niche': 'النيش',
    'Traditional': 'التقليدي',
  };

  static const _intensityDesc = {
    'Light': 'خفيفة بانتعاش متوسط',
    'Medium': 'فاخرة بثبات متوسط',
    'Strong': 'فاخرة بثبات قوي وفوحان مميز',
  };

  static const _occasionDesc = {
    'Eid': 'مناسبة للعيد والمناسبات المباركة',
    'Wedding': 'مناسبة للأفراح والسهرات',
    'Umrah': 'مناسبة للعمرة والمناسبات الروحانية',
    'Job interview': 'مناسبة للقاءات المهنية والعمل',
    'Date': 'مناسبة للمواعيد والسهرات الرومانسية',
    'Daily': 'مناسبة لليوميات والاستخدام المتكرر',
  };
}
