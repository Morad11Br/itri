import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ai_recommendation.dart';
import '../models/dupe_recommendation.dart';
import '../models/perfume.dart';
import 'note_translations.dart';

class SupabaseFragranceRepository {
  SupabaseFragranceRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const int defaultPageSize = 30;

  Future<List<Perfume>> loadTrendingPerfumes({int limit = 12}) {
    return loadPerfumePage(page: 0, pageSize: limit);
  }

  Future<List<Perfume>> loadPerfumesByAccord(
    String accord, {
    int limit = 6,
    int offset = 0,
  }) async {
    final to = offset + limit - 1;
    final rows = await _client
        .from('fragrances')
        .select(
          'source_id, source_url, name, brand, image_url, fallback_image_url, '
          'year, gender, rating, rating_votes, accords',
        )
        .filter('accords', 'cs', '["$accord"]')
        .order('popularity_score', ascending: false)
        .order('source_id')
        .range(offset, to);

    return rows.map(_toPerfume).toList(growable: false);
  }

  Future<List<Perfume>> findPerfumesForOccasion({
    required List<String> occasionAccords,
    required List<String> styleAccords,
    required List<String> seasonAccords,
    String? gender,
    int limit = 10,
    String? priceTier,
    List<String>? tierBrands,
  }) async {
    final allAccords = {
      ...occasionAccords.map((a) => a.trim().toLowerCase()),
      ...styleAccords.map((a) => a.trim().toLowerCase()),
      ...seasonAccords.map((a) => a.trim().toLowerCase()),
    }..removeWhere((a) => a.isEmpty);

    var rows = await _findOccasionRows(
      accordValues: allAccords.toList(),
      gender: gender,
      tierBrands: tierBrands,
      limit: max(limit * 12, 80),
    );

    if (rows.isEmpty && allAccords.isNotEmpty) {
      rows = await _findOccasionRows(
        accordValues: const [],
        gender: gender,
        tierBrands: tierBrands,
        limit: max(limit * 12, 80),
      );
    }

    final perfumes = rows.map(_toPerfume).toList(growable: false);
    final ranked = [...perfumes]
      ..sort((a, b) {
        final scoreB = _occasionMatchScore(b, occasionAccords, styleAccords);
        final scoreA = _occasionMatchScore(a, occasionAccords, styleAccords);
        final scoreCompare = scoreB.compareTo(scoreA);
        if (scoreCompare != 0) return scoreCompare;
        return b.rating.compareTo(a.rating);
      });

    return ranked.take(limit).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _findOccasionRows({
    required List<String> accordValues,
    required String? gender,
    required int limit,
    List<String>? tierBrands,
  }) async {
    var query = _client
        .from('fragrances')
        .select(
          'source_id, source_url, name, brand, image_url, fallback_image_url, '
          'year, gender, rating, rating_votes, accords',
        );
    final genderValues = _genderFilters(gender);
    if (genderValues.isNotEmpty) {
      query = query.inFilter('gender', genderValues);
    }

    if (tierBrands != null && tierBrands.isNotEmpty) {
      query = query.or(
        tierBrands.map((b) => 'brand.ilike."%$b%"').join(','),
      );
    }

    if (accordValues.isNotEmpty) {
      query = query.or(
        accordValues.map((accord) => 'accords.cs.["$accord"]').join(','),
      );
    }

    final rows = await query
        .order('popularity_score', ascending: false)
        .limit(limit);

    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<Perfume>> loadPerfumePage({
    required int page,
    int pageSize = defaultPageSize,
  }) async {
    return loadPerfumeRange(offset: page * pageSize, limit: pageSize);
  }

  Future<List<Perfume>> loadPerfumeRange({
    required int offset,
    int limit = defaultPageSize,
  }) async {
    final to = offset + limit - 1;
    final rows = await _client
        .from('fragrances')
        .select(
          'source_id, source_url, name, brand, image_url, fallback_image_url, '
          'year, gender, rating, rating_votes, accords',
        )
        .order('popularity_score', ascending: false)
        .order('source_id')
        .range(offset, to);

    return rows.map(_toPerfume).toList(growable: false);
  }

  Future<List<Perfume>> searchPerfumes(String query, {int limit = 20}) async {
    final term = query.trim();
    if (term.isEmpty) return loadTrendingPerfumes(limit: limit);

    final rowsById = <String, Map<String, dynamic>>{};

    void addRows(List<dynamic> rows) {
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final id = _string(row['source_id']);
        if (id.isNotEmpty) rowsById.putIfAbsent(id, () => row);
      }
    }

    const selectFields =
        'source_id, source_url, name, brand, image_url, fallback_image_url, '
        'year, gender, rating, rating_votes, accords, notes';

    final escapedTerm = _escapeIlike(term);
    final textRows = await _client
        .from('fragrances')
        .select(selectFields)
        .or(
          'name.ilike.%$escapedTerm%,brand.ilike.%$escapedTerm%,gender.ilike.%$escapedTerm%',
        )
        .order('popularity_score', ascending: false)
        .limit(limit);
    addRows(textRows);

    // Multi-word query (e.g. "Creed Aventus"): search each token individually
    // so "brand=Creed, name=Aventus" is found even though neither field alone
    // contains the full phrase.
    if (rowsById.length < limit) {
      final tokens = _normalizeKeyword(term)
          .split(RegExp(r'[^a-z0-9]+'))
          .where((t) => t.length >= 2)
          .toSet();
      if (tokens.length > 1) {
        final tokenFilter = tokens
            .map((t) => 'name.ilike.%$t%,brand.ilike.%$t%')
            .join(',');
        final tokenRows = await _client
            .from('fragrances')
            .select(selectFields)
            .or(tokenFilter)
            .order('popularity_score', ascending: false)
            .limit(limit * 3);
        addRows(tokenRows);
      }
    }

    final keywordAccords = _searchAccords(term);
    if (keywordAccords.isNotEmpty && rowsById.length < limit) {
      final accordRows = await _client
          .from('fragrances')
          .select(
            'source_id, source_url, name, brand, image_url, fallback_image_url, '
            'year, gender, rating, rating_votes, accords, notes',
          )
          .or(
            keywordAccords.map((accord) => 'accords.cs.["$accord"]').join(','),
          )
          .order('popularity_score', ascending: false)
          .limit(limit);
      addRows(accordRows);
    }

    var rows = rowsById.values.toList(growable: false);
    rows.sort((a, b) {
      final scoreB = _searchScore(b, term);
      final scoreA = _searchScore(a, term);
      final scoreCompare = scoreB.compareTo(scoreA);
      if (scoreCompare != 0) return scoreCompare;
      return (_double(b['rating'])).compareTo(_double(a['rating']));
    });

    return rows.take(limit).map(_toPerfume).toList(growable: false);
  }

  Future<
    ({String brand, String name, String confidence, List<Perfume> matches})
  >
  identifyByImage(String base64Image) async {
    final response = await _client.functions.invoke(
      'identify-perfume-image',
      body: {'image': base64Image},
    );

    final data = response.data;
    if (data is Map && data.containsKey('error')) {
      throw Exception(data['error']);
    }

    final brand = (data['brand'] as String?) ?? '';
    final name = (data['name'] as String?) ?? '';
    final confidence = (data['confidence'] as String?) ?? 'low';
    final matches = (data['matches'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(_toPerfume)
        .toList(growable: false);

    return (brand: brand, name: name, confidence: confidence, matches: matches);
  }

  Future<List<AiRecommendation>> findByAi({
    required String occasion,
    required String style,
    required String gender,
    required String season,
    required String intensity,
  }) async {
    final response = await _client.functions.invoke(
      'find-perfume',
      body: {
        'occasion': occasion,
        'style': style,
        'gender': gender,
        'season': season,
        'intensity': intensity,
      },
    );

    final data = response.data;
    if (data is Map && data.containsKey('error')) {
      throw Exception(data['error']);
    }
    if (data is! List) throw Exception('Unexpected response format');

    return [
      for (final item in data)
        AiRecommendation(
          perfume: _toPerfume(item as Map<String, dynamic>),
          reason: (item['ai_reason'] as String?) ?? '',
        ),
    ];
  }

  Future<DupeFinderResult> findDupesByAi(
    Perfume reference, {
    int limit = 8,
    int? referencePriceSar,
  }) async {
    final response = await _client.functions.invoke(
      'find-dupes',
      body: {
        'limit': limit,
        'referencePriceSar': referencePriceSar,
        'reference': {
          'name': reference.name,
          'brand': reference.brand,
          'accords': reference.accords,
          'topNotes': reference.topNotes.map((n) => n.id).toList(),
          'heartNotes': reference.heartNotes.map((n) => n.id).toList(),
          'baseNotes': reference.baseNotes.map((n) => n.id).toList(),
        },
      },
    );

    final data = response.data;
    if (data is Map && data.containsKey('error')) {
      throw Exception(data['error']);
    }
    if (data is! Map) throw Exception('Unexpected response format');

    final referencePriceRangeSar = data['reference_price_range_sar']
        ?.toString();
    final dupesList = data['dupes'] as List? ?? [];

    final dupes = [
      for (final item in dupesList)
        DupeRecommendation(
          perfume: _toPerfume(item as Map<String, dynamic>),
          reason: (item['ai_reason'] as String?) ?? '',
          similarityPct: (item['similarity_pct'] as num?)?.toInt() ?? 0,
          priceRangeSar: item['price_range_sar']?.toString(),
        ),
    ];

    return DupeFinderResult(
      dupes: dupes,
      referencePriceRangeSar: referencePriceRangeSar,
    );
  }

  Future<Perfume> loadPerfumeDetails(String sourceId) async {
    final row = await _client
        .from('fragrances')
        .select(
          'source_id, source_url, name, brand, image_url, fallback_image_url, '
          'year, gender, rating, rating_votes, description, accords, notes',
        )
        .eq('source_id', sourceId)
        .single();

    return _toPerfume(row);
  }

  Future<List<Perfume>> loadPerfumesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await _client
        .from('fragrances')
        .select(
          'source_id, source_url, name, brand, image_url, fallback_image_url, '
          'year, gender, rating, rating_votes, accords, notes',
        )
        .inFilter('source_id', ids);
    return rows.map(_toPerfume).toList(growable: false);
  }

  Perfume _toPerfume(Map<String, dynamic> row) {
    final brand = _string(row['brand']);
    final accords = _stringList(row['accords']);
    final notes = row['notes'] is Map<String, dynamic>
        ? row['notes'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final accent = _accentFor(accords.isNotEmpty ? accords.join('|') : brand);
    final ratingVotes = _int(row['rating_votes']);

    return Perfume(
      id: _string(row['source_id']),
      sourceUrl: _string(row['source_url']),
      name: _string(row['name']),
      brand: brand,
      rating: _double(row['rating']),
      count: ratingVotes == null
          ? '0'
          : _arabicNumber(_compactCount(ratingVotes)),
      accent: accent,
      imageUrl: _nullableString(row['image_url']),
      fallbackImageUrl: _nullableString(row['fallback_image_url']),
      description: _nullableString(row['description']),
      year: _int(row['year']),
      gender: _genderLabel(_string(row['gender'])),
      accords: accords,
      topNotes: _notesForTier(notes, 'top', accent),
      heartNotes: _notesForTier(notes, 'middle', accent),
      baseNotes: _notesForTier(notes, 'base', accent),
    );
  }

  List<FragranceNote> _notesForTier(
    Map<String, dynamic> notes,
    String tier,
    Color accent,
  ) {
    final values = notes[tier];
    if (values is! List) return const [];

    return values
        .whereType<Object>()
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .take(6)
        .map(
          (name) => FragranceNote(
            id: name,
            name: NoteTranslations.translate(name),
            color: _noteColor(name, accent),
          ),
        )
        .toList(growable: false);
  }

  String _string(Object? value) => value?.toString() ?? '';

  String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  double _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Object>()
        .map((item) => item.toString().trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _escapeIlike(String value) {
    return value
        .replaceAll('\\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_')
        .replaceAll(',', ' ');
  }

  Set<String> _searchAccords(String query) {
    final normalized = _normalizeKeyword(query);
    final tokens = normalized
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 2)
        .toSet();
    final candidates = <String>{normalized, ...tokens};
    final accords = <String>{};
    for (final item in candidates) {
      final mapped = _keywordToAccord[item];
      if (mapped != null && mapped.isNotEmpty) accords.add(mapped);
    }
    return accords;
  }

  int _searchScore(Map<String, dynamic> row, String query) {
    final normalizedQuery = _normalizeKeyword(query);
    final tokens = normalizedQuery
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 2)
        .toList(growable: false);
    if (tokens.isEmpty) return 0;

    final name = _normalizeKeyword(_string(row['name']));
    final brand = _normalizeKeyword(_string(row['brand']));
    final gender = _normalizeKeyword(_genderLabel(_string(row['gender'])));
    final accords = _stringList(row['accords']).map(_normalizeKeyword).toSet();
    final noteText = _notesSearchText(row['notes']);

    var score = 0;
    for (final token in tokens) {
      if (name == normalizedQuery || brand == normalizedQuery) score += 120;
      if (name.contains(token)) score += 45;
      if (brand.contains(token)) score += 35;
      if (gender.contains(token)) score += 18;
      if (accords.contains(token)) score += 30;
      final mappedAccord = _keywordToAccord[token];
      if (mappedAccord != null && accords.contains(mappedAccord)) score += 30;
      if (noteText.contains(token)) score += 20;
    }
    return score;
  }

  String _notesSearchText(Object? value) {
    if (value is! Map) return '';
    return value.values
        .whereType<List>()
        .expand((items) => items)
        .map((item) => _normalizeKeyword(item.toString()))
        .join(' ');
  }

  String _normalizeKeyword(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  static const Map<String, String> _keywordToAccord = {
    'all': '',
    'oud': 'oud',
    'agarwood': 'oud',
    'musk': 'musky',
    'musky': 'musky',
    'citrus': 'citrus',
    'fresh': 'fresh',
    'floral': 'floral',
    'flower': 'floral',
    'flowers': 'floral',
    'rose': 'rose',
    'woody': 'woody',
    'wood': 'woody',
    'woods': 'woody',
    'oriental': 'oriental',
    'amber': 'amber',
    'ambery': 'amber',
    'vanilla': 'vanilla',
    'sweet': 'sweet',
    'spice': 'spicy',
    'spicy': 'spicy',
    'warm': 'warm spicy',
    'warm spicy': 'warm spicy',
    'aromatic': 'aromatic',
    'aquatic': 'aquatic',
    'green': 'green',
    'leather': 'leather',
    'smoky': 'smoky',
    'smoke': 'smoky',
    'powder': 'powdery',
    'powdery': 'powdery',
    'tobacco': 'tobacco',
    'saffron': 'saffron',
    'incense': 'incense',
    'niche': 'aromatic',
    'western': 'fresh',
  };

  String _genderLabel(String value) {
    return switch (_normalizedGender(value)) {
      'women' => 'Women',
      'men' => 'Men',
      'unisex' => 'Unisex',
      _ => value,
    };
  }

  List<String> _genderFilters(String? value) {
    return switch (value) {
      'men' => const [
        'men',
        'Men',
        'male',
        'Male',
        'for men',
        'For Men',
        'gender_for_men',
      ],
      'women' => const [
        'women',
        'Women',
        'female',
        'Female',
        'for women',
        'For Women',
        'gender_for_women',
      ],
      'unisex' => const [
        'unisex',
        'Unisex',
        'women and men',
        'Women And Men',
        'for women and men',
        'For Women And Men',
        'gender_for_women_and_men',
      ],
      _ => const [],
    };
  }

  String _normalizedGender(String value) {
    final text = value.trim().toLowerCase().replaceAll('_', ' ');
    if (text.isEmpty) return '';
    if (text.contains('women and men') ||
        text.contains('woman and man') ||
        text.contains('unisex')) {
      return 'unisex';
    }
    if (text.contains('women') ||
        text.contains('woman') ||
        text.contains('female')) {
      return 'women';
    }
    if (text.contains('men') || text.contains('man') || text.contains('male')) {
      return 'men';
    }
    return text;
  }

  int _occasionMatchScore(
    Perfume perfume,
    List<String> occasionAccords,
    List<String> styleAccords,
  ) {
    final accordSet = perfume.accords.toSet();
    final occasionMatches = occasionAccords
        .map((accord) => accord.toLowerCase())
        .where(accordSet.contains)
        .length;
    final styleMatches = styleAccords
        .map((accord) => accord.toLowerCase())
        .where(accordSet.contains)
        .length;
    return (occasionMatches * 2) + (styleMatches * 4);
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
    return palette[seed.hashCode.abs() % palette.length];
  }

  Color _noteColor(String seed, Color fallback) {
    if (seed.isEmpty) return fallback;
    final random = Random(seed.hashCode);
    return Color.fromARGB(
      255,
      80 + random.nextInt(130),
      70 + random.nextInt(120),
      60 + random.nextInt(120),
    );
  }

  String _compactCount(int value) {
    if (value >= 1000) {
      final compact = value / 1000;
      return '${compact.toStringAsFixed(compact >= 10 ? 0 : 1)}k';
    }
    return value.toString();
  }

  String _arabicNumber(String input) => input;
}
