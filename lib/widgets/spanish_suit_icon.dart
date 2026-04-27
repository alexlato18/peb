import 'package:flutter/material.dart';
import '../data/spanish_card.dart';

class SpanishSuitIcon extends StatelessWidget {
  const SpanishSuitIcon({
    super.key,
    required this.suit,
    this.size = 24,
  });

  final SpanishSuit suit;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SpanishSuitOnlyPainter(
          suit: suit,
          theme: Theme.of(context),
        ),
      ),
    );
  }
}

class _SpanishSuitOnlyPainter extends CustomPainter {
  _SpanishSuitOnlyPainter({
    required this.suit,
    required this.theme,
  });

  final SpanishSuit suit;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final color = _suitColor(suit);
    final center = Offset(size.width / 2, size.height / 2);
    final drawSize = size.shortestSide * 0.9;

    switch (suit) {
      case SpanishSuit.oros:
        _drawOros(canvas, center, drawSize, color);
        break;
      case SpanishSuit.copas:
        _drawCopas(canvas, center, drawSize, color);
        break;
      case SpanishSuit.espadas:
        _drawEspadas(canvas, center, drawSize, color);
        break;
      case SpanishSuit.bastos:
        _drawBastos(canvas, center, drawSize, color);
        break;
    }
  }

  void _drawOros(Canvas canvas, Offset c, double s, Color color) {
    final radius = s * 0.42;

    final basePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, radius, basePaint);

    final borderPaint = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.06;
    canvas.drawCircle(c, radius, borderPaint);

    final innerRingPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.05;
    canvas.drawCircle(c, radius * 0.65, innerRingPaint);

    final centerDotPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, radius * 0.12, centerDotPaint);
  }

  void _drawCopas(Canvas canvas, Offset c, double s, Color color) {
    final cup = Path()
      ..moveTo(c.dx - s * 0.45, c.dy - s * 0.25)
      ..quadraticBezierTo(c.dx - s * 0.50, c.dy + s * 0.15, c.dx, c.dy + s * 0.22)
      ..quadraticBezierTo(c.dx + s * 0.50, c.dy + s * 0.15, c.dx + s * 0.45, c.dy - s * 0.25)
      ..quadraticBezierTo(c.dx, c.dy - s * 0.55, c.dx - s * 0.45, c.dy - s * 0.25)
      ..close();

    final paint = Paint()..color = color;
    canvas.drawPath(cup, paint);

    final stem = Rect.fromCenter(
      center: c.translate(0, s * 0.34),
      width: s * 0.14,
      height: s * 0.25,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(stem, const Radius.circular(8)),
      paint,
    );

    final base = Rect.fromCenter(
      center: c.translate(0, s * 0.52),
      width: s * 0.52,
      height: s * 0.12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(base, const Radius.circular(10)),
      paint,
    );
  }

  void _drawEspadas(Canvas canvas, Offset c, double s, Color color) {
    final paint = Paint()..color = color;

    final blade = Path()
      ..moveTo(c.dx, c.dy - s * 0.58)
      ..lineTo(c.dx + s * 0.10, c.dy - s * 0.10)
      ..lineTo(c.dx, c.dy + s * 0.42)
      ..lineTo(c.dx - s * 0.10, c.dy - s * 0.10)
      ..close();
    canvas.drawPath(blade, paint);

    final guard = Rect.fromCenter(
      center: c.translate(0, s * 0.25),
      width: s * 0.55,
      height: s * 0.10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(guard, const Radius.circular(10)),
      paint,
    );

    final handle = Rect.fromCenter(
      center: c.translate(0, s * 0.38),
      width: s * 0.16,
      height: s * 0.30,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(handle, const Radius.circular(10)),
      paint,
    );

    canvas.drawCircle(c.translate(0, s * 0.56), s * 0.08, paint);
  }

  void _drawBastos(Canvas canvas, Offset c, double s, Color color) {
    final paint = Paint()..color = color;

    final body = Rect.fromCenter(
      center: c,
      width: s * 0.22,
      height: s * 0.78,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(18)),
      paint,
    );

    final ringPaint = Paint()..color = Colors.white.withOpacity(0.18);
    for (final t in [-0.22, 0.0, 0.22]) {
      final ring = Rect.fromCenter(
        center: c.translate(0, s * t),
        width: s * 0.28,
        height: s * 0.08,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(ring, const Radius.circular(12)),
        ringPaint,
      );
    }
  }

  Color _suitColor(SpanishSuit suit) {
    switch (suit) {
      case SpanishSuit.oros:
        return const Color.fromARGB(255, 226, 222, 3);
      case SpanishSuit.copas:
        return const Color(0xFFB0352F);
      case SpanishSuit.espadas:
        return const Color.fromARGB(255, 31, 32, 31);
      case SpanishSuit.bastos:
        return const Color.fromARGB(255, 2, 107, 7);
    }
  }

  @override
  bool shouldRepaint(covariant _SpanishSuitOnlyPainter oldDelegate) {
    return oldDelegate.suit != suit || oldDelegate.theme != theme;
  }
}