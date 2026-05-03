import 'package:flutter/material.dart';

class BottleIcon extends StatelessWidget {
  final Color color;
  final double size;

  const BottleIcon({
    super.key,
    this.color = const Color(0xFFC9A227),
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 1.6),
      painter: _BottlePainter(color: color),
    );
  }
}

class _BottlePainter extends CustomPainter {
  final Color color;
  _BottlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final capPaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    // Neck cap
    final capRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.37, h * 0.02, w * 0.27, h * 0.08),
      const Radius.circular(2),
    );
    canvas.drawRRect(capRect, capPaint);

    // Collar
    final collarRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.3, h * 0.10, w * 0.4, h * 0.04),
      const Radius.circular(1),
    );
    canvas.drawRRect(
      collarRect,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill,
    );

    // Body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.17, h * 0.14, w * 0.67, h * 0.75),
      const Radius.circular(10),
    );
    canvas.drawRRect(bodyRect, fillPaint);
    canvas.drawRRect(bodyRect, strokePaint);

    // Shine stripe
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    final shineRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.18, w * 0.17, h * 0.42),
      const Radius.circular(8),
    );
    canvas.drawRRect(shineRect, shinePaint);

    // Bottle label "BAR"
    final tp = TextPainter(
      text: TextSpan(
        text: 'BAR',
        style: TextStyle(
          color: color.withValues(alpha: 0.5),
          fontSize: w * 0.22,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h * 0.52));
  }

  @override
  bool shouldRepaint(_BottlePainter old) => old.color != color;
}
