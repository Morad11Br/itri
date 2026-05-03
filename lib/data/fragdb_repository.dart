import 'dart:math';

import 'package:flutter/services.dart';

import '../models/perfume.dart';

class FragDbRepository {
  static const _fragrancesPath = 'assets/fragdb/fragrances.csv';
  static const _notesPath = 'assets/fragdb/notes.csv';

  Future<List<Perfume>> loadPerfumes() async {
    final results = await Future.wait([
      rootBundle.loadString(_fragrancesPath),
      rootBundle.loadString(_notesPath),
    ]);

    final notes = _loadNotes(results[1]);
    final rows = _parsePipeCsv(results[0]);
    if (rows.isEmpty) return const [];

    final headers = rows.first;
    return rows
        .skip(1)
        .map((row) {
          final record = _toRecord(headers, row);
          return _toPerfume(record, notes);
        })
        .toList(growable: false);
  }

  Map<String, _NoteRecord> _loadNotes(String csv) {
    final rows = _parsePipeCsv(csv);
    if (rows.isEmpty) return const {};

    final headers = rows.first;
    final records = <String, _NoteRecord>{};
    for (final row in rows.skip(1)) {
      final record = _toRecord(headers, row);
      final id = record['id'] ?? '';
      if (id.isEmpty) continue;
      records[id] = _NoteRecord(
        id: id,
        name: record['name'] ?? id,
        group: record['group'] ?? '',
      );
    }
    return records;
  }

  Perfume _toPerfume(
    Map<String, String> record,
    Map<String, _NoteRecord> notes,
  ) {
    final brand = _labelBeforeId(record['brand'] ?? '');
    final rating =
        double.tryParse((record['rating'] ?? '').split(';').first) ?? 0;
    final reviews = int.tryParse(record['reviews_count'] ?? '');
    final accent = _accentFor(record['accords'] ?? brand);
    final description = _cleanHtml(record['description'] ?? '');

    return Perfume(
      id: record['pid'] ?? '',
      sourceUrl: record['url'] ?? '',
      name: record['name'] ?? '',
      brand: brand,
      rating: rating,
      count: reviews == null ? '0' : _arabicNumber(_compactCount(reviews)),
      accent: accent,
      imageUrl: (record['main_photo']?.isNotEmpty ?? false)
          ? record['main_photo']
          : null,
      description: description.isEmpty ? null : description,
      year: int.tryParse(record['year'] ?? ''),
      gender: _genderLabel(record['gender'] ?? ''),
      accords: _accords(record['accords'] ?? ''),
      topNotes: _notesForTier(
        record['notes_pyramid'] ?? '',
        'top',
        notes,
        accent,
      ),
      heartNotes: _notesForTier(
        record['notes_pyramid'] ?? '',
        'middle',
        notes,
        accent,
      ),
      baseNotes: _notesForTier(
        record['notes_pyramid'] ?? '',
        'base',
        notes,
        accent,
      ),
    );
  }

  List<FragranceNote> _notesForTier(
    String pyramid,
    String tier,
    Map<String, _NoteRecord> notes,
    Color accent,
  ) {
    final match = RegExp('$tier\\(([^)]*)\\)').firstMatch(pyramid);
    if (match == null) return const [];

    final ids = match
        .group(1)!
        .split(';')
        .map((item) => item.split(',').first.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .take(6);

    return ids
        .map((id) {
          final note = notes[id];
          return FragranceNote(
            id: id,
            name: note?.name ?? id.toUpperCase(),
            color: _noteColor(note?.group ?? id, accent),
          );
        })
        .toList(growable: false);
  }

  List<List<String>> _parsePipeCsv(String input) {
    final rows = <List<String>>[];
    final row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      final next = i + 1 < input.length ? input[i + 1] : null;

      if (char == '"') {
        if (inQuotes && next == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == '|' && !inQuotes) {
        row.add(field.toString());
        field.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && next == '\n') i++;
        row.add(field.toString());
        field.clear();
        if (row.any((value) => value.isNotEmpty)) {
          rows.add(List<String>.from(row));
        }
        row.clear();
      } else {
        field.write(char);
      }
    }

    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(List<String>.from(row));
    }

    return rows;
  }

  Map<String, String> _toRecord(List<String> headers, List<String> row) {
    final record = <String, String>{};
    for (var i = 0; i < headers.length; i++) {
      record[headers[i]] = i < row.length ? row[i] : '';
    }
    return record;
  }

  String _labelBeforeId(String value) => value.split(';').first.trim();

  List<String> _accords(String value) {
    return value
        .split(';')
        .map((item) => item.split(':').first.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _cleanHtml(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _genderLabel(String value) {
    return switch (value) {
      'gender_for_women' => 'Women',
      'gender_for_men' => 'Men',
      'gender_for_women_and_men' => 'Unisex',
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

class _NoteRecord {
  final String id;
  final String name;
  final String group;

  const _NoteRecord({
    required this.id,
    required this.name,
    required this.group,
  });
}
