import 'dart:async';

import 'package:flutter/material.dart';
import '../data/user_collection_repository.dart';
import '../l10n/app_localizations.dart';
import '../l10n/hardcoded_localizations.dart';
import '../services/free_usage_service.dart';
import '../services/subscription_service.dart';
import '../models/perfume.dart';
import '../theme.dart';
import '../widgets/bottle_icon.dart';
import '../widgets/perfume_image.dart';
import '../widgets/star_rating.dart';

class CollectionScreen extends StatefulWidget {
  final List<Perfume> perfumes;
  final FutureOr<void> Function(Perfume) onPerfumeTap;
  final VoidCallback onAddTap;
  final Future<List<Perfume>> Function(int offset, int limit)? onLoadMore;
  final bool requiresAuth;
  // Returns perfume_id → status for the signed-in user.
  final Future<Map<String, String>> Function()? loadCollection;
  final Future<CollectionStats> Function()? loadStats;
  final Future<void> Function(Perfume)? onDeleteFromCollection;
  final Future<List<Perfume>> Function(List<String> ids)? lookupPerfumesByIds;
  final int collectionVersion;
  final VoidCallback? onRequireUpgrade;
  const CollectionScreen({
    super.key,
    required this.perfumes,
    required this.onPerfumeTap,
    required this.onAddTap,
    this.onLoadMore,
    this.requiresAuth = false,
    this.collectionVersion = 0,
    this.loadCollection,
    this.loadStats,
    this.onDeleteFromCollection,
    this.lookupPerfumesByIds,
    this.onRequireUpgrade,
  });

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  static const _pageSize = 30;

  final _scrollController = ScrollController();
  // Filter value: '' = all, otherwise 'owned' | 'wish' | 'tested'
  String _filter = '';
  bool _gridView = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _loadingCollection = false;
  bool _pendingCollectionReload = false;
  late int _nextOffset = widget.perfumes.length;
  late List<Perfume> _perfumes = widget.perfumes;
  Map<String, String>?
  _collectionStatuses; // perfume_id → status; null = not loaded yet
  CollectionStats? _liveStats;
  String? _collectionError;
  final Set<String> _deletingIds = {};

  List<Perfume> _dedupById(List<Perfume> list) {
    final seen = <String>{};
    return list.where((p) => seen.add(p.id)).toList();
  }

  // 'For sale' removed: schema constraint is status IN ('owned','wish','tested')
  List<String> get _filterLabels {
    final l10n = AppLocalizations.of(context);
    return [l10n.all, l10n.owned, l10n.wish, l10n.tested];
  }

  static const _filterValues = ['', 'owned', 'wish', 'tested'];

  int get _collectionCount {
    final stats = _liveStats;
    final statuses = _collectionStatuses;
    return stats?.count ?? statuses?.length ?? 0;
  }

  List<Perfume> get _filteredPerfumes {
    final statuses = _collectionStatuses;
    if (statuses == null) {
      if (widget.requiresAuth) return [];
      // Guest/offline: show all as catalog browse.
      // Logged-in: don't show all perfumes while loading or on error.
      return widget.loadCollection == null ? _perfumes : [];
    }
    if (_filter.isEmpty) {
      return _perfumes
          .where((p) => p.id.isNotEmpty && statuses.containsKey(p.id))
          .toList();
    }
    return _perfumes
        .where((p) => p.id.isNotEmpty && statuses[p.id] == _filter)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadCollection());
  }

  Future<void> _loadCollection() async {
    if (widget.loadCollection == null) return;
    if (_loadingCollection) {
      _pendingCollectionReload = true;
      return;
    }
    setState(() {
      _loadingCollection = true;
      _collectionError = null;
    });
    try {
      final results = await Future.wait([
        widget.loadCollection!(),
        if (widget.loadStats != null) widget.loadStats!(),
      ]);
      if (!mounted) return;
      final statuses = results[0] as Map<String, String>;

      // Fetch any collection perfumes (e.g. custom/manual entries) that are
      // not present in the global catalog loaded so far.
      final missingIds = statuses.keys
          .where((id) => !_perfumes.any((p) => p.id == id))
          .toList();
      if (missingIds.isNotEmpty && widget.lookupPerfumesByIds != null) {
        final missing = await widget.lookupPerfumesByIds!(missingIds);
        _perfumes = _dedupById([..._perfumes, ...missing]);
      }

      setState(() {
        _collectionStatuses = statuses;
        if (results.length > 1) _liveStats = results[1] as CollectionStats;
      });
    } catch (e) {
      if (mounted) setState(() => _collectionError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingCollection = false);
        if (_pendingCollectionReload) {
          _pendingCollectionReload = false;
          unawaited(_loadCollection());
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant CollectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.perfumes != widget.perfumes) {
      // Preserve custom perfumes fetched on-demand so they don't vanish
      // when the global catalog updates.
      final custom = _perfumes
          .where((p) => !oldWidget.perfumes.any((op) => op.id == p.id))
          .toList();
      _perfumes = _dedupById([...widget.perfumes, ...custom]);
      _nextOffset = widget.perfumes.length;
      _hasMore = true;
    }
    final collectionBecameAvailable =
        oldWidget.loadCollection == null && widget.loadCollection != null;
    final collectionBecameUnavailable =
        oldWidget.loadCollection != null && widget.loadCollection == null;
    if (collectionBecameUnavailable) {
      setState(() {
        _collectionStatuses = null;
        _liveStats = null;
      });
    } else if (collectionBecameAvailable ||
        oldWidget.collectionVersion != widget.collectionVersion) {
      unawaited(_loadCollection());
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() => unawaited(_maybeLoadMore());

  Future<void> _maybeLoadMore() async {
    if (widget.onLoadMore == null || _loadingMore || !_hasMore) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 500) return;

    setState(() => _loadingMore = true);
    try {
      final page = await widget.onLoadMore!(_nextOffset, _pageSize);
      if (!mounted) return;
      setState(() {
        _nextOffset += page.length;
        _hasMore = page.length == _pageSize;
        _perfumes = [..._perfumes, ...page];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasMore = false);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refreshCollection() async {
    await _loadCollection();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: kCream,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  AppLocalizations.of(context).collection,
                  style: arabicStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              _buildStatsRow(),
              _buildFilterBar(),
              Expanded(
                child: RefreshIndicator(
                  color: kGold,
                  backgroundColor: Colors.white,
                  onRefresh: _refreshCollection,
                  child: _buildCollectionBody(),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: ValueListenableBuilder<bool>(
          valueListenable: SubscriptionService.instance.isPro,
          builder: (_, isPro, __) {
            if (isPro) {
              return FloatingActionButton(
                onPressed: widget.onAddTap,
                backgroundColor: kGold,
                foregroundColor: kOud,
                elevation: 8,
                child: const Icon(Icons.add, size: 28),
              );
            }
            final atLimit = _collectionCount >= FreeUsageService.kFreeCollectionLimit;
            return FloatingActionButton(
              onPressed: atLimit ? widget.onRequireUpgrade : widget.onAddTap,
              backgroundColor: atLimit ? kSand : kGold,
              foregroundColor: kOud,
              elevation: 8,
              child: Icon(
                atLimit ? Icons.lock_rounded : Icons.add,
                size: 28,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCollectionBody() {
    if (_loadingCollection) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 220),
          Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: kGold),
            ),
          ),
        ],
      );
    }
    if (_collectionError != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 180),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 40, color: kSand),
                  const SizedBox(height: 12),
                  Text(
                    context.t('Could not load your collection.'),
                    textAlign: TextAlign.center,
                    style: arabicStyle(fontSize: 14, color: kWarmGray),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _loadCollection(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: kOud,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        context.t('Try Again'),
                        style: arabicStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (_filteredPerfumes.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: 420, child: _buildEmptyState())],
      );
    }
    return _gridView ? _buildGrid() : _buildList();
  }

  Widget _buildStatsRow() {
    final statuses = _collectionStatuses;
    final stats = _liveStats;

    // Count: authoritative from DB when available, fallback to map length.
    final count = _collectionCount;

    // Price: sum of price_paid stored at entry time; show dash until loaded.
    final price = stats?.totalPrice ?? 0.0;
    final priceText = stats == null
        ? '—'
        : price > 0
        ? _formatPrice(price)
        : '—';

    // Unique accords: computed client-side from already-loaded perfume list.
    final uniqueAccords = statuses == null
        ? 0
        : _perfumes
              .where((p) => p.id.isNotEmpty && statuses.containsKey(p.id))
              .expand((p) => p.accords)
              .toSet()
              .length;

    final l10n = AppLocalizations.of(context);
    final tiles = [
      (
        icon: '🧴',
        value: count.toString(),
        sub: null as String?,
        label: l10n.perfumes,
      ),
      (
        icon: '💎',
        value: priceText,
        sub: price > 0 ? l10n.sar : null,
        label: l10n.value,
      ),
      (
        icon: '✨',
        value: uniqueAccords.toString(),
        sub: l10n.sar,
        label: l10n.diversity,
      ),
    ];

    return ValueListenableBuilder<bool>(
      valueListenable: SubscriptionService.instance.isPro,
      builder: (context, isPro, _) {
        return SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            itemCount: tiles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = tiles[i];
              // Value (i==1) and Diversity (i==2) are Pro-only
              final isLocked = !isPro && i > 0;
              return GestureDetector(
                onTap: isLocked ? widget.onRequireUpgrade : null,
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: kCardShadow,
                    border: Border(
                      bottom: BorderSide(
                        color: isLocked
                            ? const Color(0x22C9A227)
                            : const Color(0x33C9A227),
                        width: 2,
                      ),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.icon, style: const TextStyle(fontSize: 17)),
                        const SizedBox(height: 2),
                        if (isLocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
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
                          )
                        else if (i == 0 && !isPro)
                          RichText(
                            text: TextSpan(
                              text: t.value,
                              style: arabicStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                              children: [
                                TextSpan(
                                  text: ' / ${FreeUsageService.kFreeCollectionLimit}',
                                  style: arabicStyle(
                                    fontSize: 10,
                                    color: count >= FreeUsageService.kFreeCollectionLimit
                                        ? Colors.red.shade400
                                        : kWarmGray,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          RichText(
                            text: TextSpan(
                              text: t.value,
                              style: arabicStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                              children: t.sub != null
                                  ? [
                                      TextSpan(
                                        text: ' ${t.sub}',
                                        style: arabicStyle(
                                          fontSize: 10,
                                          color: kWarmGray,
                                        ),
                                      ),
                                    ]
                                  : [],
                            ),
                          ),
                        Text(
                          t.label,
                          style: arabicStyle(fontSize: 11, color: kSand),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000) {
      final parts = price.toStringAsFixed(0).split('');
      final buf = StringBuffer();
      for (var i = 0; i < parts.length; i++) {
        if (i > 0 && (parts.length - i) % 3 == 0) buf.write(',');
        buf.write(parts[i]);
      }
      return buf.toString();
    }
    return price.toStringAsFixed(0);
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                itemCount: _filterLabels.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final f = _filterLabels[i];
                  final v = _filterValues[i];
                  final active = v == _filter;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = v),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: active ? kOud : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: active ? kOud : const Color(0xFFE5DDD4),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        f,
                        style: arabicStyle(
                          fontSize: 12,
                          color: active ? Colors.white : kWarmGray,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Row(
            children: [
              _viewToggle(true, Icons.grid_view_rounded),
              const SizedBox(width: 4),
              _viewToggle(false, Icons.list_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _viewToggle(bool isGrid, IconData icon) {
    final active = _gridView == isGrid;
    return GestureDetector(
      onTap: () => setState(() => _gridView = isGrid),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: active ? kOud : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active ? null : kCardShadow,
        ),
        child: Icon(icon, size: 16, color: active ? Colors.white : kSand),
      ),
    );
  }

  Widget _buildGrid() {
    final items = _filteredPerfumes;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isTablet = width >= 600;
        final crossAxisCount = width >= 760 ? 3 : 2;
        final spacing = isTablet ? 12.0 : 10.0;
        final horizontalPadding = isTablet ? 20.0 : 16.0;
        final cardPadding = isTablet ? 14.0 : 12.0;
        final childAspectRatio = isTablet ? 0.95 : 0.72;
        final photoHeight = isTablet ? 132.0 : 108.0;
        final imageFallbackSize = isTablet ? 64.0 : 58.0;

        return GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            4,
            horizontalPadding,
            100,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: items.length + (_loadingMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= items.length) return _buildLoadingTile();
            final p = items[i];
            final isDeleting = _deletingIds.contains(p.id);
            return GestureDetector(
              onTap: () => widget.onPerfumeTap(p),
              onLongPress: widget.onDeleteFromCollection == null
                  ? null
                  : () => _confirmDelete(p),
              child: Container(
                padding: EdgeInsets.all(cardPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: kCardShadow,
                ),
                child: Column(
                  mainAxisAlignment: isTablet
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    _buildGridPhotoStage(
                      p,
                      height: photoHeight,
                      fallbackSize: imageFallbackSize,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: serifStyle(fontSize: 10, italic: true),
                    ),
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: arabicStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    StarRating(rating: p.rating, size: 10),
                    if (isDeleting)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kGold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildList() {
    final items = _filteredPerfumes;
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: items.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (i >= items.length) return _buildLoadingRow();
        final p = items[i];
        final canDelete = widget.onDeleteFromCollection != null;
        Widget tile = GestureDetector(
          onTap: () => widget.onPerfumeTap(p),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: kCardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [kGoldPale, Colors.white],
                    ),
                  ),
                  child: _buildPerfumeImage(p, 34),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.brand,
                        style: serifStyle(fontSize: 11, italic: true),
                      ),
                      Text(
                        p.name,
                        style: arabicStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      StarRating(rating: p.rating, size: 11),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left_rounded, color: kSand),
              ],
            ),
          ),
        );
        if (canDelete) {
          tile = Dismissible(
            key: ValueKey('collection_${p.id}'),
            direction: DismissDirection.startToEnd,
            onDismissed: (_) => _deleteItem(p),
            background: Container(
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            child: tile,
          );
        }
        return tile;
      },
    );
  }

  Widget _buildLoadingTile() {
    return const Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: kGold),
      ),
    );
  }

  Widget _buildLoadingRow() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: kGold),
        ),
      ),
    );
  }

  Future<void> _deleteItem(Perfume p) async {
    if (widget.onDeleteFromCollection == null || p.id.isEmpty) return;
    final previousStatus = _collectionStatuses?.remove(p.id);
    setState(() => _deletingIds.add(p.id));
    try {
      await widget.onDeleteFromCollection!(p);
    } catch (e) {
      if (!mounted) return;
      // Restore locally on failure so the item reappears.
      if (previousStatus != null) {
        _collectionStatuses?[p.id] = previousStatus;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ht(context, 'Delete failed: {error}', {'error': e}),
            style: arabicStyle(fontSize: 13, color: Colors.white),
          ),
          backgroundColor: Colors.red.shade400,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingIds.remove(p.id));
    }
  }

  void _confirmDelete(Perfume p) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: Directionality.of(context),
        child: AlertDialog(
          backgroundColor: kCream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            context.t('Remove from collection'),
            style: arabicStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          content: Text(
            ht(
              context,
              'Do you want to remove "{name}" from your collection?',
              {'name': p.name},
            ),
            style: arabicStyle(fontSize: 14, color: kWarmGray),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                context.t('Cancel'),
                style: arabicStyle(fontSize: 13, color: kSand),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                unawaited(_deleteItem(p));
              },
              child: Text(
                context.t('Delete'),
                style: arabicStyle(
                  fontSize: 13,
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kGoldPale,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 36,
                color: kGold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.emptyCollection,
              style: arabicStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kEspresso,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.requiresAuth ? l10n.loginToSave : l10n.emptyCollectionDesc,
              textAlign: TextAlign.center,
              style: arabicStyle(fontSize: 14, color: kWarmGray),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onAddTap,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                l10n.addPerfume,
                style: arabicStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGold,
                foregroundColor: kOud,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridPhotoStage(
    Perfume p, {
    double height = 108,
    double fallbackSize = 58,
  }) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFCF5), kGoldPale],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: Color(0xFFF0E5D1)),
      ),
      child: _buildPerfumeImage(p, fallbackSize),
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
      padding: const EdgeInsets.all(6),
      child: PerfumeImage(
        primaryUrl: imageUrl,
        fallbackUrl: p.fallbackImageUrl,
        fallbackColor: p.accent,
        fit: BoxFit.contain,
        iconSize: fallbackSize,
      ),
    );
  }
}
