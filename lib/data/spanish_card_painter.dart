import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'spanish_card.dart';

class SpanishCardPainter extends CustomPainter {
  SpanishCardPainter({required this.card, required this.theme});

  final SpanishCard? card;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );

    // Fondo + sombra
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.save();
    canvas.translate(0, 6);
    canvas.drawRRect(r, shadowPaint);
    canvas.restore();

    // Carta base
    final bgPaint = Paint()..color = theme.colorScheme.surface;
    canvas.drawRRect(r, bgPaint);

    // Borde
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = theme.colorScheme.outline.withOpacity(0.7);
    canvas.drawRRect(r, borderPaint);

    // Si no hay carta aún, placeholder
    if (card == null) {
      _drawPlaceholder(canvas, size);
      return;
    }

    final suitColor = _suitColor(card!.suit);
    final padding = size.shortestSide * 0.08;

    // Textos
    final valueText = _valueShort(card!); // "1", "7", "S", "C", "R"
    final suitText = card!.suitLabel;

    // esquina superior izquierda (valor)
    _drawCornerText(
      canvas,
      text: valueText,
      at: Offset(padding, padding * 0.65),
      color: suitColor,
      fontSize: size.shortestSide * 0.12,
      bold: true,
    );

    // esquina superior derecha (palo mini)
    _drawSuitIcon(
      canvas,
      suit: card!.suit,
      center: Offset(size.width - padding * 1.1, padding * 1.25),
      size: size.shortestSide * 0.14,
      color: suitColor,
    );

    // esquina inferior derecha (valor)
    _drawCornerText(
      canvas,
      text: valueText,
      at: Offset(size.width - padding, size.height - padding * 0.55),
      color: suitColor,
      fontSize: size.shortestSide * 0.12,
      bold: true,
      alignRight: true,
      alignBottom: true,
    );

    // esquina inferior izquierda (palo mini)
    _drawSuitIcon(
      canvas,
      suit: card!.suit,
      center: Offset(padding * 1.1, size.height - padding * 1.25),
      size: size.shortestSide * 0.14,
      color: suitColor,
    );

    // Centro: palo grande + etiqueta
    final center = Offset(size.width / 2, size.height / 2);

    _drawSuitIcon(
      canvas,
      suit: card!.suit,
      center: center.translate(0, -size.height * 0.06),
      size: size.shortestSide * 0.44,
      color: suitColor.withOpacity(0.92),
    );

    final label = "$suitText • ${card!.valueLabel}";
    _drawCenterLabel(canvas, size, label, suitColor);
  }

  void _drawPlaceholder(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final iconPaint = Paint()
      ..color = theme.colorScheme.primary.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    // icono simple tipo "carta"
    final w = size.width * 0.42;
    final h = size.height * 0.52;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: w, height: h),
      const Radius.circular(14),
    );
    canvas.drawRRect(rect, iconPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: "Sin carta",
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.65),
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width * 0.8);

    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy + h * 0.33));
  }

  void _drawCenterLabel(Canvas canvas, Size size, String label, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.85),
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width * 0.86);

    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.78));
  }

  void _drawCornerText(
    Canvas canvas, {
    required String text,
    required Offset at,
    required Color color,
    required double fontSize,
    bool bold = false,
    bool alignRight = false,
    bool alignBottom = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: theme.textTheme.titleLarge?.copyWith(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final dx = alignRight ? at.dx - tp.width : at.dx;
    final dy = alignBottom ? at.dy - tp.height : at.dy;

    tp.paint(canvas, Offset(dx, dy));
  }

  // --- Iconos de palo (estilizados) ---

  void _drawSuitIcon(
    Canvas canvas, {
    required SpanishSuit suit,
    required Offset center,
    required double size,
    required Color color,
  }) {
    switch (suit) {
      case SpanishSuit.oros:
        _drawOros(canvas, center, size, color);
        break;
      case SpanishSuit.copas:
        _drawCopas(canvas, center, size, color);
        break;
      case SpanishSuit.espadas:
        _drawEspadas(canvas, center, size, color);
        break;
      case SpanishSuit.bastos:
        _drawBastos(canvas, center, size, color);
        break;
    }
  }

  void _drawOros(Canvas canvas, Offset c, double s, Color color) {
  // Radio principal
  final radius = s * 0.42;

  // Moneda base
  final basePaint = Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  canvas.drawCircle(c, radius, basePaint);

  // Borde exterior
  final borderPaint = Paint()
    ..color = Colors.black.withOpacity(0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * 0.06;

  canvas.drawCircle(c, radius, borderPaint);

  // Aro interior decorativo
  final innerRingPaint = Paint()
    ..color = Colors.white.withOpacity(0.18)
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * 0.05;

  canvas.drawCircle(c, radius * 0.65, innerRingPaint);

  // Punto central (detalle clásico)
  final centerDotPaint = Paint()
    ..color = Colors.white.withOpacity(0.25)
    ..style = PaintingStyle.fill;

  canvas.drawCircle(c, radius * 0.12, centerDotPaint);
}

  void _drawCopas(Canvas canvas, Offset c, double s, Color color) {
    // copa estilizada (taza + base)
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
    // espada minimalista: hoja + guarda + empuñadura
    final paint = Paint()..color = color;

    // hoja
    final blade = Path()
      ..moveTo(c.dx, c.dy - s * 0.58)
      ..lineTo(c.dx + s * 0.10, c.dy - s * 0.10)
      ..lineTo(c.dx, c.dy + s * 0.42)
      ..lineTo(c.dx - s * 0.10, c.dy - s * 0.10)
      ..close();
    canvas.drawPath(blade, paint);

    // guarda
    final guard = Rect.fromCenter(
      center: c.translate(0, s * 0.25),
      width: s * 0.55,
      height: s * 0.10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(guard, const Radius.circular(10)),
      paint,
    );

    // empuñadura
    final handle = Rect.fromCenter(
      center: c.translate(0, s * 0.38),
      width: s * 0.16,
      height: s * 0.30,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(handle, const Radius.circular(10)),
      paint,
    );

    // pomo
    canvas.drawCircle(c.translate(0, s * 0.56), s * 0.08, paint);
  }

  void _drawBastos(Canvas canvas, Offset c, double s, Color color) {
    // bastón/maza estilizada
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

    // anillos decorativos
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
    // Baraja española suele ir en rojo/negro; aquí hacemos algo simple:
    // copas + oros -> rojizo, espadas + bastos -> oscuro.
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

  String _valueShort(SpanishCard c) {
    switch (c.value) {
      case 10:
        return "S"; // Sota
      case 11:
        return "C"; // Caballo
      case 12:
        return "R"; // Rey
      default:
        return c.value.toString();
    }
  }

  @override
  bool shouldRepaint(covariant SpanishCardPainter oldDelegate) {
    return oldDelegate.card != card || oldDelegate.theme != theme;
  }
}
