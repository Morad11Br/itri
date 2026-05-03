import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/hardcoded_localizations.dart';
import '../services/subscription_service.dart';
import '../models/ai_recommendation.dart';
import '../models/perfume.dart';
import '../theme.dart';
import '../widgets/bottle_icon.dart';
import '../widgets/perfume_image.dart';

typedef OccasionFinder =
    Future<List<Perfume>> Function({
      required List<String> occasionAccords,
      required List<String> styleAccords,
      required List<String> seasonAccords,
      String? gender,
      int limit,
    });

typedef AiFinder =
    Future<List<AiRecommendation>> Function({
      required String occasion,
      required String style,
      required String gender,
      required String season,
      required String intensity,
    });

class OccasionScreen extends StatefulWidget {
  final List<Perfume> perfumes;
  final OccasionFinder? onFindPerfumes;
  final AiFinder? onFindByAi;
  final FutureOr<void> Function(Perfume)? onPerfumeTap;
  final VoidCallback? onRequireUpgrade;

  const OccasionScreen({
    super.key,
    required this.perfumes,
    this.onFindPerfumes,
    this.onFindByAi,
    this.onPerfumeTap,
    this.onRequireUpgrade,
  });

  @override
  State<OccasionScreen> createState() => _OccasionScreenState();
}

class _OccasionScreenState extends State<OccasionScreen> {
  String _occasion = 'Eid';
  String _season = 'Winter';
  String _intensity = 'Medium';
  String _recipient = 'Men';
  String _style = 'Classic';
  bool _showResults = false;
  bool _loadingResults = false;
  String? _resultError;
  List<Perfume> _results = const [];
  Map<String, String> _aiReasons = {};

  final _occasions = [
    'Eid',
    'Wedding',
    'Umrah',
    'Job interview',
    'Date',
    'Daily',
  ];

  static const _occasionAccords = {
    'Eid': ['oud', 'amber', 'warm spicy'],
    'Wedding': ['floral', 'white floral', 'powdery'],
    'Umrah': ['musky', 'fresh', 'clean'],
    'Job interview': ['fresh', 'woody', 'aromatic'],
    'Date': ['sweet', 'vanilla', 'amber'],
    'Daily': ['citrus', 'fresh', 'aromatic'],
  };

  static const _styleAccords = {
    'Classic': ['woody', 'amber'],
    'Modern': ['fresh', 'citrus'],
    'Niche': ['oud', 'leather', 'smoky'],
    'Traditional': ['oud', 'musky'],
  };

  static const _seasonAccords = {
    'Summer': ['citrus', 'fresh', 'aquatic', 'green'],
    'Winter': ['oud', 'amber', 'warm spicy', 'woody'],
    'Spring': ['floral', 'fresh', 'light floral'],
    'Autumn': ['woody', 'spicy', 'musky'],
  };

  static const _intensityAccords = {
    'Light': ['citrus', 'fresh', 'aquatic'],
    'Medium': ['floral', 'woody', 'musky'],
    'Strong': ['oud', 'amber', 'leather', 'smoky'],
  };

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: kCream,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('Perfume finder'),
                  style: arabicStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                Text(
                  context.t('Find the perfect perfume for the occasion'),
                  style: arabicStyle(fontSize: 14, color: kWarmGray),
                ),
                const SizedBox(height: 16),
                _buildOccasionCard(),
                const SizedBox(height: 12),
                _buildSeasonCard(),
                const SizedBox(height: 12),
                _buildIntensityCard(),
                const SizedBox(height: 12),
                _buildRecipientStyleRow(),
                const SizedBox(height: 16),
                _buildCTA(),
                if (_showResults) ...[
                  const SizedBox(height: 16),
                  if (_loadingResults)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kGold,
                          ),
                        ),
                      ),
                    )
                  else if (_resultError != null)
                    Text(
                      _resultError!,
                      style: arabicStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    )
                  else
                    ..._results.map(_buildResultCard),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOccasionCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Occasion'),
            style: arabicStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _occasions.map((o) {
              final active = o == _occasion;
              return GestureDetector(
                onTap: () => setState(() => _occasion = o),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: active ? kOud : kCream,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? kOud : const Color(0xFFE5DDD4),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    context.t(o),
                    style: arabicStyle(
                      fontSize: 13,
                      color: active ? Colors.white : kWarmGray,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Season'),
            style: arabicStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: ['Summer', 'Autumn', 'Winter', 'Spring'].map((s) {
              final active = s == _season;
              const icons = {
                'Summer': '☀️',
                'Autumn': '🍂',
                'Winter': '❄️',
                'Spring': '🌸',
              };
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _season = s),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? kOud : kCream,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? kOud : const Color(0xFFE5DDD4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(icons[s]!, style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 2),
                        Text(
                          context.t(s),
                          textAlign: TextAlign.center,
                          style: arabicStyle(
                            fontSize: 12,
                            color: active ? Colors.white : kWarmGray,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildIntensityCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Intensity'),
            style: arabicStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: ['Light', 'Medium', 'Strong'].map((i) {
              final active = i == _intensity;
              const desc = {
                'Light': 'Fresh',
                'Medium': 'Balanced',
                'Strong': 'Concentrated',
              };
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _intensity = i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? kOud : kCream,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? kOud : const Color(0xFFE5DDD4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          context.t(i),
                          textAlign: TextAlign.center,
                          style: arabicStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : kEspresso,
                          ),
                        ),
                        Text(
                          context.t(desc[i]!),
                          textAlign: TextAlign.center,
                          style: arabicStyle(
                            fontSize: 10,
                            color: active ? Colors.white70 : kSand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientStyleRow() {
    return Row(
      children: [
        Expanded(
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('Recipient'),
                  style: arabicStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...['Men', 'Women', 'Unisex'].map((r) {
                  final active = r == _recipient;
                  return GestureDetector(
                    onTap: () => setState(() => _recipient = r),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        vertical: 7,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: active ? kOud : kCream,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: active ? kOud : const Color(0xFFE5DDD4),
                        ),
                      ),
                      child: Text(
                        context.t(r),
                        textAlign: TextAlign.center,
                        style: arabicStyle(
                          fontSize: 12,
                          color: active ? Colors.white : kWarmGray,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('Style'),
                  style: arabicStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...['Classic', 'Modern', 'Niche', 'Traditional'].map((s) {
                  final active = s == _style;
                  return GestureDetector(
                    onTap: () => setState(() => _style = s),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        vertical: 7,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: active ? kOud : kCream,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: active ? kOud : const Color(0xFFE5DDD4),
                        ),
                      ),
                      child: Text(
                        context.t(s),
                        textAlign: TextAlign.center,
                        style: arabicStyle(
                          fontSize: 12,
                          color: active ? Colors.white : kWarmGray,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCTA() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loadingResults ? null : _findPerfumes,
        style: ElevatedButton.styleFrom(
          backgroundColor: kGold,
          foregroundColor: kOud,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 6,
        ),
        child: Text(
          widget.onFindByAi != null
              ? context.t('Find your perfume with AI ✨')
              : context.t('Find the perfect perfume 🌟'),
          style: arabicStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kOud,
          ),
        ),
      ),
    );
  }

  Future<void> _findPerfumes() async {
    final occasionAccords = _occasionAccords[_occasion] ?? const <String>[];
    final styleAccords = _styleAccords[_style] ?? const <String>[];
    final gender = _selectedGender();

    setState(() {
      _showResults = true;
      _loadingResults =
          widget.onFindByAi != null || widget.onFindPerfumes != null;
      _resultError = null;
      _aiReasons = {};
      _results = _findLocalResults(
        occasionAccords: occasionAccords,
        styleAccords: styleAccords,
        seasonAccords: _seasonAccords[_season] ?? [],
        gender: gender,
      );
    });

    // AI path — preferred when available, Pro-gated
    if (widget.onFindByAi != null) {
      if (!SubscriptionService.instance.isPro.value) {
        if (mounted) setState(() => _loadingResults = false);
        widget.onRequireUpgrade?.call();
        return;
      }
      try {
        final recs = await widget.onFindByAi!(
          occasion: _occasion,
          style: _style,
          gender: gender ?? 'unisex',
          season: _season,
          intensity: _intensity,
        );
        if (!mounted) return;
        setState(() {
          _results = recs.map((r) => r.perfume).toList();
          _aiReasons = {for (final r in recs) r.perfume.id: r.reason};
        });
        return;
      } catch (_) {
        // fall through to rule-based
      } finally {
        if (mounted) setState(() => _loadingResults = false);
      }
    }

    // Rule-based fallback
    if (widget.onFindPerfumes == null) {
      if (mounted) setState(() => _loadingResults = false);
      return;
    }

    final seasonAccords = _seasonAccords[_season] ?? [];
    final intensityAccords = _intensityAccords[_intensity] ?? [];
    try {
      final results = await widget.onFindPerfumes!(
        occasionAccords: occasionAccords,
        styleAccords: [...styleAccords, ...intensityAccords],
        seasonAccords: seasonAccords,
        gender: gender,
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _results = results.isNotEmpty
            ? results
            : _findLocalResults(
                occasionAccords: occasionAccords,
                styleAccords: styleAccords,
                seasonAccords: seasonAccords,
                gender: gender,
              );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resultError = context.t(
          'Failed to load results. Showing best available local options.',
        );
        _results = _findLocalResults(
          occasionAccords: occasionAccords,
          styleAccords: styleAccords,
          seasonAccords: seasonAccords,
          gender: gender,
        );
      });
    } finally {
      if (mounted) setState(() => _loadingResults = false);
    }
  }

  String? _selectedGender() {
    return switch (_recipient) {
      'Men' => 'men',
      'Women' => 'women',
      'Unisex' => 'unisex',
      _ => null,
    };
  }

  List<Perfume> _findLocalResults({
    required List<String> occasionAccords,
    required List<String> styleAccords,
    required List<String> seasonAccords,
    required String? gender,
  }) {
    final results = widget.perfumes.where((perfume) {
      final genderMatch = switch (gender) {
        'men' => perfume.gender == 'Men',
        'women' => perfume.gender == 'Women',
        'unisex' => perfume.gender == 'Unisex',
        _ => true,
      };
      return genderMatch;
    }).toList();

    results.sort((a, b) {
      final scoreB = _matchScore(
        b,
        occasionAccords,
        styleAccords,
        seasonAccords,
      );
      final scoreA = _matchScore(
        a,
        occasionAccords,
        styleAccords,
        seasonAccords,
      );
      final scoreCompare = scoreB.compareTo(scoreA);
      if (scoreCompare != 0) return scoreCompare;
      return b.rating.compareTo(a.rating);
    });
    return (results.isEmpty ? widget.perfumes : results).take(10).toList();
  }

  int _matchScore(
    Perfume perfume,
    List<String> occasionAccords,
    List<String> styleAccords,
    List<String> seasonAccords,
  ) {
    final accords = perfume.accords.map((a) => a.toLowerCase()).toSet();
    final occasionMatches = occasionAccords.where(accords.contains).length;
    final styleMatches = styleAccords.where(accords.contains).length;
    final seasonMatches = seasonAccords.where(accords.contains).length;
    return (occasionMatches * 2) + (styleMatches * 4) + (seasonMatches * 3);
  }

  Widget _buildResultCard(Perfume perfume) {
    final accent = perfume.accent;
    return GestureDetector(
      onTap: widget.onPerfumeTap == null
          ? null
          : () => widget.onPerfumeTap!(perfume),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: kCardShadow,
          border: Border(right: BorderSide(color: accent, width: 3)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [kGoldPale, Colors.white],
                ),
              ),
              child: _buildPerfumeImage(perfume, 28),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    perfume.brand,
                    style: serifStyle(fontSize: 11, italic: true),
                  ),
                  Text(
                    perfume.name,
                    style: arabicStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _aiReasons[perfume.id] ?? _recommendationText(perfume),
                    style: arabicStyle(
                      fontSize: 11,
                      color: _aiReasons.containsKey(perfume.id)
                          ? kGold
                          : kWarmGray,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${perfume.rating.toStringAsFixed(1)} ★',
                  style: arabicStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kGold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [kGoldLight, kGold]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.t('View'),
                    style: arabicStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kOud,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerfumeImage(Perfume p, double fallbackSize) {
    final imageUrl = p.imageUrl ?? p.fallbackImageUrl;
    if (imageUrl == null) {
      return Center(
        child: BottleIcon(color: p.accent, size: fallbackSize),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: PerfumeImage(
        primaryUrl: imageUrl,
        fallbackUrl: p.fallbackImageUrl,
        fallbackColor: p.accent,
        fit: BoxFit.cover,
        iconSize: fallbackSize,
      ),
    );
  }

  String _recommendationText(Perfume perfume) {
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

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: kCardShadow,
      ),
      child: child,
    );
  }
}
