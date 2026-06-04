import 'dart:math';
import 'package:flutter/material.dart';

import '../models/fish_definitions.dart';
import '../models/fish_models.dart';

class FishSprite extends StatefulWidget {
  const FishSprite({
    super.key,
    required this.fish,
    this.showEffects = true,
  });

  final FishInstance fish;
  final bool showEffects;

  @override
  State<FishSprite> createState() => _FishSpriteState();
}

class _FishSpriteState extends State<FishSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _hasEffects => widget.fish.shiny || widget.fish.modifiers.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    if (_hasEffects) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant FishSprite oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_hasEffects && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!_hasEffects && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _has(String mod) => widget.fish.modifiers.contains(mod);
  Widget _buildFishImage(String assetPath) {
    Widget image;

    if (widget.fish.customImageUrl != null &&
        widget.fish.customImageUrl!.isNotEmpty) {
      image = Image.network(
        widget.fish.customImageUrl!,
        fit: BoxFit.contain,
      );
    } else {
      image = Image.asset(
        assetPath,
        fit: BoxFit.contain,
      );
    }

    if (!widget.fish.shiny) {
      return image;
    }

    final hue = widget.fish.shinyHue ?? 45;

    final shinyColor = HSVColor.fromAHSV(
      1,
      hue,
      0.95,
      1,
    ).toColor();

    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        shinyColor.withOpacity(0.72),
        BlendMode.modulate,
      ),
      child: image,
    );
  }
  @override
  Widget build(BuildContext context) {
    final definition = getFishDefinitionById(widget.fish.fishId);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final p = _controller.value;

        return CustomPaint(
          painter: widget.showEffects
              ? _FishBackPainter(
                  progress: p,
                  shiny: widget.fish.shiny,
                  fire: _has('fuego'),
                  ice: _has('hielo'),
                  rainbow: _has('arcoiris'),
                  electric: _has('electrico'),
                  toxic: _has('toxico'),
                  ghost: _has('fantasma'),
                )
              : null,
          foregroundPainter: widget.showEffects
              ? _FishFrontPainter(
                  progress: p,
                  shiny: widget.fish.shiny,
                  fire: _has('fuego'),
                  ice: _has('hielo'),
                  rainbow: _has('arcoiris'),
                  electric: _has('electrico'),
                  toxic: _has('toxico'),
                  ghost: _has('fantasma'),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Opacity(
              opacity: _has('fantasma') ? 0.58 : 1,
              child: _buildFishImage(definition.assetPath),
            ),
          ),
        );
      },
    );
  }
}

class _FishBackPainter extends CustomPainter {
  const _FishBackPainter({
    required this.progress,
    required this.shiny,
    required this.fire,
    required this.ice,
    required this.rainbow,
    required this.electric,
    required this.toxic,
    required this.ghost,
  });

  final double progress;
  final bool shiny;
  final bool fire;
  final bool ice;
  final bool rainbow;
  final bool electric;
  final bool toxic;
  final bool ghost;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    if (rainbow) {
      _paintRainbowTrail(canvas, size);
    }

    if (fire) {
      _paintFireAura(canvas, size);
    }

    if (ice) {
      _paintIceAura(canvas, size);
    }

    if (electric) {
      _paintElectricAura(canvas, size);
    }

    if (toxic) {
      _paintToxicAura(canvas, size);
    }

    if (ghost) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: size.width * 1.10,
          height: size.height * 0.80,
        ),
        paint,
      );
    }

    if (shiny) {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withOpacity(0.45),
            Colors.amberAccent.withOpacity(0.28),
            Colors.pinkAccent.withOpacity(0.10),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: center,
            radius: size.width * 0.78,
          ),
        );

      canvas.drawCircle(center, size.width * 0.78, glow);
    }
  }

  void _paintRainbowTrail(Canvas canvas, Size size) {
    final colors = [
      Colors.redAccent,
      Colors.orangeAccent,
      Colors.yellowAccent,
      Colors.greenAccent,
      Colors.cyanAccent,
      Colors.blueAccent,
      Colors.purpleAccent,
    ];

    for (var i = 0; i < colors.length; i++) {
      final y = size.height * (0.26 + i * 0.055);
      final wave = sin(progress * pi * 2 + i * 0.8) * 9;

      final paint = Paint()
        ..color = colors[i].withOpacity(0.42)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

      final path = Path()
        ..moveTo(size.width * 0.02, y + wave)
        ..cubicTo(
          size.width * 0.13,
          y - 16,
          size.width * 0.27,
          y + 16,
          size.width * 0.48,
          y + wave,
        );

      canvas.drawPath(path, paint);
    }
  }

  void _paintFireAura(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.deepOrangeAccent.withOpacity(0.38),
          Colors.orange.withOpacity(0.20),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: size.width * 0.70),
      );

    canvas.drawCircle(center, size.width * 0.70, paint);
  }

  void _paintIceAura(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.lightBlueAccent.withOpacity(0.30),
          Colors.cyanAccent.withOpacity(0.12),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: size.width * 0.68),
      );

    canvas.drawCircle(center, size.width * 0.68, paint);
  }

  void _paintElectricAura(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.yellowAccent.withOpacity(0.34),
          Colors.blueAccent.withOpacity(0.10),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: size.width * 0.70),
      );

    canvas.drawCircle(center, size.width * 0.70, paint);
  }

  void _paintToxicAura(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.greenAccent.withOpacity(0.36),
          Colors.limeAccent.withOpacity(0.15),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: size.width * 0.68),
      );

    canvas.drawCircle(center, size.width * 0.68, paint);
  }

  @override
  bool shouldRepaint(covariant _FishBackPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.shiny != shiny ||
        oldDelegate.fire != fire ||
        oldDelegate.ice != ice ||
        oldDelegate.rainbow != rainbow ||
        oldDelegate.electric != electric ||
        oldDelegate.toxic != toxic ||
        oldDelegate.ghost != ghost;
  }
}

class _FishFrontPainter extends CustomPainter {
  const _FishFrontPainter({
    required this.progress,
    required this.shiny,
    required this.fire,
    required this.ice,
    required this.rainbow,
    required this.electric,
    required this.toxic,
    required this.ghost,
  });

  final double progress;
  final bool shiny;
  final bool fire;
  final bool ice;
  final bool rainbow;
  final bool electric;
  final bool toxic;
  final bool ghost;

  @override
  void paint(Canvas canvas, Size size) {
    if (fire) _paintFlames(canvas, size);
    if (ice) _paintSnow(canvas, size);
    if (electric) _paintLightning(canvas, size);
    if (toxic) _paintToxicBubbles(canvas, size);
    if (ghost) _paintGhostWisps(canvas, size);
    if (shiny) _paintSparkles(canvas, size);
  }

  void _paintFlames(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);

    for (var i = 0; i < 12; i++) {
      final t = (progress + i * 0.083) % 1;
      final x = size.width * (0.10 + (i % 6) * 0.155);
      final y = size.height * (0.88 - t * 0.72);
      final flameHeight = 12 * (1 - t) + 5;
      final flameWidth = 5 * (1 - t) + 3;

      paint.color = Color.lerp(
        Colors.deepOrangeAccent,
        Colors.yellowAccent,
        t,
      )!
          .withOpacity((1 - t).clamp(0.0, 1.0));

      final path = Path()
        ..moveTo(x, y - flameHeight)
        ..quadraticBezierTo(
          x + flameWidth,
          y - flameHeight * 0.35,
          x,
          y,
        )
        ..quadraticBezierTo(
          x - flameWidth,
          y - flameHeight * 0.35,
          x,
          y - flameHeight,
        );

      canvas.drawPath(path, paint);
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.lightBlueAccent.withOpacity(0.90)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 9; i++) {
      final t = (progress + i * 0.13) % 1;
      final x = size.width * (0.12 + (i % 5) * 0.19);
      final y = size.height * (0.08 + t * 0.78);
      final r = 4.5 + sin(progress * pi * 2 + i) * 1.4;

      for (var a = 0; a < 3; a++) {
        final angle = a * pi / 3;
        canvas.drawLine(
          Offset(x - cos(angle) * r, y - sin(angle) * r),
          Offset(x + cos(angle) * r, y + sin(angle) * r),
          paint,
        );
      }
    }
  }

void _paintLightning(Canvas canvas, Size size) {
  final sparkPaint = Paint()
    ..color = Colors.yellowAccent.withOpacity(0.75)
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

  final corePaint = Paint()
    ..color = Colors.white.withOpacity(0.95)
    ..strokeWidth = 0.9
    ..strokeCap = StrokeCap.round;

  for (var i = 0; i < 10; i++) {
    final t = (progress + i * 0.137) % 1;

    final x = size.width * (0.16 + (i % 5) * 0.17);
    final y = size.height * (0.18 + ((i * 0.23 + progress) % 0.65));

    final length = 5 + sin(progress * pi * 2 + i) * 2;

    final dx = sin(progress * pi * 6 + i) * 3;
    final dy = cos(progress * pi * 5 + i) * 3;

    final opacity = (1 - t).clamp(0.25, 0.85);

    sparkPaint.color = Colors.yellowAccent.withOpacity(opacity);
    corePaint.color = Colors.white.withOpacity(opacity);

    final start = Offset(x, y);
    final mid = Offset(x + dx, y + length);
    final end = Offset(x - dx, y + length + dy);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(mid.dx, mid.dy)
      ..lineTo(end.dx, end.dy);

    canvas.drawPath(path, sparkPaint);
    canvas.drawPath(path, corePaint);
  }
}

  void _paintToxicBubbles(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.58)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

    for (var i = 0; i < 9; i++) {
      final t = (progress + i * 0.11) % 1;
      final wave = sin(progress * pi * 2 + i) * 5;
      final x = size.width * (0.16 + (i % 4) * 0.20) + wave;
      final y = size.height * (0.83 - t * 0.66);
      final radius = 2.5 + (1 - t) * 4.5;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _paintGhostWisps(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (var i = 0; i < 4; i++) {
      final t = (progress + i * 0.25) % 1;
      final y = size.height * (0.25 + i * 0.14);
      final x = size.width * (0.10 + t * 0.60);

      final path = Path()
        ..moveTo(x, y)
        ..cubicTo(
          x + 15,
          y - 18,
          x + 28,
          y + 18,
          x + 42,
          y,
        );

      canvas.drawPath(path, paint);
    }
  }

  void _paintSparkles(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.90)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final center = size.center(Offset.zero);

    for (var i = 0; i < 5; i++) {
      final angle = progress * pi * 2 + i * 1.25;
      final pulse = 0.65 + sin(progress * pi * 2 + i) * 0.35;
      final pos = Offset(
        center.dx + cos(angle) * size.width * 0.40,
        center.dy + sin(angle) * size.height * 0.32,
      );

      final r = 4 + 3 * pulse;

      canvas.drawLine(Offset(pos.dx - r, pos.dy), Offset(pos.dx + r, pos.dy), paint);
      canvas.drawLine(Offset(pos.dx, pos.dy - r), Offset(pos.dx, pos.dy + r), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FishFrontPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.shiny != shiny ||
        oldDelegate.fire != fire ||
        oldDelegate.ice != ice ||
        oldDelegate.rainbow != rainbow ||
        oldDelegate.electric != electric ||
        oldDelegate.toxic != toxic ||
        oldDelegate.ghost != ghost;
  }
}