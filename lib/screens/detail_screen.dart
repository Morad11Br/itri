import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../l10n/hardcoded_localizations.dart';
import '../services/subscription_service.dart';
import '../services/free_usage_service.dart';
import '../theme.dart';
import '../models/perfume.dart';
import '../widgets/bottle_icon.dart';
import '../widgets/perfume_image.dart';
import '../widgets/star_rating.dart';
import '../data/user_collection_repository.dart' show UserReview;

class DetailScreen extends StatefulWidget {
  final Perfume perfume;
  final String? collectionStatus;
  final bool isFavorite;
  final UserReview? initialReview;
  final Future<void> Function(String status)? onCollectionStatusChanged;
  final Future<void> Function(bool isFavorite)? onFavoriteChanged;
  final Future<void> Function(int rating, String? body)? onSaveReview;
  final Future<List<UserReview>> Function()? onLoadPerfumeReviews;
  final VoidCallback? onRequireUpgrade;
  final VoidCallback? onFindAlternatives;
  final VoidCallback onBack;
  const DetailScreen({
    super.key,
    required this.perfume,
    this.collectionStatus,
    this.isFavorite = false,
    this.initialReview,
    this.onCollectionStatusChanged,
    this.onFavoriteChanged,
    this.onSaveReview,
    this.onLoadPerfumeReviews,
    this.onRequireUpgrade,
    this.onFindAlternatives,
    required this.onBack,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late String? _collectionStatus = widget.collectionStatus;
  bool _savingStatus = false;
  String? _statusError;
  late int _userRating = widget.initialReview?.rating ?? 0;
  String? _activeNote;
  late bool _isFavorite = widget.isFavorite;
  bool _savingFavorite = false;

  final _reviewBodyCtrl = TextEditingController();
  bool _savingReview = false;
  bool _reviewSaved = false;
  List<UserReview> _perfumeReviews = const [];
  bool _loadingReviews = false;
  bool _reviewsLoadError = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialReview?.body != null) {
      _reviewBodyCtrl.text = widget.initialReview!.body!;
      _reviewSaved = true;
    }
    _loadPerfumeReviews();
  }

  @override
  void dispose() {
    _reviewBodyCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.perfume.id != widget.perfume.id ||
        oldWidget.collectionStatus != widget.collectionStatus) {
      _collectionStatus = widget.collectionStatus;
      _statusError = null;
    }
    if (oldWidget.perfume.id != widget.perfume.id) {
      _userRating = widget.initialReview?.rating ?? 0;
      _reviewBodyCtrl.text = widget.initialReview?.body ?? '';
      _reviewSaved = widget.initialReview != null;
      _perfumeReviews = const [];
      _loadPerfumeReviews();
    }
  }

  Future<void> _loadPerfumeReviews() async {
    if (widget.onLoadPerfumeReviews == null) return;
    setState(() { _loadingReviews = true; _reviewsLoadError = false; });
    try {
      final reviews = await widget.onLoadPerfumeReviews!();
      if (mounted) setState(() => _perfumeReviews = reviews);
    } catch (e) {
      if (kDebugMode) debugPrint('DetailScreen: failed to load reviews: $e');
      if (mounted) setState(() => _reviewsLoadError = true);
    } finally {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  Future<void> _submitReview() async {
    if (_userRating == 0 || widget.onSaveReview == null) return;
    final isPro = SubscriptionService.instance.isPro.value;
    if (!isPro && !FreeUsageService.instance.consumeReview()) {
      widget.onRequireUpgrade?.call();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _savingReview = true);
    try {
      await widget.onSaveReview!(_userRating, _reviewBodyCtrl.text);
      if (!mounted) return;
      _reviewBodyCtrl.clear();
      setState(() => _reviewSaved = true);
      // Refresh community reviews to include the new one
      _loadPerfumeReviews();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('Could not save review. Try again.'),
              style: arabicStyle(fontSize: 14)),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingReview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.perfume;
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: kCream,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 290,
              pinned: true,
              backgroundColor: kOud,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: Colors.white,
                ),
                onPressed: widget.onBack,
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    _isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _savingFavorite ? Colors.white38 : Colors.white,
                  ),
                  onPressed: _savingFavorite ? null : _toggleFavorite,
                ),
                Builder(
                  builder: (btnCtx) => IconButton(
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    onPressed: () {
                      final p = widget.perfume;
                      final box = btnCtx.findRenderObject() as RenderBox?;
                      final notes = [
                        ...p.topNotes,
                        ...p.heartNotes,
                        ...p.baseNotes,
                      ].take(5).map((n) => n.name).join(', ');
                      final desc = p.description;
                      final descSnippet = desc != null && desc.isNotEmpty
                          ? (desc.length > 120 ? '${desc.substring(0, 120)}…' : desc)
                          : null;
                      final lines = [
                        '${p.name} — ${p.brand}',
                        '${p.rating} ★${p.count != '0' ? ' (${p.count})' : ''}',
                        if (notes.isNotEmpty) '🌸 $notes',
                        if (descSnippet != null) descSnippet,
                      ];
                      Share.share(
                        lines.join('\n'),
                        sharePositionOrigin: box == null
                            ? null
                            : box.localToGlobal(Offset.zero) & box.size,
                      );
                    },
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kOud, p.accent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 54,
                        right: 54,
                        bottom: 26,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      Positioned(bottom: 30, child: _buildHeroImage(p)),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.brand,
                      style: serifStyle(fontSize: 14, italic: true),
                    ),
                    Text(
                      p.name,
                      style: arabicStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    if (p.year != null || p.gender != null)
                      Text(
                        [
                          p.year?.toString(),
                          p.gender == null ? null : context.t(p.gender!),
                        ].whereType<String>().join(' • '),
                        style: arabicStyle(fontSize: 12, color: kSand),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StarRating(rating: p.rating, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '${p.rating} (${p.count} ${context.t('reviews')})',
                          style: arabicStyle(fontSize: 13, color: kWarmGray),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    _buildAlternativesButton(),
                    const SizedBox(height: 16),
                    _buildNotesPyramid(),
                    if (p.description != null) ...[
                      const SizedBox(height: 16),
                      _buildDescriptionCard(p.description!),
                    ],
                    const SizedBox(height: 16),
                    _buildRatingCard(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage(Perfume p) {
    final imageUrl = p.imageUrl ?? p.fallbackImageUrl;
    if (imageUrl == null) {
      return BottleIcon(color: Colors.white, size: 70);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: PerfumeImage(
        primaryUrl: imageUrl,
        fallbackUrl: p.fallbackImageUrl,
        fallbackColor: Colors.white,
        width: 190,
        height: 230,
        fit: BoxFit.contain,
        iconSize: 70,
      ),
    );
  }

  Widget _buildStatusCard() {
    final statuses = [
      {'label': context.t('Owned'), 'id': 'owned'},
      {'label': context.t('Wishlist'), 'id': 'wish'},
      {'label': context.t('Tested'), 'id': 'tested'},
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).status,
            style: arabicStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: statuses.map((s) {
              final active = _collectionStatus == s['id'];
              return Expanded(
                child: GestureDetector(
                  onTap: _savingStatus
                      ? null
                      : () => _setCollectionStatus(s['id']!),
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? kOud : kCream,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active ? kOud : const Color(0xFFE5DDD4),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      s['label']!,
                      textAlign: TextAlign.center,
                      style: arabicStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : kWarmGray,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_savingStatus) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Color(0xFFF0EBE5),
              valueColor: AlwaysStoppedAnimation<Color>(kGold),
            ),
          ],
          if (_statusError != null) ...[
            const SizedBox(height: 8),
            Text(
              _statusError!,
              style: arabicStyle(fontSize: 11, color: Colors.red.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setCollectionStatus(String status) async {
    final previousStatus = _collectionStatus;
    setState(() {
      _collectionStatus = status;
      _savingStatus = true;
      _statusError = null;
    });

    try {
      await widget.onCollectionStatusChanged?.call(status);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _collectionStatus = previousStatus;
        _statusError = context.t('Could not save status. Please try again.');
      });
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final next = !_isFavorite;
    setState(() {
      _isFavorite = next;
      _savingFavorite = true;
    });
    try {
      await widget.onFavoriteChanged?.call(next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFavorite = !next);
    } finally {
      if (mounted) setState(() => _savingFavorite = false);
    }
  }

  void _onDiscoverAlternatives() {
    final isPro = SubscriptionService.instance.isPro.value;
    final hasCredits = FreeUsageService.instance.dupeFinderLeft.value > 0;
    if (!isPro && !hasCredits) {
      widget.onRequireUpgrade?.call();
      return;
    }
    widget.onFindAlternatives?.call();
  }

  Widget _buildAlternativesButton() {
    if (widget.onFindAlternatives == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _onDiscoverAlternatives,
        icon: const Icon(Icons.saved_search_rounded, size: 18),
        label: Text(
          context.t('Discover Alternatives'),
          style: arabicStyle(
            fontSize: 15,
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

  Widget _buildNotesPyramid() {
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
          Text(
            AppLocalizations.of(context).notesPyramid,
            style: arabicStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          _buildNoteTier(
            context.t('Top notes'),
            Icons.keyboard_arrow_up_rounded,
            widget.perfume.topNotes,
          ),
          _buildNoteTier(
            context.t('Heart notes'),
            Icons.favorite_rounded,
            widget.perfume.heartNotes,
          ),
          _buildNoteTier(
            context.t('Base notes'),
            Icons.keyboard_arrow_down_rounded,
            widget.perfume.baseNotes,
          ),
        ],
      ),
    );
  }

  Widget _buildNoteTier(
    String label,
    IconData icon,
    List<FragranceNote> notes,
  ) {
    if (notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: kSand),
              const SizedBox(width: 4),
              Text(label, style: arabicStyle(fontSize: 11, color: kSand)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: notes.map((note) {
              final active = _activeNote == note.name;
              final color = note.color;
              return GestureDetector(
                onTap: () =>
                    setState(() => _activeNote = active ? null : note.name),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: active ? color.withValues(alpha: 0.2) : kCream,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: color.withValues(alpha: 0.44),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.t(note.name),
                        style: arabicStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (_activeNote != null && notes.any((n) => n.name == _activeNote))
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kGoldPale,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ht(
                  context,
                  '{note} — a distinctive fragrance note that adds depth and richness to the perfume',
                  {'note': context.t(_activeNote!)},
                ),
                style: arabicStyle(fontSize: 12, color: kWarmGray),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(String description) {
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
          Text(
            AppLocalizations.of(context).aboutPerfume,
            style: arabicStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: arabicStyle(fontSize: 12, color: kWarmGray, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard() {
    // Compute community average from loaded reviews
    final allRatings = _perfumeReviews.where((r) => r.rating > 0).toList();
    final avgRating = allRatings.isEmpty
        ? null
        : allRatings.map((r) => r.rating).reduce((a, b) => a + b) /
            allRatings.length;

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
          // Header: title + community average
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).rating,
                style: arabicStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              if (_loadingReviews)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kGold),
                )
              else if (avgRating != null)
                Row(
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: arabicStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kGold,
                      ),
                    ),
                    const Icon(Icons.star_rounded, size: 14, color: kGold),
                    const SizedBox(width: 4),
                    Text(
                      '(${allRatings.length})',
                      style: arabicStyle(fontSize: 12, color: kSand),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),

          // User's own rating
          Row(
            children: [
              Text(
                context.t('Your rating'),
                style: arabicStyle(fontSize: 12, color: kWarmGray),
              ),
              if (widget.onSaveReview != null &&
                  !SubscriptionService.instance.isPro.value) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: widget.onRequireUpgrade,
                  child: Container(
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
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(
              5,
              (i) => GestureDetector(
                onTap: widget.onSaveReview == null
                    ? null
                    : () {
                        final isPro = SubscriptionService.instance.isPro.value;
                        final hasFree = FreeUsageService.instance.reviewLeft.value > 0;
                        if (!isPro && !hasFree) {
                          widget.onRequireUpgrade?.call();
                          return;
                        }
                        setState(() {
                          _userRating = i + 1;
                          _reviewSaved = false;
                        });
                      },
                child: Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Icon(
                    i < _userRating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 32,
                    color: i < _userRating ? kGold : const Color(0xFFE5DDD4),
                  ),
                ),
              ),
            ),
          ),

          // Review text field + submit (only when onSaveReview is wired)
          if (widget.onSaveReview != null && _userRating > 0) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _reviewBodyCtrl,
              maxLines: 3,
              onChanged: (_) => setState(() => _reviewSaved = false),
              decoration: InputDecoration(
                hintText: context.t('Write your review (optional)...'),
                hintStyle: arabicStyle(fontSize: 13, color: kSand),
                filled: true,
                fillColor: kCream,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5DDD4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5DDD4)),
                ),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savingReview || _reviewSaved ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: kOud,
                  disabledBackgroundColor: _reviewSaved
                      ? kGold.withValues(alpha: 0.4)
                      : kGold.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                ),
                child: _savingReview
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kOud,
                        ),
                      )
                    : Text(
                        _reviewSaved
                            ? context.t('Review saved ✓')
                            : context.t('Submit review'),
                        style: arabicStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kOud,
                        ),
                      ),
              ),
            ),
          ],

          // Reviews load error
          if (_reviewsLoadError) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _loadPerfumeReviews,
              child: Row(
                children: [
                  Icon(Icons.refresh_rounded, size: 14, color: kSand),
                  const SizedBox(width: 4),
                  Text(
                    context.t('Could not load reviews. Tap to retry.'),
                    style: arabicStyle(fontSize: 12, color: kSand),
                  ),
                ],
              ),
            ),
          ],

          // Community reviews
          if (_perfumeReviews.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF0EBE5)),
            const SizedBox(height: 8),
            Text(
              context.t('Community reviews'),
              style: arabicStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ..._perfumeReviews.take(5).map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                i < r.rating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 13,
                                color: i < r.rating
                                    ? kGold
                                    : const Color(0xFFE5DDD4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            r.displayName ?? context.t('User'),
                            style: arabicStyle(fontSize: 11, color: kWarmGray),
                          ),
                        ],
                      ),
                      if (r.body != null && r.body!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            r.body!,
                            style: arabicStyle(
                              fontSize: 12,
                              color: kEspresso,
                              height: 1.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
