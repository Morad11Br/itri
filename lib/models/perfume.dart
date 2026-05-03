import 'package:flutter/material.dart';

class FragranceNote {
  final String id;
  final String name;
  final Color color;

  const FragranceNote({
    required this.id,
    required this.name,
    required this.color,
  });
}

class Perfume {
  final String id;
  final String sourceUrl;
  final String name;
  final String brand;
  final double rating;
  final String count;
  final Color accent;
  final String? imageUrl;
  final String? fallbackImageUrl;
  final String? description;
  final int? year;
  final String? gender;
  final List<String> accords;
  final List<FragranceNote> topNotes;
  final List<FragranceNote> heartNotes;
  final List<FragranceNote> baseNotes;

  const Perfume({
    this.id = '',
    this.sourceUrl = '',
    required this.name,
    required this.brand,
    required this.rating,
    this.count = '0',
    this.accent = const Color(0xFFC9A227),
    this.imageUrl,
    this.fallbackImageUrl,
    this.description,
    this.year,
    this.gender,
    this.accords = const [],
    this.topNotes = const [],
    this.heartNotes = const [],
    this.baseNotes = const [],
  });
}

final List<Perfume> kTrendingPerfumes = [
  Perfume(
    name: 'Aventus',
    brand: 'Creed',
    rating: 4.8,
    count: '2,341',
    accent: const Color(0xFF6B8E23),
  ),
  Perfume(
    name: 'Cambodian Oud',
    brand: 'Amouage',
    rating: 4.9,
    count: '1,876',
    accent: const Color(0xFF8B4513),
  ),
  Perfume(
    name: 'Royal Musk',
    brand: 'Rasasi',
    rating: 4.6,
    count: '984',
    accent: const Color(0xFFD4A5A5),
  ),
  Perfume(
    name: 'Black Orchid',
    brand: 'Tom Ford',
    rating: 4.7,
    count: '1,223',
    accent: const Color(0xFF4A0E4E),
  ),
];

final List<Perfume> kCollectionPerfumes = [
  Perfume(
    name: 'Aventus',
    brand: 'Creed',
    rating: 4.8,
    accent: const Color(0xFF6B8E23),
  ),
  Perfume(
    name: 'Cambodian Oud',
    brand: 'Amouage',
    rating: 4.9,
    accent: const Color(0xFF8B4513),
  ),
  Perfume(
    name: 'Royal Musk',
    brand: 'Rasasi',
    rating: 4.6,
    accent: const Color(0xFFD4A5A5),
  ),
  Perfume(
    name: 'Black Orchid',
    brand: 'Tom Ford',
    rating: 4.7,
    accent: const Color(0xFF4A0E4E),
  ),
  Perfume(
    name: 'Silver Mountain',
    brand: 'Creed',
    rating: 4.5,
    accent: const Color(0xFF708090),
  ),
  Perfume(
    name: 'Rose Oud',
    brand: 'Maison Margiela',
    rating: 4.3,
    accent: const Color(0xFFFF69B4),
  ),
];
