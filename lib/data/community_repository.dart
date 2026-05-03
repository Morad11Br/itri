import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityUser {
  final String id;
  final String displayName;
  final String initials;
  final int followersCount;

  const CommunityUser({
    required this.id,
    required this.displayName,
    required this.initials,
    required this.followersCount,
  });
}

class CommunityPost {
  final String id;
  final CommunityUser user;
  final String perfumeName;
  final String content;
  final int longevity;
  final int sillage;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final Color accent;

  const CommunityPost({
    required this.id,
    required this.user,
    required this.perfumeName,
    required this.content,
    required this.longevity,
    required this.sillage,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    required this.accent,
  });
}

class CommunityReviewer {
  final CommunityUser user;
  final int reviewsCount;

  const CommunityReviewer({required this.user, required this.reviewsCount});
}

class CommunityFeed {
  final List<CommunityPost> posts;
  final List<CommunityReviewer> reviewers;

  const CommunityFeed({required this.posts, required this.reviewers});
}

class ProfileStats {
  final CommunityUser? user;
  final int collectionCount;
  final int reviewsCount;
  final int postsCount;
  final int followersCount;
  final List<ProfileNoteStat> notes;

  const ProfileStats({
    required this.user,
    required this.collectionCount,
    required this.reviewsCount,
    required this.postsCount,
    required this.followersCount,
    required this.notes,
  });
}

class ProfileNoteStat {
  final String name;
  final int percent;
  final Color color;

  const ProfileNoteStat({
    required this.name,
    required this.percent,
    required this.color,
  });
}

class CommunityRepository {
  CommunityRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> ensureUserProfile({
    required String userId,
    String? email,
    String? name,
  }) async {
    final displayName = _displayName(name: name, email: email);
    await _client.from('users').upsert({
      'id': userId,
      'display_name': displayName,
      'avatar_initials': _initials(displayName),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id');
  }

  Future<CommunityFeed> loadCommunityFeed() async {
    final postRows = await _client
        .from('posts')
        .select(
          'id, user_id, perfume_id, content, longevity, sillage, likes_count, '
          'comments_count, created_at',
        )
        .order('created_at', ascending: false)
        .limit(30);

    final reviewRows = await _client
        .from('reviews')
        .select('user_id')
        .order('created_at', ascending: false)
        .limit(500);

    final userIds = <String>{
      ...postRows.map((row) => row['user_id']?.toString() ?? ''),
      ...reviewRows.map((row) => row['user_id']?.toString() ?? ''),
    }..removeWhere((id) => id.isEmpty);
    final perfumeIds = postRows
        .map((row) => row['perfume_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final users = await _loadUsers(userIds.toList());
    final perfumes = await _loadPerfumeNames(perfumeIds);

    final reviewCounts = <String, int>{};
    for (final row in reviewRows) {
      final userId = row['user_id']?.toString();
      if (userId == null || userId.isEmpty) continue;
      reviewCounts[userId] = (reviewCounts[userId] ?? 0) + 1;
    }

    final reviewers =
        reviewCounts.entries
            .map((entry) {
              final user = users[entry.key];
              if (user == null) return null;
              return CommunityReviewer(user: user, reviewsCount: entry.value);
            })
            .whereType<CommunityReviewer>()
            .toList()
          ..sort((a, b) => b.reviewsCount.compareTo(a.reviewsCount));

    final posts = postRows
        .map((row) {
          final userId = row['user_id']?.toString() ?? '';
          final perfumeId = row['perfume_id']?.toString() ?? '';
          return CommunityPost(
            id: row['id']?.toString() ?? '',
            user: users[userId] ?? _anonymousUser(userId),
            perfumeName: perfumes[perfumeId] ?? 'Unspecified perfume',
            content: row['content']?.toString() ?? '',
            longevity: _int(row['longevity']) ?? 0,
            sillage: _int(row['sillage']) ?? 0,
            likesCount: _int(row['likes_count']) ?? 0,
            commentsCount: _int(row['comments_count']) ?? 0,
            createdAt: _date(row['created_at']),
            accent: _accentFor(perfumeId.isEmpty ? userId : perfumeId),
          );
        })
        .toList(growable: false);

    return CommunityFeed(
      posts: posts,
      reviewers: reviewers.take(5).toList(growable: false),
    );
  }

  Future<ProfileStats> loadProfileStats(String userId) async {
    final users = await _loadUsers([userId]);
    final collectionRows = await _client
        .from('user_collections')
        .select('perfume_id')
        .eq('user_id', userId)
        .limit(500);
    final reviewRows = await _client
        .from('reviews')
        .select('id')
        .eq('user_id', userId)
        .limit(500);
    final postRows = await _client
        .from('posts')
        .select('id')
        .eq('user_id', userId)
        .limit(500);

    final perfumeIds = collectionRows
        .map((row) => row['perfume_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final notes = await _loadProfileNotes(perfumeIds);
    final user = users[userId];

    return ProfileStats(
      user: user,
      collectionCount: collectionRows.length,
      reviewsCount: reviewRows.length,
      postsCount: postRows.length,
      followersCount: user?.followersCount ?? 0,
      notes: notes,
    );
  }

  Future<Map<String, CommunityUser>> _loadUsers(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('users')
        .select('id, display_name, avatar_initials, followers_count')
        .inFilter('id', ids);

    return {
      for (final row in rows)
        row['id'].toString(): CommunityUser(
          id: row['id'].toString(),
          displayName: _string(row['display_name'], fallback: 'Itri User'),
          initials: _string(row['avatar_initials'], fallback: 'MO'),
          followersCount: _int(row['followers_count']) ?? 0,
        ),
    };
  }

  Future<Map<String, String>> _loadPerfumeNames(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('fragrances')
        .select('source_id, name, brand')
        .inFilter('source_id', ids);

    return {
      for (final row in rows)
        row['source_id'].toString():
            '${_string(row['brand'])} ${_string(row['name'])}'.trim(),
    };
  }

  Future<List<ProfileNoteStat>> _loadProfileNotes(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client
        .from('fragrances')
        .select('accords')
        .inFilter('source_id', ids);

    final counts = <String, int>{};
    for (final row in rows) {
      final accords = row['accords'];
      if (accords is! List) continue;
      for (final accord in accords.take(3)) {
        final name = accord.toString().trim();
        if (name.isEmpty) continue;
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return const [];

    final total = counts.values.fold<int>(0, (sum, value) => sum + value);
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries
        .take(5)
        .map((entry) {
          return ProfileNoteStat(
            name: _arabicAccord(entry.key),
            percent: ((entry.value / total) * 100).round(),
            color: _accentFor(entry.key),
          );
        })
        .toList(growable: false);
  }

  CommunityUser _anonymousUser(String userId) {
    return CommunityUser(
      id: userId,
      displayName: 'Itri User',
      initials: 'MO',
      followersCount: 0,
    );
  }

  String _displayName({String? name, String? email}) {
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) return trimmedName;
    final emailName = email?.split('@').first.trim();
    if (emailName != null && emailName.isNotEmpty) return emailName;
    return 'Itri User';
  }

  String _initials(String name) {
    final compact = name.trim().replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) return 'MO';
    return compact.length <= 2 ? compact : compact.substring(0, 2);
  }

  String _string(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  DateTime _date(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  String _arabicAccord(String value) {
    return switch (value.toLowerCase()) {
      'oud' => 'Oud',
      'musky' => 'Musk',
      'musk' => 'Musk',
      'rose' => 'Rose',
      'amber' => 'Amber',
      'woody' => 'Woody',
      'fresh' => 'Fresh',
      'citrus' => 'Citrus',
      'floral' => 'Floral',
      'vanilla' => 'Vanilla',
      _ => value,
    };
  }

  Color _accentFor(String seed) {
    const palette = [
      Color(0xFF6B8E23),
      Color(0xFF8B4513),
      Color(0xFF4A0E4E),
      Color(0xFF3B6F7D),
      Color(0xFFA14D3A),
      Color(0xFF7B5D9A),
      Color(0xFFB7791F),
      Color(0xFF4F6F52),
    ];
    if (seed.isEmpty) return palette.first;
    return palette[seed.hashCode.abs() % palette.length];
  }
}
