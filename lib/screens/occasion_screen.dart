import 'dart:async';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../l10n/hardcoded_localizations.dart';
import '../services/subscription_service.dart';
import '../models/ai_recommendation.dart';
import '../models/perfume.dart';
import '../theme.dart';
import '../widgets/occasion_result_card.dart';
import '../widgets/perfume_intelligence_header.dart';
import '../widgets/paywall_sheet.dart';

typedef OccasionFinder =
    Future<List<Perfume>> Function({
      required List<String> occasionAccords,
      required List<String> styleAccords,
      required List<String> seasonAccords,
      String? gender,
      int limit,
      String? priceTier,
      List<String>? tierBrands,
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
  String _priceTier = 'All';
  bool _showResults = false;
  bool _loadingResults = false;
  String? _resultError;
  List<Perfume> _results = const [];
  Map<String, String> _aiReasons = {};
  bool _isOnline = true;

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

  static const _priceTiers = ['All', 'Budget', 'Mid', 'Premium', 'Niche'];

  static const _tierBrands = {
    'Budget': [
      'lattafa', 'rasasi', 'armaf', 'al rehab', 'swiss arabian',
      'club de nuit', 'sterling parfums', 'afnan', 'ard al zaafaran',
      'al haramain', 'ajmal', 'nabeel', 'sapil', 'riiffs',
      'maison alhambra', 'milestone', 'emper', 'vurv', 'asdaaf',
      'fragrance world', 'flavia', 'paris corner', 'orientica',
      'byron', 'just jack', 'aldehyde', 'alt', 'dossier',
      'oakcha', 'oil perfumery', 'dual scent', 'french factor',
      'la rive', 'jovan', 'coty', 'avon', 'mary kay',
      'reminiscence', 's.oliver', 'benetton', 'arabian oud',
    ],
    'Mid': [
      'versace', 'hugo boss', 'montblanc', 'calvin klein',
      'davidoff', 'lacoste', 'prada', 'coach', 'guess',
      'nautica', 'kenneth cole', 'perry ellis', 'azzaro',
      'issey miyake', 'narciso rodriguez', 'carolina herrera',
      'paco rabanne', 'jean paul gaultier', 'dolce gabbana',
      'ralph lauren', 'salvatore ferragamo', 'bvlgari', 'burberry',
      'dunhill', 'bentley', 'jaguar', 'mercedes benz', 'mancera',
      'banana republic', 'gucci', 'lancome', 'elizabeth arden',
      'kenzo', 'loewe', 'marc jacobs', 'diesel', 'dkny',
      'escada', 'joop', 'cacharel', 'chopard', 'ferrari',
    ],
    'Premium': [
      'dior', 'chanel', 'ysl', 'givenchy', 'prada',
      'armani', 'guerlain', 'hermes', 'lanvin', 'cartier',
      'valentino', 'bvlgari', 'coach', 'jimmy choo', 'tiffany',
      'marc jacobs', 'elie saab', 'narciso rodriguez', 'victor', 'roja',
    ],
    'Niche': [
      'tom ford', 'creed', 'amouage', 'maison francis kurkdjian',
      'mfk', 'initio', 'xerjoff', 'parfums de marly',
      'byredo', 'diptyque', 'le labo', 'frederic malle', 'serge lutens',
      'kilian', 'clive christian', 'roja dove', 'bond no. 9', 'nasomatto',
      'ormonde jayne', 'neela vermeire', 'boadicea', 'fort & manle',
      'tauer', 'dusita', 'strangers', 'hiba', 'ensar oud',
    ],
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
                const SizedBox(height: 12),
                _buildPriceTierCard(),
                const SizedBox(height: 16),
                if (!_isOnline) _buildOfflineBanner(),
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
                  else ...[
                    PerfumeIntelligenceHeader(
                      occasion: _occasion,
                      season: _season,
                      style: _style,
                      intensity: _intensity,
                    ),
                    if (_results.isEmpty)
                      _buildEmptyState()
                    else
                      ..._results.map((perfume) {
                        final occasionAccords =
                            _occasionAccords[_occasion] ?? const <String>[];
                        final styleAccords =
                            _styleAccords[_style] ?? const <String>[];
                        final seasonAccords =
                            _seasonAccords[_season] ?? const <String>[];
                        return OccasionResultCard(
                          key: ValueKey(perfume.id),
                          perfume: perfume,
                          aiReason: _aiReasons[perfume.id],
                          matchScore: _matchPercentage(
                            perfume,
                            occasionAccords,
                            styleAccords,
                            seasonAccords,
                          ),
                          metadataChips: _perfumeMetadata(context, perfume),
                          onTap: widget.onPerfumeTap == null
                              ? null
                              : () => widget.onPerfumeTap!(perfume),
                        );
                      }),
                  ],
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

  Widget _buildPriceTierCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Price tier'),
            style: arabicStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _priceTiers.map((t) {
              final active = t == _priceTier;
              return GestureDetector(
                onTap: () => setState(() => _priceTier = t),
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
                    context.t(t),
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

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.t('No internet connection. Connect to search the full database.'),
              style: arabicStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTA() {
    final hasAi = widget.onFindByAi != null;
    final isPro = SubscriptionService.instance.isPro.value;
    return Column(
      children: [
        SizedBox(
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
              hasAi && isPro
                  ? context.t('Find your perfume with AI ✨')
                  : context.t('Find the perfect perfume 🌟'),
              style: arabicStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kOud,
              ),
            ),
          ),
        ),
        if (hasAi && !isPro) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => PaywallBottomSheet.show(
              context,
              message: context.t('AI recommendations require Premium'),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kGoldLight, kGold],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded, size: 12, color: kOud),
                  const SizedBox(width: 4),
                  Text(
                    '${context.t('AI')} ${context.t('Premium')}',
                    style: arabicStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kOud,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Future<bool> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final online = results.isNotEmpty &&
        results.any((r) => r != ConnectivityResult.none);
    if (_isOnline != online) setState(() => _isOnline = online);
    return online;
  }

  Future<void> _findPerfumes() async {
    final isOnline = await _checkConnectivity();
    if (!isOnline) {
      setState(() {
        _showResults = true;
        _loadingResults = false;
        _resultError = context.t('No internet connection. Please check your network and try again.');
      });
      return;
    }

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

    // AI path — Premium only
    if (widget.onFindByAi != null) {
      final isPro = SubscriptionService.instance.isPro.value;
      if (isPro) {
        try {
          final recs = await widget.onFindByAi!(
            occasion: _occasion,
            style: _style,
            gender: gender ?? 'unisex',
            season: _season,
            intensity: _intensity,
          );
          if (!mounted) return;
          final filtered = recs.where((r) => _matchesPriceTier(r.perfume)).toList();
          setState(() {
            _results = filtered.map((r) => r.perfume).toList();
            _aiReasons = {for (final r in filtered) r.perfume.id: r.reason};
          });
          return;
        } catch (_) {
          // fall through to rule-based
        } finally {
          if (mounted) setState(() => _loadingResults = false);
        }
      }
      // Free users silently fall through to rule-based — no blocking paywall
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
        priceTier: _priceTier,
        tierBrands: _tierBrands[_priceTier],
      );
      if (!mounted) return;
      setState(() {
        _results = results.isNotEmpty
            ? results.where(_matchesPriceTier).toList()
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

  bool _matchesPriceTier(Perfume perfume) {
    if (_priceTier == 'All') return true;
    final brands = _tierBrands[_priceTier];
    if (brands == null || brands.isEmpty) return true;
    final brandLower = perfume.brand.toLowerCase();
    return brands.any((b) => brandLower.contains(b));
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
      return genderMatch && _matchesPriceTier(perfume);
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

  int _matchPercentage(
    Perfume perfume,
    List<String> occasionAccords,
    List<String> styleAccords,
    List<String> seasonAccords,
  ) {
    final raw = _matchScore(perfume, occasionAccords, styleAccords, seasonAccords);
    final maxScore = (occasionAccords.length * 2) +
        (styleAccords.length * 4) +
        (seasonAccords.length * 3);
    if (maxScore == 0) return 75;
    return ((raw / maxScore) * 100).round().clamp(62, 98);
  }

  List<String> _perfumeMetadata(BuildContext context, Perfume p) {
    final chips = <String>[];
    final accords = p.accords.map((a) => a.toLowerCase()).toSet();

    final heavy = {'oud', 'amber', 'leather', 'smoky', 'warm spicy', 'patchouli'};
    final fresh = {'citrus', 'fresh', 'aquatic', 'green', 'aromatic'};
    final hasHeavy = accords.intersection(heavy).isNotEmpty;
    final hasFresh = accords.intersection(fresh).isNotEmpty;

    // Performance
    if (_intensity == 'Strong' || hasHeavy) {
      chips.add(context.t('🔥 Strong projection'));
    } else if (_intensity == 'Medium') {
      chips.add(context.t('✨ Moderate projection'));
    } else if (_intensity == 'Light' || hasFresh) {
      chips.add(context.t('🍃 Light projection'));
    }

    // Longevity
    if (hasHeavy) {
      chips.add(context.t('🕒 Long lasting'));
    } else {
      chips.add(context.t('⏱️ Moderate longevity'));
    }

    // Notes family
    if (accords.any((a) =>
        a.contains('oud') || a.contains('woody') || a.contains('cedar') || a.contains('sandalwood'))) {
      chips.add(context.t('🌲 Woody notes'));
    } else if (accords.any((a) =>
        a.contains('floral') || a.contains('rose') || a.contains('jasmine'))) {
      chips.add(context.t('🌸 Floral notes'));
    } else if (accords.any((a) =>
        a.contains('citrus') || a.contains('fresh') || a.contains('aquatic'))) {
      chips.add(context.t('🍊 Fresh notes'));
    } else if (accords.any((a) => a.contains('spicy'))) {
      chips.add(context.t('🌶️ Spicy notes'));
    }

    // Occasion fit
    final evening = {'Date', 'Wedding', 'Eid'};
    final day = {'Daily', 'Job interview', 'Umrah'};
    if (evening.contains(_occasion)) {
      chips.add(context.t('🌙 Evening wear'));
    } else if (day.contains(_occasion)) {
      chips.add(context.t('☀️ Day wear'));
    }

    return chips.take(3).toList();
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: kCardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: kSand.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            context.t('No perfumes found matching your criteria'),
            textAlign: TextAlign.center,
            style: arabicStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kWarmGray,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t('Try adjusting the occasion, season, or price filters'),
            textAlign: TextAlign.center,
            style: arabicStyle(
              fontSize: 13,
              color: kSand,
            ),
          ),
        ],
      ),
    );
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
