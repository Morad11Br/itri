import 'package:flutter/material.dart';
import '../data/community_repository.dart';
import '../l10n/app_localizations.dart';
import '../l10n/hardcoded_localizations.dart';
import '../theme.dart';
import '../widgets/bottle_icon.dart';
import '../widgets/star_rating.dart';

class CommunityScreen extends StatefulWidget {
  final Future<CommunityFeed> Function()? loadCommunity;

  const CommunityScreen({super.key, this.loadCommunity});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late final Future<CommunityFeed>? _communityFuture = widget.loadCommunity
      ?.call();
  final Set<String> _liked = {};

  final _posts = [
    {
      'user': 'Mohammed Al-Omari',
      'init': 'MO',
      'time': '30 minutes ago',
      'perfume': 'Creed Aventus',
      'note':
          'Suitable for formal meetings — excellent longevity in cold weather',
      'longevity': 5,
      'sillage': 4,
      'accent': 0xFF6B8E23,
    },
    {
      'user': 'Sarah Al-Ghamdi',
      'init': 'SG',
      'time': '2 hours ago',
      'perfume': 'Amouage Interlude',
      'note': 'A complex, beautiful scent that changes an hour after spraying',
      'longevity': 5,
      'sillage': 5,
      'accent': 0xFF8B4513,
    },
    {
      'user': 'Abdullah Al-Rashed',
      'init': 'AR',
      'time': '5 hours ago',
      'perfume': 'Tom Ford Black Orchid',
      'note': 'I wore it to dinner and received many compliments',
      'longevity': 4,
      'sillage': 3,
      'accent': 0xFF4A0E4E,
    },
  ];

  final _reviewers = [
    {'name': 'Ahmed', 'medal': '🥇', 'count': '234'},
    {'name': 'Fatimah', 'medal': '🥈', 'count': '187'},
    {'name': 'Khalid', 'medal': '🥉', 'count': '156'},
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: kCream,
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_communityFuture == null) {
      return _buildFeed(null);
    }

    return FutureBuilder<CommunityFeed>(
      future: _communityFuture,
      builder: (context, snapshot) {
        return _buildFeed(snapshot.data);
      },
    );
  }

  Widget _buildFeed(CommunityFeed? feed) {
    final livePosts = feed?.posts ?? const <CommunityPost>[];
    final liveReviewers = feed?.reviewers ?? const <CommunityReviewer>[];
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              AppLocalizations.of(context).community,
              style: arabicStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildChallengeBanner()),
        SliverToBoxAdapter(
          child: liveReviewers.isEmpty
              ? _buildReviewers()
              : _buildLiveReviewers(liveReviewers),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              context.t('Today I wore...'),
              style: arabicStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: livePosts.isEmpty
                  ? _buildFallbackPostCard(i)
                  : _buildLivePostCard(livePosts[i]),
            ),
            childCount: livePosts.isEmpty ? _posts.length : livePosts.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildChallengeBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kGold, Color(0xFFA07C1A)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Weekly challenge'),
            style: arabicStyle(
              fontSize: 11,
              color: kOud.withValues(alpha: 0.6),
            ),
          ),
          Text(
            context.t('Eid challenge — share your favorite perfume'),
            style: arabicStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: kOud,
            ),
          ),
          Text(
            context.t('347 posts so far'),
            style: arabicStyle(
              fontSize: 12,
              color: kOud.withValues(alpha: 0.73),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: kOud,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              context.t('Share now'),
              style: arabicStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kGold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            AppLocalizations.of(context).topReviewers,
            style: arabicStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: _reviewers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final u = _reviewers[i];
              return Container(
                width: 90,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: kCardShadow,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(u['medal']!, style: const TextStyle(fontSize: 19)),
                      Text(
                        u['name']!,
                        style: arabicStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${u['count']} ${AppLocalizations.of(context).reviews}',
                        style: arabicStyle(fontSize: 11, color: kSand),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildLiveReviewers(List<CommunityReviewer> reviewers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            AppLocalizations.of(context).topReviewers,
            style: arabicStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: reviewers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final reviewer = reviewers[i];
              final medal = ['🥇', '🥈', '🥉', '⭐', '⭐'][i.clamp(0, 4)];
              return _reviewerTile(
                medal: medal,
                name: reviewer.user.displayName,
                count: _arabicNumber(reviewer.reviewsCount),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _reviewerTile({
    required String medal,
    required String name,
    required String count,
  }) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: kCardShadow,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(medal, style: const TextStyle(fontSize: 19)),
            Text(
              name,
              style: arabicStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            Text(
              '$count ${AppLocalizations.of(context).reviews}',
              style: arabicStyle(fontSize: 11, color: kSand),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackPostCard(int i) {
    final p = _posts[i];
    final accent = Color(p['accent'] as int);
    final id = 'fallback-$i';
    final isLiked = _liked.contains(id);
    return _postCard(
      id: id,
      user: p['user'] as String,
      initials: p['init'] as String,
      time: p['time'] as String,
      perfume: p['perfume'] as String,
      note: p['note'] as String,
      longevity: p['longevity'] as int,
      sillage: p['sillage'] as int,
      accent: accent,
      isLiked: isLiked,
    );
  }

  Widget _buildLivePostCard(CommunityPost post) {
    final isLiked = _liked.contains(post.id);
    return _postCard(
      id: post.id,
      user: post.user.displayName,
      initials: post.user.initials,
      time: _relativeTime(post.createdAt),
      perfume: post.perfumeName,
      note: post.content,
      longevity: post.longevity,
      sillage: post.sillage,
      accent: post.accent,
      isLiked: isLiked,
      commentsCount: post.commentsCount,
    );
  }

  Widget _postCard({
    required String id,
    required String user,
    required String initials,
    required String time,
    required String perfume,
    required String note,
    required int longevity,
    required int sillage,
    required Color accent,
    required bool isLiked,
    int commentsCount = 0,
  }) {
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
          Row(
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
                    initials,
                    style: arabicStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kOud,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user,
                      style: arabicStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(time, style: arabicStyle(fontSize: 11, color: kSand)),
                  ],
                ),
              ),
              Text(
                context.t('Follow'),
                style: arabicStyle(fontSize: 11, color: kGold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kCream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [kGoldPale, Colors.white],
                    ),
                  ),
                  child: Center(child: BottleIcon(color: accent, size: 24)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        perfume,
                        style: serifStyle(
                          fontSize: 13,
                          italic: true,
                          fontWeight: FontWeight.w600,
                          color: kEspresso,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${AppLocalizations.of(context).longevity}: ',
                            style: arabicStyle(fontSize: 11, color: kWarmGray),
                          ),
                          StarRating(rating: longevity.toDouble(), size: 10),
                          const SizedBox(width: 8),
                          Text(
                            '${AppLocalizations.of(context).sillage}: ',
                            style: arabicStyle(fontSize: 11, color: kWarmGray),
                          ),
                          StarRating(rating: sillage.toDouble(), size: 10),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            note,
            style: arabicStyle(fontSize: 13, color: kWarmGray, height: 1.6),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF5F0EB))),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(
                    () => isLiked ? _liked.remove(id) : _liked.add(id),
                  ),
                  child: Row(
                    children: [
                      Text(
                        isLiked ? '❤️' : '🤍',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.t('Like'),
                        style: arabicStyle(
                          fontSize: 13,
                          color: isLiked ? kRose : kWarmGray,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Text('💬', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  commentsCount == 0
                      ? context.t('Comment')
                      : '${_arabicNumber(commentsCount)} ${context.t('Comment')}',
                  style: arabicStyle(fontSize: 13, color: kWarmGray),
                ),
                const SizedBox(width: 16),
                const Text('🔖', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  context.t('Save'),
                  style: arabicStyle(fontSize: 13, color: kWarmGray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return context.t('Now');
    if (diff.inMinutes < 60) {
      return ht(context, 'ago {count} minute', {
        'count': _arabicNumber(diff.inMinutes),
      });
    }
    if (diff.inHours < 24) {
      return ht(context, 'ago {count} hour', {
        'count': _arabicNumber(diff.inHours),
      });
    }
    return ht(context, 'ago {count} day', {
      'count': _arabicNumber(diff.inDays),
    });
  }

  String _arabicNumber(int value) => value.toString();
}
