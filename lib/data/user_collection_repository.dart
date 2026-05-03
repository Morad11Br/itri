import 'package:supabase_flutter/supabase_flutter.dart';

class UserReview {
  final String userId;
  final String perfumeId;
  final int rating;
  final String? body;
  final String? displayName;
  final DateTime? createdAt;

  const UserReview({
    required this.userId,
    required this.perfumeId,
    required this.rating,
    this.body,
    this.displayName,
    this.createdAt,
  });
}

class CollectionStats {
  final int count;
  final double totalPrice;

  const CollectionStats({required this.count, required this.totalPrice});
}

class UserCollectionRepository {
  UserCollectionRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<CollectionStats> loadCollectionStats({required String userId}) async {
    final rows = await _client
        .from('user_collections')
        .select('price_paid')
        .eq('user_id', userId);

    final count = rows.length;
    final totalPrice = rows.fold<double>(0, (sum, r) {
      final price = r['price_paid'];
      return price is num ? sum + price.toDouble() : sum;
    });

    return CollectionStats(count: count, totalPrice: totalPrice);
  }

  Future<Map<String, String>> loadAllStatuses({required String userId}) async {
    final rows = await _client
        .from('user_collections')
        .select('perfume_id, status')
        .eq('user_id', userId);
    return {
      for (final r in rows) r['perfume_id'] as String: r['status'] as String,
    };
  }

  Future<Set<String>> loadAllFavorites({required String userId}) async {
    final rows = await _client
        .from('user_collections')
        .select('perfume_id')
        .eq('user_id', userId)
        .eq('is_favorite', true);
    return {for (final r in rows) r['perfume_id'] as String};
  }

  Future<bool> loadFavorite({
    required String userId,
    required String perfumeId,
  }) async {
    final row = await _client
        .from('user_collections')
        .select('is_favorite')
        .eq('user_id', userId)
        .eq('perfume_id', perfumeId)
        .maybeSingle();
    return row?['is_favorite'] == true;
  }

  Future<void> saveFavorite({
    required String userId,
    required String perfumeId,
    required bool isFavorite,
  }) async {
    await _client
        .from('user_collections')
        .update({
          'is_favorite': isFavorite,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('perfume_id', perfumeId);
  }

  Future<String?> loadStatus({
    required String userId,
    required String perfumeId,
  }) async {
    final row = await _client
        .from('user_collections')
        .select('status')
        .eq('user_id', userId)
        .eq('perfume_id', perfumeId)
        .maybeSingle();

    return row?['status']?.toString();
  }

  Future<void> saveStatus({
    required String userId,
    required String perfumeId,
    required String status,
  }) async {
    await _client.from('user_collections').upsert({
      'user_id': userId,
      'perfume_id': perfumeId,
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,perfume_id');
  }

  // Inserts a user-typed perfume into fragrances (satisfying the FK),
  // then saves the full manual-entry metadata to user_collections.
  Future<void> saveManualEntry({
    required String userId,
    required String name,
    String concentration = 'EDP',
    String acquisitionSource = 'Purchase',
    double? pricePaid,
    List<String> customAccords = const [],
    String? personalNotes,
  }) async {
    final sourceId =
        'custom_${DateTime.now().millisecondsSinceEpoch}_${userId.substring(0, 8)}';

    await _client.from('fragrances').upsert({
      'source_id': sourceId,
      'name': name,
      'brand': 'Custom',
      'rating': 0.0,
      'rating_votes': 0,
      'accords': customAccords.isEmpty ? null : customAccords,
      'notes': customAccords.isEmpty
          ? null
          : {'top': customAccords, 'middle': [], 'base': []},
    }, onConflict: 'source_id');

    await _client.from('user_collections').upsert({
      'user_id': userId,
      'perfume_id': sourceId,
      'status': 'owned',
      'concentration': concentration,
      'acquisition_source': acquisitionSource,
      'price_paid': pricePaid,
      'personal_notes': personalNotes,
      'custom_accords': customAccords.isEmpty ? null : customAccords,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,perfume_id');
  }

  Future<void> deleteStatus({
    required String userId,
    required String perfumeId,
  }) async {
    await _client
        .from('user_collections')
        .delete()
        .eq('user_id', userId)
        .eq('perfume_id', perfumeId);
  }

  Future<UserReview?> loadUserReview({
    required String userId,
    required String perfumeId,
  }) async {
    final row = await _client
        .from('reviews')
        .select('rating, body, created_at')
        .eq('user_id', userId)
        .eq('perfume_id', perfumeId)
        .maybeSingle();
    if (row == null) return null;
    return UserReview(
      userId: userId,
      perfumeId: perfumeId,
      rating: (row['rating'] as num?)?.toInt() ?? 0,
      body: row['body'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'].toString())
          : null,
    );
  }

  Future<List<UserReview>> loadPerfumeReviews({
    required String perfumeId,
    int limit = 10,
  }) async {
    final rows = await _client
        .from('reviews')
        .select('user_id, rating, body, created_at, users(display_name)')
        .eq('perfume_id', perfumeId)
        .gt('rating', 0)
        .order('created_at', ascending: false)
        .limit(limit);
    return [
      for (final r in rows)
        UserReview(
          userId: r['user_id']?.toString() ?? '',
          perfumeId: perfumeId,
          rating: (r['rating'] as num?)?.toInt() ?? 0,
          body: r['body'] as String?,
          displayName: (r['users'] as Map?)?['display_name'] as String?,
          createdAt: r['created_at'] != null
              ? DateTime.tryParse(r['created_at'].toString())
              : null,
        ),
    ];
  }

  Future<void> saveReview({
    required String userId,
    required String perfumeId,
    required int rating,
    String? body,
  }) async {
    await _client.from('reviews').upsert({
      'user_id': userId,
      'perfume_id': perfumeId,
      'rating': rating,
      'body': (body != null && body.trim().isNotEmpty) ? body.trim() : null,
    }, onConflict: 'user_id,perfume_id');
  }
}
