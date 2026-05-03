import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/deal.dart';

class DealsRepository {
  DealsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Deal>> loadActiveDeals() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _client
        .from('deals')
        .select('store_name, description, color_hex')
        .eq('is_active', true)
        .or('expires_at.is.null,expires_at.gt.$now')
        .order('sort_order')
        .limit(10);

    return [
      for (final r in rows)
        Deal(
          store: r['store_name'] as String,
          description: r['description'] as String,
          color: _parseColor(r['color_hex'] as String? ?? '#3D2314'),
        ),
    ];
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }
}
