import 'package:flutter/material.dart';
import '../models/perfume.dart';
import 'bottle_reveal_screen.dart';

/// Full-screen animated dupe-finder demo, optimised for screen-recording
/// TikTok / X content. Uses hardcoded demo data with a simulated delay so
/// the scanning animation always has time to play.
///
/// Usage:
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => const DupeFinderDemoScreen(),
///   ));
class DupeFinderDemoScreen extends StatelessWidget {
  const DupeFinderDemoScreen({super.key});

  static const _reference = Perfume(
    name: 'Bleu De Chanel',
    brand: 'Chanel',
    rating: 4.9,
    accent: Color(0xFFCAA14A),
  );

  static Future<List<BottleDupeResult>> _demoDupes() async {
    await Future.delayed(const Duration(seconds: 3));
    return const [
      BottleDupeResult(
        perfume: Perfume(
          name: 'Oud Noir',
          brand: 'Maison Lila',
          rating: 4.5,
          accent: Color(0xFFD4AF70),
          accords: ['كهرمان', 'بخور', 'صندل'],
        ),
        matchPct: 94,
        priceRangeSar: '285',
      ),
      BottleDupeResult(
        perfume: Perfume(
          name: 'Bleu Imperial',
          brand: 'Atelier Sahab',
          rating: 4.3,
          accent: Color(0xFF5B7EC9),
          accords: ['حمضيات', 'زنجبيل', 'أرز'],
        ),
        matchPct: 88,
        priceRangeSar: '220',
      ),
      BottleDupeResult(
        perfume: Perfume(
          name: 'Royal Amber',
          brand: 'Nuun Parfums',
          rating: 4.1,
          accent: Color(0xFFD4832A),
          accords: ['عنبر', 'فانيلا', 'مسك'],
        ),
        matchPct: 82,
        priceRangeSar: '165',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BottleRevealScreen(
      reference: _reference,
      dupesFuture: _demoDupes(),
      referencePriceSar: 1180,
    );
  }
}
