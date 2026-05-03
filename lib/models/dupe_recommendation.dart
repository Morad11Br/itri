import 'perfume.dart';

class DupeRecommendation {
  final Perfume perfume;
  final String reason;
  final int similarityPct;
  final String? priceRangeSar;

  const DupeRecommendation({
    required this.perfume,
    required this.reason,
    required this.similarityPct,
    this.priceRangeSar,
  });
}

class DupeFinderResult {
  final List<DupeRecommendation> dupes;
  final String? referencePriceRangeSar;

  const DupeFinderResult({required this.dupes, this.referencePriceRangeSar});
}
