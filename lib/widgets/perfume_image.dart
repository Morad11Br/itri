import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'bottle_icon.dart';

/// Cached network image with automatic fallback chain:
///   primaryUrl → fallbackUrl → BottleIcon
///
/// Drop-in replacement for all Image.network calls in the app.
class PerfumeImage extends StatelessWidget {
  final String primaryUrl;
  final String? fallbackUrl;
  final Color fallbackColor;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double iconSize;
  /// When true, shows BottleIcon on all errors. When false, shows empty box.
  final bool showIconOnError;

  const PerfumeImage({
    super.key,
    required this.primaryUrl,
    this.fallbackUrl,
    this.fallbackColor = kGold,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.iconSize = 32,
    this.showIconOnError = true,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: primaryUrl,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholderFadeInDuration: Duration.zero,
      placeholder: (context, url) => const SizedBox.shrink(),
      errorWidget: (context, url, error) => _fallback(),
    );
  }

  Widget _fallback() {
    // Try the fallback URL before giving up
    if (fallbackUrl != null && fallbackUrl != primaryUrl) {
      return CachedNetworkImage(
        imageUrl: fallbackUrl!,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (context, url) => const SizedBox.shrink(),
        errorWidget: (context, url, error) => _icon(),
      );
    }
    return _icon();
  }

  Widget _icon() {
    if (!showIconOnError) return const SizedBox.shrink();
    return Center(child: BottleIcon(color: fallbackColor, size: iconSize));
  }
}
