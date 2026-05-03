import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import '../l10n/app_localizations.dart';
import '../l10n/hardcoded_localizations.dart';
import '../models/deal.dart';
import '../models/perfume.dart';
import '../theme.dart';
import '../widgets/bottle_icon.dart';
import '../widgets/perfume_image.dart';
import '../widgets/star_rating.dart';
import 'settings/notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<Perfume> perfumes;
  final FutureOr<void> Function(Perfume) onPerfumeTap;
  final String? displayName;
  final Future<List<Perfume>> Function({
    String? accord,
    required int offset,
    required int limit,
  })?
  onLoadPage;
  final Future<void> Function(Perfume)? onAddToCollection;
  final Future<Map<String, String>> Function()? onLoadCollectionStatuses;
  final int collectionVersion;
  final Future<List<Deal>> Function()? loadDeals;
  final Future<Set<String>> Function()? onLoadFavorites;
  final Future<void> Function(Perfume, bool isFavorite)? onToggleFavorite;
  final VoidCallback? onRequireAuth;
  final VoidCallback onSearchTap;
  const HomeScreen({
    super.key,
    required this.perfumes,
    required this.onPerfumeTap,
    this.displayName,
    this.onLoadPage,
    this.onAddToCollection,
    this.onLoadCollectionStatuses,
    this.collectionVersion = 0,
    this.loadDeals,
    this.onLoadFavorites,
    this.onToggleFavorite,
    this.onRequireAuth,
    required this.onSearchTap,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String get _initials {
    final name = widget.displayName?.trim() ?? '';
    if (name.isEmpty) return 'U';
    final words = name.split(RegExp(r'\s+'));
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}';
    return name.length >= 2 ? name.substring(0, 2) : name[0];
  }

  String _timeGreeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return l10n.goodMorning;
    if (hour >= 12 && hour < 17) return l10n.goodAfternoon;
    if (hour >= 17 && hour < 22) return l10n.goodEvening;
    return l10n.goodNight;
  }

  String _activeCategory = 'All';
  late List<Perfume> _categoryPerfumes = widget.perfumes;
  late int _nextOffset = widget.perfumes.length;
  bool _loadingCategory = false;
  int _categoryRequestVersion = 0;
  final Set<String> _addingIds = {};
  final Set<String> _addedIds = {};
  final Set<String> _favoritedIds = {};
  final Set<String> _favoritingIds = {};

  static const _pageSize = 10;
  bool _hasMore = true;
  bool _loadingMore = false;
  final _scrollController = ScrollController();

  final _categories = [
    'All',
    'Oud',
    'Musk',
    'Citrus',
    'Floral',
    'Woody',
    'Oriental',
    'Western',
    'Niche',
  ];

  List<Deal> _deals = const [];
  bool _loadingDeals = false;

  static const _categoryAccords = {
    'All': null,
    'Oud': 'oud',
    'Musk': 'musky',
    'Citrus': 'citrus',
    'Floral': 'floral',
    'Woody': 'woody',
    'Oriental': 'oriental',
    'Western': 'fresh',
    'Niche': 'aromatic',
  };

  static const _hijriMonths = [
    'Muharram',
    'Safar',
    'Rabi Al-Awwal',
    'Rabi Al-Thani',
    'Jumada Al-Awwal',
    'Jumada Al-Thani',
    'Rajab',
    'Shaaban',
    'Ramadan',
    'Shawwal',
    'Dhu Al-Qadah',
    'Dhu Al-Hijjah',
  ];
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _hasMore = widget.perfumes.length >= _pageSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_selectCategory(_activeCategory));
    });
    unawaited(_fetchDeals());
    unawaited(_loadFavorites());
    unawaited(_loadCollectionStatuses());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadFavorites() async {
    if (widget.onLoadFavorites == null) return;
    try {
      final ids = await widget.onLoadFavorites!();
      if (mounted) setState(() => _favoritedIds.addAll(ids));
    } catch (_) {}
  }

  Future<void> _loadCollectionStatuses() async {
    if (widget.onLoadCollectionStatuses == null) return;
    try {
      final statuses = await widget.onLoadCollectionStatuses!();
      if (mounted) {
        setState(() {
          _addedIds
            ..clear()
            ..addAll(statuses.keys);
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite(Perfume p) async {
    if (widget.onToggleFavorite == null) {
      widget.onRequireAuth?.call();
      return;
    }
    final id = p.id.isNotEmpty ? p.id : p.name;
    if (_favoritingIds.contains(id)) return;
    final next = !_favoritedIds.contains(id);
    setState(() {
      if (next) {
        _favoritedIds.add(id);
      } else {
        _favoritedIds.remove(id);
      }
      _favoritingIds.add(id);
    });
    try {
      await widget.onToggleFavorite!(p, next);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (next) {
          _favoritedIds.remove(id);
        } else {
          _favoritedIds.add(id);
        }
      });
    } finally {
      if (mounted) setState(() => _favoritingIds.remove(id));
    }
  }

  Future<void> _fetchDeals() async {
    if (widget.loadDeals == null) return;
    setState(() => _loadingDeals = true);
    try {
      final deals = await widget.loadDeals!();
      if (!mounted) return;
      setState(() => _deals = deals);
    } catch (_) {
      // leave _deals empty — section hidden
    } finally {
      if (mounted) setState(() => _loadingDeals = false);
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.perfumes != widget.perfumes) {
      if (_activeCategory == 'All') {
        _categoryPerfumes = widget.perfumes;
        _nextOffset = widget.perfumes.length;
        _hasMore = widget.perfumes.length >= _pageSize;
      } else {
        _categoryPerfumes = _filterLocalCategory(
          widget.perfumes,
          _activeCategory,
        );
        _nextOffset = _categoryPerfumes.length;
      }
    }
    if (oldWidget.onLoadCollectionStatuses != widget.onLoadCollectionStatuses ||
        oldWidget.collectionVersion != widget.collectionVersion) {
      unawaited(_loadCollectionStatuses());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Container(
        color: kCream,
        child: SafeArea(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildTopBar()),
              SliverToBoxAdapter(child: _buildHijriDate()),
              SliverToBoxAdapter(child: _buildFeaturedBanner()),
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  AppLocalizations.of(context).categories,
                  '',
                ),
              ),
              SliverToBoxAdapter(child: _buildCategories()),
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  AppLocalizations.of(context).trending,
                  '',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: _loadingCategory
                    ? const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: kGold,
                              ),
                            ),
                          ),
                        ),
                      )
                    : SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _buildPerfumeCard(_categoryPerfumes[i]),
                          childCount: _categoryPerfumes.length,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.66,
                            ),
                      ),
              ),
              if (_loadingMore) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kGold,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else if (_hasMore &&
                  widget.onLoadPage != null &&
                  !_loadingCategory &&
                  _categoryPerfumes.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: OutlinedButton(
                      onPressed: _loadMore,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kGold),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        AppLocalizations.of(context).loadMore,
                        style: arabicStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kGold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (_loadingDeals || _deals.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    AppLocalizations.of(context).deals,
                    '',
                  ),
                ),
                SliverToBoxAdapter(child: _buildDeals()),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [kGold, kGoldLight]),
            ),
            child: Center(
              child: Text(
                _initials,
                style: arabicStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kOud,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _timeGreeting(l10n),
                style: arabicStyle(fontSize: 13, color: kWarmGray),
              ),
              Text(
                widget.displayName ?? l10n.user,
                style: arabicStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Spacer(),
          _iconButton(Icons.notifications_outlined, onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          }),
          const SizedBox(width: 8),
          _iconButton(Icons.search_rounded, onTap: widget.onSearchTap),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: kCardShadow,
        ),
        child: Icon(icon, size: 18, color: kEspresso),
      ),
    );
  }

  Widget _buildHijriDate() {
    final h = HijriCalendar.now();
    final month = context.t(_hijriMonths[h.hMonth - 1]);
    final weekday = context.t(_weekdays[DateTime.now().weekday - 1]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        '${h.hDay} $month ${h.hYear} • $weekday',
        style: arabicStyle(fontSize: 12, color: kSand),
      ),
    );
  }

  Perfume? get _perfumeOfTheDay {
    final perfumes = widget.perfumes;
    if (perfumes.isEmpty) return null;
    final h = HijriCalendar.now();
    final hash = h.hYear * 10000 + h.hMonth * 100 + h.hDay;
    return perfumes[hash % perfumes.length];
  }

  Widget _buildFeaturedBanner() {
    final potd = _perfumeOfTheDay;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 175,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kOud, Color(0xFF6B3A1F), Color(0xFF9B5A2F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: GestureDetector(
            onTap: potd == null ? null : () => widget.onPerfumeTap(potd),
            child: Stack(
              children: [
                Positioned(
                  top: 12,
                  left: 20,
                  child: Opacity(
                    opacity: 0.12,
                    child: BottleIcon(color: kGoldLight, size: 50),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 130, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        context.t('Perfume of the Day'),
                        style: arabicStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kGold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (potd != null) ...[
                        Text(
                          potd.brand,
                          style: serifStyle(
                            fontSize: 13,
                            italic: true,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          potd.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: arabicStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildBannerActions(potd),
                      ] else
                        Text(
                          context.t('Discover the world of oud and musk'),
                          style: arabicStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.25,
                          ),
                        ),
                    ],
                  ),
                ),
                if (potd?.imageUrl != null)
                  Positioned.fill(
                    right: 20,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: PerfumeImage(
                          primaryUrl: potd!.imageUrl!,
                          width: 90,
                          height: 120,
                          fit: BoxFit.contain,
                          showIconOnError: false,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerActions(Perfume p) {
    final id = p.id.isNotEmpty ? p.id : p.name;
    final isFav = _favoritedIds.contains(id);
    final isFaving = _favoritingIds.contains(id);
    final isAdded = _addedIds.contains(id);
    final isAdding = _addingIds.contains(id);
    final canAdd = widget.onAddToCollection != null || widget.onRequireAuth != null;

    return Row(
      children: [
        // Heart
        GestureDetector(
          onTap: isFaving
              ? null
              : () async {
                  if (widget.onToggleFavorite == null) {
                    widget.onRequireAuth?.call();
                    return;
                  }
                  await _toggleFavorite(p);
                },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFaving ? Colors.white38 : Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Add to collection
        GestureDetector(
          onTap: !canAdd || isAdding || isAdded
              ? null
              : () async {
                  if (widget.onAddToCollection == null) {
                    widget.onRequireAuth?.call();
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _addingIds.add(id));
                  try {
                    await widget.onAddToCollection!(p);
                    if (mounted) {
                      setState(() => _addedIds.add(id));
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            ht(context, 'Added {name} to your collection', {'name': p.name}),
                            style: arabicStyle(fontSize: 13, color: Colors.white),
                          ),
                          backgroundColor: kOud,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Add failed: $e',
                            style: arabicStyle(fontSize: 13, color: Colors.white),
                          ),
                          backgroundColor: Colors.red.shade400,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _addingIds.remove(id));
                  }
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isAdded
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: isAdding
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAdded ? Icons.check_rounded : Icons.add_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isAdded ? context.t('Added') : context.t('Add'),
                        style: arabicStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String action) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: arabicStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(action, style: arabicStyle(fontSize: 13, color: kGold)),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final active = cat == _activeCategory;
          return GestureDetector(
            onTap: () => _selectCategory(cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? kOud : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? kOud : const Color(0xFFE5DDD4),
                  width: 1.5,
                ),
                boxShadow: active ? null : kCardShadow,
              ),
              child: Text(
                context.t(cat),
                style: arabicStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? Colors.white : kWarmGray,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectCategory(String category) async {
    if (category == _activeCategory && _categoryPerfumes.isNotEmpty) return;

    final accord = _categoryAccords[category];
    final version = ++_categoryRequestVersion;

    setState(() {
      _activeCategory = category;
      _loadingCategory = widget.onLoadPage != null && category != 'All';
      _loadingMore = false;
    });

    if (category == 'All') {
      setState(() {
        _categoryPerfumes = widget.perfumes;
        _nextOffset = widget.perfumes.length;
        _hasMore = widget.perfumes.length >= _pageSize;
        _loadingCategory = false;
      });
      return;
    }

    // Offline fallback
    if (widget.onLoadPage == null) {
      setState(() {
        _categoryPerfumes = _filterLocalCategory(widget.perfumes, category);
        _nextOffset = _categoryPerfumes.length;
        _hasMore = false;
        _loadingCategory = false;
      });
      return;
    }

    try {
      final perfumes = await widget.onLoadPage!(
        accord: accord,
        offset: 0,
        limit: _pageSize,
      );
      if (!mounted || version != _categoryRequestVersion) return;
      setState(() {
        _categoryPerfumes = _dedupPerfumes(perfumes);
        _nextOffset = perfumes.length;
        _hasMore = perfumes.length == _pageSize;
        _loadingCategory = false;
      });
    } catch (_) {
      if (!mounted || version != _categoryRequestVersion) return;
      setState(() {
        _categoryPerfumes = _filterLocalCategory(widget.perfumes, category);
        _nextOffset = _categoryPerfumes.length;
        _hasMore = false;
        _loadingCategory = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || widget.onLoadPage == null) return;

    final accord = _categoryAccords[_activeCategory];
    setState(() => _loadingMore = true);

    try {
      final perfumes = await widget.onLoadPage!(
        accord: accord,
        offset: _nextOffset,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _nextOffset += perfumes.length;
        _categoryPerfumes = _dedupPerfumes([..._categoryPerfumes, ...perfumes]);
        _hasMore = perfumes.length == _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String _perfumeKey(Perfume perfume) =>
      perfume.id.isNotEmpty ? perfume.id : '${perfume.brand}:${perfume.name}';

  List<Perfume> _dedupPerfumes(List<Perfume> perfumes) {
    final seen = <String>{};
    return perfumes
        .where((perfume) => seen.add(_perfumeKey(perfume)))
        .toList(growable: false);
  }

  List<Perfume> _filterLocalCategory(List<Perfume> perfumes, String category) {
    final accord = _categoryAccords[category];
    if (accord == null) return perfumes;

    final matches = perfumes
        .where((perfume) => perfume.accords.any((item) => item == accord))
        .toList();

    return matches.isEmpty ? perfumes : matches;
  }

  Widget _buildPerfumeCard(Perfume p) {
    return GestureDetector(
      onTap: () => widget.onPerfumeTap(p),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: kCardShadow,
        ),
        child: Column(
          children: [
            Expanded(child: _buildPhotoStage(p)),
            const SizedBox(height: 8),
            Text(
              p.brand,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: serifStyle(fontSize: 11, italic: true),
            ),
            const SizedBox(height: 2),
            Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: arabicStyle(fontSize: 14, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StarRating(rating: p.rating, size: 11),
                const SizedBox(width: 4),
                Text(p.count, style: arabicStyle(fontSize: 11, color: kSand)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final id = p.id.isNotEmpty ? p.id : p.name;
                      final isAdding = _addingIds.contains(id);
                      final isAdded = _addedIds.contains(id);
                      final canAdd =
                          widget.onAddToCollection != null ||
                          widget.onRequireAuth != null;
                      return GestureDetector(
                        onTap: !canAdd || isAdding || isAdded
                            ? null
                            : () async {
                                if (widget.onAddToCollection == null) {
                                  widget.onRequireAuth?.call();
                                  return;
                                }
                                final messenger = ScaffoldMessenger.of(context);
                                final isArabic =
                                    Localizations.localeOf(
                                      context,
                                    ).languageCode ==
                                    'ar';
                                final addedMessage = ht(
                                  context,
                                  'Added {name} to your collection',
                                  {'name': p.name},
                                );
                                setState(() => _addingIds.add(id));
                                try {
                                  await widget.onAddToCollection!(p);
                                  if (mounted) {
                                    setState(() => _addedIds.add(id));
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          addedMessage,
                                          style: arabicStyle(
                                            fontSize: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                        backgroundColor: kOud,
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    final errorMessage = isArabic
                                        ? 'فشل الإضافة: $e'
                                        : 'Add failed: $e';
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          errorMessage,
                                          style: arabicStyle(
                                            fontSize: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                        backgroundColor: Colors.red.shade400,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _addingIds.remove(id));
                                  }
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isAdded
                                ? kGold.withValues(alpha: 0.16)
                                : kGoldPale,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: kGold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: isAdding
                              ? const SizedBox(
                                  height: 14,
                                  child: Center(
                                    child: SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: kGold,
                                      ),
                                    ),
                                  ),
                                )
                              : Text(
                                  isAdded
                                      ? '✓'
                                      : AppLocalizations.of(context).add,
                                  textAlign: TextAlign.center,
                                  style: arabicStyle(
                                    fontSize: isAdded ? 13 : 11,
                                    color: kGold,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _toggleFavorite(p),
                  child: Container(
                    width: 30,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5DDD4)),
                    ),
                    child: Builder(
                      builder: (_) {
                        final id = p.id.isNotEmpty ? p.id : p.name;
                        final isFav = _favoritedIds.contains(id);
                        final saving = _favoritingIds.contains(id);
                        if (saving) {
                          return const SizedBox(
                            height: 14,
                            child: Center(
                              child: SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: kOud,
                                ),
                              ),
                            ),
                          );
                        }
                        return Text(
                          isFav ? '♥' : '♡',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isFav ? kOud : null,
                          ),
                        );
                      },
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

  Widget _buildPhotoStage(Perfume p) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFCF5), kGoldPale],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: Color(0xFFF0E5D1)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: p.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          _buildPerfumeImage(p, 62),
        ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: PerfumeImage(
        primaryUrl: imageUrl,
        fallbackUrl: p.fallbackImageUrl,
        fallbackColor: p.accent,
        fit: BoxFit.contain,
        iconSize: fallbackSize,
      ),
    );
  }

  Widget _buildDeals() {
    if (_loadingDeals) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: kGold),
          ),
        ),
      );
    }
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: _deals.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final d = _deals[i];
          return Container(
            width: 170,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: kCardShadow,
              border: Border(right: BorderSide(color: d.color, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(d.store, style: arabicStyle(fontSize: 11, color: kSand)),
                Text(
                  d.description,
                  style: arabicStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
