import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/hardcoded_localizations.dart';
import '../services/subscription_service.dart';
import '../models/dupe_recommendation.dart';
import '../models/perfume.dart';
import '../theme.dart';
import '../widgets/bottle_icon.dart';
import '../widgets/perfume_image.dart';

typedef ScentFinder =
    Future<List<Perfume>> Function({
      required List<String> occasionAccords,
      required List<String> styleAccords,
      required List<String> seasonAccords,
      String? gender,
      int limit,
    });

class ScentFinderScreen extends StatefulWidget {
  final Future<List<Perfume>> Function(String query)? onSearchPerfumes;
  final Future<Perfume> Function(String id)? onLoadDetails;
  final ScentFinder? onFindSimilar;
  final Future<DupeFinderResult> Function(
    Perfume reference,
    int? referencePriceSar,
  )?
  onFindDupesByAi;
  final FutureOr<void> Function(Perfume)? onPerfumeTap;
  final VoidCallback? onRequireUpgrade;

  const ScentFinderScreen({
    super.key,
    this.onSearchPerfumes,
    this.onLoadDetails,
    this.onFindSimilar,
    this.onFindDupesByAi,
    this.onPerfumeTap,
    this.onRequireUpgrade,
  });

  @override
  State<ScentFinderScreen> createState() => _ScentFinderScreenState();
}

class _ScentFinderScreenState extends State<ScentFinderScreen> {
  // Search state
  final _searchCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  Timer? _debounce;
  List<Perfume> _searchResults = const [];
  bool _searching = false;

  // Reference perfume
  Perfume? _reference;
  bool _loadingReference = false;

  // Clone results
  List<_DupeResult> _dupes = const [];
  bool _loadingDupes = false;
  bool _showDupes = false;
  String? _error;
  String? _referenceEstimatedPrice;

  int? get _referencePriceSar => int.tryParse(_priceCtrl.text.trim());

  @override
  void dispose() {
    _searchCtrl.dispose();
    _priceCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _searchResults = const []);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _runSearch(query),
    );
  }

  Future<void> _runSearch(String query) async {
    if (widget.onSearchPerfumes == null) return;
    setState(() => _searching = true);
    try {
      final results = await widget.onSearchPerfumes!(query);
      if (!mounted) return;
      setState(() => _searchResults = results);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectReference(Perfume p) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loadingReference = true;
      _searchResults = const [];
      _showDupes = false;
      _dupes = const [];
    });

    Perfume detail = p;
    if (widget.onLoadDetails != null && p.id.isNotEmpty) {
      try {
        detail = await widget.onLoadDetails!(p.id);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _reference = detail;
      _loadingReference = false;
      _searchCtrl.clear();
    });
  }

  Future<void> _findClones() async {
    final ref = _reference;
    if (ref == null) return;

    if (!SubscriptionService.instance.isPro.value) {
      widget.onRequireUpgrade?.call();
      return;
    }

    setState(() {
      _showDupes = true;
      _loadingDupes = true;
      _error = null;
      _dupes = const [];
    });

    // AI path — preferred
    if (widget.onFindDupesByAi != null) {
      try {
        final result = await widget.onFindDupesByAi!(ref, _referencePriceSar);
        if (!mounted) return;
        setState(() {
          _referenceEstimatedPrice = result.referencePriceRangeSar;
          _dupes = result.dupes
              .map(
                (r) => _DupeResult(
                  perfume: r.perfume,
                  similarity: r.similarityPct.toDouble(),
                  aiReason: r.reason,
                  priceRangeSar: r.priceRangeSar,
                ),
              )
              .toList();
        });
        return;
      } catch (_) {
        // fall through to Jaccard
      } finally {
        if (mounted) setState(() => _loadingDupes = false);
      }
    }

    // Jaccard fallback
    try {
      List<Perfume> candidates = const [];
      if (widget.onFindSimilar != null && ref.accords.isNotEmpty) {
        candidates = await widget.onFindSimilar!(
          occasionAccords: ref.accords,
          styleAccords: [],
          seasonAccords: [],
          limit: 60,
        );
      }

      final refAllNotes = {
        ...ref.topNotes.map((n) => n.id.toLowerCase()),
        ...ref.heartNotes.map((n) => n.id.toLowerCase()),
        ...ref.baseNotes.map((n) => n.id.toLowerCase()),
      };

      final dupes =
          candidates
              .where((p) => p.id != ref.id)
              .map((p) {
                final score = _similarityScore(ref, refAllNotes, p);
                return _DupeResult(perfume: p, similarity: score);
              })
              .where((d) => d.similarity >= 15)
              .toList()
            ..sort((a, b) => b.similarity.compareTo(a.similarity));

      if (!mounted) return;
      setState(() => _dupes = dupes.take(20).toList());
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = ht(
          context,
          'Could not load results. Check your connection and try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingDupes = false);
    }
  }

  double _similarityScore(
    Perfume ref,
    Set<String> refNotes,
    Perfume candidate,
  ) {
    // Jaccard on accords (weighted 70%)
    final refAccords = ref.accords.toSet();
    final candAccords = candidate.accords.toSet();
    final accordIntersection = refAccords.intersection(candAccords).length;
    final accordUnion = refAccords.union(candAccords).length;
    final accordJaccard = accordUnion == 0
        ? 0.0
        : accordIntersection / accordUnion;

    // Jaccard on notes (weighted 30%) — candidate may not have notes loaded
    double noteJaccard = 0.0;
    if (refNotes.isNotEmpty) {
      final candNotes = {
        ...candidate.topNotes.map((n) => n.id.toLowerCase()),
        ...candidate.heartNotes.map((n) => n.id.toLowerCase()),
        ...candidate.baseNotes.map((n) => n.id.toLowerCase()),
      };
      if (candNotes.isNotEmpty) {
        final intersection = refNotes.intersection(candNotes).length;
        final union = refNotes.union(candNotes).length;
        noteJaccard = union == 0 ? 0.0 : intersection / union;
      }
    }

    return ((accordJaccard * 0.7) + (noteJaccard * 0.3)) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: kCream,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Expanded(
                child: _showDupes && _reference != null
                    ? _buildDupesView()
                    : _buildSearchView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_showDupes)
                GestureDetector(
                  onTap: () => setState(() {
                    _showDupes = false;
                    _dupes = const [];
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(left: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: kCardShadow,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 15,
                      color: kOud,
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('Dupe Finder'),
                    style: arabicStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    context.t('Find a similar perfume for less'),
                    style: arabicStyle(fontSize: 13, color: kWarmGray),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const _popularSearches = [
    'Baccarat Rouge 540',
    'Creed Aventus',
    'Dior Sauvage',
    'Tom Ford Oud Wood',
    'Maison Margiela Replica',
    'Chanel No. 5',
    'Amouage Interlude',
    'Initio Oud for Greatness',
  ];

  Widget _buildSearchView() {
    final showEmpty =
        _reference == null &&
        _searchCtrl.text.isEmpty &&
        !_searching;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _buildSearchBar(),
        ),
        if (_reference != null && _searchCtrl.text.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildReferenceCard(),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFindButton(),
          ),
        ],
        if (_searchCtrl.text.isNotEmpty || _searching)
          Expanded(child: _buildSearchResults()),
        if (showEmpty)
          Expanded(child: _buildEmptyState()),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHowItWorks(),
          const SizedBox(height: 24),
          _buildPopularSearches(),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    final steps = [
      (
        icon: Icons.search_rounded,
        color: kGold,
        title: context.t('Search for a perfume'),
        sub: context.t('Find the expensive perfume you love'),
      ),
      (
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFF9B6DFF),
        title: context.t('AI finds alternatives'),
        sub: context.t('We match by scent, notes, and accords'),
      ),
      (
        icon: Icons.savings_rounded,
        color: kSuccess,
        title: context.t('Save up to 80%'),
        sub: context.t('Same scent, fraction of the price'),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.t('How it works'),
                style: arabicStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder<bool>(
                valueListenable: SubscriptionService.instance.isPro,
                builder: (context, isPro, _) => isPro
                    ? const SizedBox.shrink()
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [kGoldLight, kGold],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Pro ✨',
                          style: arabicStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: kOud,
                          ),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...steps.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: s.color.withValues(alpha: 0.12),
                    ),
                    child: Icon(s.icon, color: s.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: s.color,
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: arabicStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              s.title,
                              style: arabicStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.only(right: 24),
                          child: Text(
                            s.sub,
                            style: arabicStyle(
                              fontSize: 11,
                              color: kWarmGray,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPopularSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('Popular searches'),
          style: arabicStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _popularSearches.map((name) {
            return GestureDetector(
              onTap: () {
                _searchCtrl.text = name;
                _onSearchChanged(name);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: kCardShadow,
                  border: Border.all(
                    color: kGold.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.north_west_rounded,
                      size: 12,
                      color: kGold,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      name,
                      style: arabicStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: kEspresso,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: kCardShadow,
      ),
      child: TextField(
        controller: _searchCtrl,
        textDirection: Directionality.of(context),
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: context.t(
            'Search for a perfume (e.g. Aventus, Baccarat...)',
          ),
          hintStyle: arabicStyle(fontSize: 13, color: kSand),
          prefixIcon: (_searching || _loadingReference)
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kGold,
                    ),
                  ),
                )
              : const Icon(Icons.search_rounded, color: kSand, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: kSand),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchResults = const []);
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        style: arabicStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && !_searching) {
      return Center(
        child: Text(
          context.t('No results. Try another name'),
          style: arabicStyle(fontSize: 13, color: kWarmGray),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, i) {
        final p = _searchResults[i];
        return GestureDetector(
          onTap: () => _selectReference(p),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: kCardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: kGoldPale,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildPerfumeImage(p, 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: arabicStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        p.brand,
                        style: serifStyle(fontSize: 12, italic: true),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14,
                  color: kSand,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReferenceCard() {
    final ref = _reference!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: kCardShadow,
        border: Border.all(color: kGold.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: kGoldPale,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildPerfumeImage(ref, 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref.brand,
                      style: serifStyle(fontSize: 12, italic: true),
                    ),
                    Text(
                      ref.name,
                      style: arabicStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (ref.gender != null && ref.gender!.isNotEmpty)
                      Text(
                        context.t(ref.gender!),
                        style: arabicStyle(fontSize: 11, color: kWarmGray),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _reference = null),
                child: const Icon(Icons.close_rounded, size: 18, color: kSand),
              ),
            ],
          ),
          if (ref.accords.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ref.accords.take(6).map((a) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: kGoldPale,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kGold.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    context.t(a),
                    style: arabicStyle(
                      fontSize: 11,
                      color: kOud,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          if (_referenceEstimatedPrice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 13,
                    color: kGold,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ht(context, 'Estimated price: ~{price} SAR', {
                      'price': _referenceEstimatedPrice,
                    }),
                    style: arabicStyle(
                      fontSize: 12,
                      color: kGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  textDirection: Directionality.of(context),
                  decoration: InputDecoration(
                    hintText: context.t('Original price (SAR)'),
                    hintStyle: arabicStyle(fontSize: 12, color: kSand),
                    suffixText: AppLocalizations.of(context).sar,
                    suffixStyle: arabicStyle(fontSize: 12, color: kWarmGray),
                    filled: true,
                    fillColor: kCream,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: kGold.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: kGold.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kGold),
                    ),
                  ),
                  style: arabicStyle(fontSize: 14),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.t('Optional — used to calculate savings'),
                style: arabicStyle(fontSize: 10, color: kSand),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() => _reference = null);
              _priceCtrl.clear();
            },
            child: Text(
              context.t('Choose a different perfume'),
              style: arabicStyle(
                fontSize: 11,
                color: kGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _findClones,
        icon: const Icon(Icons.saved_search_rounded, size: 18),
        label: Text(
          context.t('Find closest alternatives'),
          style: arabicStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kOud,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: kGold,
          foregroundColor: kOud,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 6,
        ),
      ),
    );
  }

  Widget _buildDupesView() {
    final ref = _reference!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kGoldPale,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildPerfumeImage(ref, 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ht(context, 'Alternatives: {name}', {'name': ref.name}),
                      style: arabicStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(
                          ref.brand,
                          style: serifStyle(fontSize: 11, italic: true),
                        ),
                        if (_referenceEstimatedPrice != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '~$_referenceEstimatedPrice ${AppLocalizations.of(context).sar}',
                            style: arabicStyle(
                              fontSize: 11,
                              color: kGold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingDupes
              ? const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: kGold,
                    ),
                  ),
                )
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: arabicStyle(fontSize: 13, color: kWarmGray),
                    ),
                  ),
                )
              : _dupes.isEmpty
              ? Center(
                  child: Text(
                    context.t(
                      'We could not find enough alternatives for this perfume.',
                    ),
                    style: arabicStyle(fontSize: 13, color: kWarmGray),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: _dupes.length,
                  itemBuilder: (context, i) => _buildDupeCard(_dupes[i], i),
                ),
        ),
      ],
    );
  }

  Widget _buildDupeCard(_DupeResult result, int rank) {
    final p = result.perfume;
    final pct = result.similarity;
    final color = _similarityColor(pct);

    return GestureDetector(
      onTap: widget.onPerfumeTap == null ? null : () => widget.onPerfumeTap!(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: kCardShadow,
          border: Border(right: BorderSide(color: p.accent, width: 3)),
        ),
        child: Row(
          children: [
            // Similarity badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${pct.round()}%',
                    style: arabicStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.brand, style: serifStyle(fontSize: 11, italic: true)),
                  Text(
                    p.name,
                    style: arabicStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (result.aiReason.isNotEmpty)
                    Text(
                      result.aiReason,
                      style: arabicStyle(
                        fontSize: 11,
                        color: kGold,
                        height: 1.4,
                      ),
                    )
                  else if (p.accords.isNotEmpty)
                    Text(
                      p.accords.take(3).map(context.t).join(' · '),
                      style: arabicStyle(fontSize: 11, color: kWarmGray),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${p.rating.toStringAsFixed(1)} ★',
                  style: arabicStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kGold,
                  ),
                ),
                const SizedBox(height: 4),
                if (result.priceRangeSar != null) ...[
                  Text(
                    '~${result.priceRangeSar} ${AppLocalizations.of(context).sar}',
                    style: arabicStyle(fontSize: 10, color: kWarmGray),
                  ),
                  if (_referencePriceSar != null)
                    _buildSavingsBadge(
                      result.priceRangeSar!,
                      _referencePriceSar!,
                    ),
                ] else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kGoldLight, kGold],
                      ),
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

  Widget _buildSavingsBadge(String priceRange, int refPrice) {
    // Parse midpoint from "150-300" or "200"
    final parts = priceRange.split('-');
    final low = int.tryParse(parts.first.trim()) ?? 0;
    final high = parts.length > 1
        ? (int.tryParse(parts.last.trim()) ?? low)
        : low;
    final mid = ((low + high) / 2).round();
    if (mid <= 0 || refPrice <= mid) return const SizedBox.shrink();
    final savings = ((refPrice - mid) / refPrice * 100).round();
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: kSuccess.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kSuccess.withValues(alpha: 0.4)),
      ),
      child: Text(
        ht(context, 'Save ~{savings}%', {'savings': savings}),
        style: arabicStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: kSuccess,
        ),
      ),
    );
  }

  Color _similarityColor(double pct) {
    if (pct >= 70) return kSuccess;
    if (pct >= 50) return kGold;
    if (pct >= 30) return kAmber;
    return kWarmGray;
  }

  Widget _buildPerfumeImage(Perfume p, double fallbackSize) {
    final imageUrl = p.imageUrl ?? p.fallbackImageUrl;
    if (imageUrl == null) {
      return Center(
        child: BottleIcon(color: p.accent, size: fallbackSize),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: PerfumeImage(
        primaryUrl: imageUrl,
        fallbackUrl: p.fallbackImageUrl,
        fallbackColor: p.accent,
        fit: BoxFit.cover,
        iconSize: fallbackSize,
      ),
    );
  }
}

class _DupeResult {
  final Perfume perfume;
  final double similarity;
  final String aiReason;
  final String? priceRangeSar;
  const _DupeResult({
    required this.perfume,
    required this.similarity,
    this.aiReason = '',
    this.priceRangeSar,
  });
}
