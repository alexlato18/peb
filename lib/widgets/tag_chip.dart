import 'dart:math';
import 'package:flutter/material.dart';

import '../data/tag_style_repository.dart';
import '../data/secret_tags.dart';

class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    required this.style,
    this.onTap,
  });

  final String label;
  final TagStyle style;
  final VoidCallback? onTap;

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _neonGreen = Color(0xFF39FF14);

  @override
  Widget build(BuildContext context) {
    if (isAppleOffensiveTag(label)) {
      return _AppleSecretTagChip(
        label: displayTagLabel(label),
        onTap: onTap,
      );
    }

    if (isBetaTesterTag(label)) {
      return _BetaTesterSecretTagChip(
        label: displayTagLabel(label),
        onTap: onTap,
      );
    }
    if (isNerdSecretTag(label)) {
      return _NerdSecretTagChip(
        label: displayTagLabel(label),
        onTap: onTap,
      );
    }

    if (isAddictTag(label)) {
      return _AddictSecretTagChip(
        label: displayTagLabel(label),
        onTap: onTap,
      );
    }

    if (isExplorerTag(label)) {
      return _ExplorerSecretTagChip(
        label: displayTagLabel(label),
        onTap: onTap,
      );
    }

    if (isGhostTag(label)) {
      return _GhostSecretTagChip(
        label: displayTagLabel(label),
        onTap: onTap,
      );
    }

    final borderRadius = BorderRadius.circular(999);
    final textColor = style.holo ? _gold : style.text;

    if (!style.holo) {
      return InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: style.bg,
            borderRadius: borderRadius,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            displayTagLabel(label),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: borderRadius,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(child: _HoloBackground()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                displayTagLabel(label),
                style: const TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddictSecretTagChip extends StatefulWidget {
  const _AddictSecretTagChip({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  State<_AddictSecretTagChip> createState() => _AddictSecretTagChipState();
}

class _AddictSecretTagChipState extends State<_AddictSecretTagChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(999);

    return InkWell(
      borderRadius: borderRadius,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final smokeOffset = sin(t * 2 * pi) * 2;
          final drinkWave = 0.75 + 0.25 * sin(t * 2 * pi).abs();

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1010),
              borderRadius: borderRadius,
              border: Border.all(
                color: const Color(0xFFFFC46B).withOpacity(0.85),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF7A00).withOpacity(0.25),
                  blurRadius: 9,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: Offset(0, smokeOffset),
                  child: CustomPaint(
                    size: const Size(24, 18),
                    painter: _CigarettePainter(progress: t),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Color(0xFFFFC46B),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 7),
                Transform.scale(
                  scale: drinkWave,
                  child: CustomPaint(
                    size: const Size(19, 20),
                    painter: _DrinkPainter(progress: t),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
class _BetaTesterSecretTagChip extends StatefulWidget {
  const _BetaTesterSecretTagChip({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  State<_BetaTesterSecretTagChip> createState() =>
      _BetaTesterSecretTagChipState();
}

class _BetaTesterSecretTagChipState extends State<_BetaTesterSecretTagChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _glitchOffset(double t, double seed) {
    final v = sin((t * 32 + seed) * pi);
    if (v > 0.82) return 2.0;
    if (v < -0.82) return -2.0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(999);

    return InkWell(
      borderRadius: borderRadius,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final dx = _glitchOffset(t, 0);
          final redDx = _glitchOffset(t, 1.4);
          final blueDx = _glitchOffset(t, 2.7);
          final scanY = (t * 22) % 22;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: borderRadius,
              border: Border.all(
                color: Color.lerp(
                  const Color(0xFFFFD54F),
                  const Color(0xFFFF1744),
                  sin(t * 2 * pi).abs(),
                )!,
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD54F).withOpacity(0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.15),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BetaGlitchBackgroundPainter(
                      progress: t,
                      scanY: scanY,
                    ),
                  ),
                ),

                Transform.translate(
                  offset: Offset(redDx - 1.5, 0),
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: Color(0xFFFF1744),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),

                Transform.translate(
                  offset: Offset(blueDx + 1.5, 0),
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),

                Transform.translate(
                  offset: Offset(dx, 0),
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BetaGlitchBackgroundPainter extends CustomPainter {
  _BetaGlitchBackgroundPainter({
    required this.progress,
    required this.scanY,
  });

  final double progress;
  final double scanY;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final scanPaint = Paint()
      ..color = const Color(0xFFFFD54F).withOpacity(0.18)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(0, scanY),
      Offset(size.width, scanY),
      scanPaint,
    );

    final glitchPaint = Paint()
      ..color = const Color(0xFFFF1744).withOpacity(0.20)
      ..style = PaintingStyle.fill;

    if (sin(progress * 18 * pi) > 0.75) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * 0.15,
          size.height * 0.18,
          size.width * 0.40,
          2,
        ),
        glitchPaint,
      );
    }

    final cyanPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.18)
      ..style = PaintingStyle.fill;

    if (sin(progress * 25 * pi) < -0.78) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * 0.45,
          size.height * 0.68,
          size.width * 0.35,
          2,
        ),
        cyanPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BetaGlitchBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.scanY != scanY;
  }
}
class _CigarettePainter extends CustomPainter {
  _CigarettePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final filterPaint = Paint()
      ..color = const Color(0xFFE5A85C)
      ..style = PaintingStyle.fill;

    final emberPaint = Paint()
      ..color = Color.lerp(
        Colors.red,
        Colors.orange,
        sin(progress * 2 * pi).abs(),
      )!
      ..style = PaintingStyle.fill;

    final smokePaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final y = size.height * 0.62;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, y, size.width * 0.68, 5),
      const Radius.circular(6),
    );

    canvas.drawRRect(rect, bodyPaint);

    final filterRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.55, y, size.width * 0.20, 5),
      const Radius.circular(6),
    );
    canvas.drawRRect(filterRect, filterPaint);

    canvas.drawCircle(
      Offset(2, y + 2.5),
      2.5,
      emberPaint,
    );

    final path = Path()
      ..moveTo(size.width * 0.08, y - 2)
      ..cubicTo(
        size.width * 0.00,
        y - 8 - progress * 2,
        size.width * 0.20,
        y - 10,
        size.width * 0.12,
        y - 15,
      );

    canvas.drawPath(path, smokePaint);
  }

  @override
  bool shouldRepaint(covariant _CigarettePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _DrinkPainter extends CustomPainter {
  _DrinkPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final glassPaint = Paint()
      ..color = Colors.white.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final liquidPaint = Paint()
      ..color = Color.lerp(
        const Color(0xFFFFA726),
        const Color(0xFFFFD54F),
        sin(progress * 2 * pi).abs(),
      )!
      ..style = PaintingStyle.fill;

    final strawPaint = Paint()
      ..color = const Color(0xFFFFC46B)
      ..strokeWidth = 1.4;

    final cup = Path()
      ..moveTo(size.width * 0.25, size.height * 0.18)
      ..lineTo(size.width * 0.75, size.height * 0.18)
      ..lineTo(size.width * 0.62, size.height * 0.92)
      ..lineTo(size.width * 0.38, size.height * 0.92)
      ..close();

    final liquid = Path()
      ..moveTo(size.width * 0.31, size.height * 0.50)
      ..lineTo(size.width * 0.69, size.height * 0.50)
      ..lineTo(size.width * 0.60, size.height * 0.86)
      ..lineTo(size.width * 0.40, size.height * 0.86)
      ..close();

    canvas.drawPath(liquid, liquidPaint);
    canvas.drawPath(cup, glassPaint);

    canvas.drawLine(
      Offset(size.width * 0.55, 0),
      Offset(size.width * 0.45, size.height * 0.45),
      strawPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DrinkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ExplorerSecretTagChip extends StatefulWidget {
  const _ExplorerSecretTagChip({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  State<_ExplorerSecretTagChip> createState() => _ExplorerSecretTagChipState();
}

class _ExplorerSecretTagChipState extends State<_ExplorerSecretTagChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(999);

    return InkWell(
      borderRadius: borderRadius,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = Curves.easeInOut.transform(_c.value);
          final lidOpen = t;
          final textLift = -8.0 * t;
          final textOpacity = 0.45 + 0.55 * t;
          final glow = 0.25 + 0.55 * t;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1805),
              borderRadius: borderRadius,
              border: Border.all(
                color: const Color(0xFFFFD36E),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD36E).withOpacity(glow),
                  blurRadius: 10 + 10 * glow,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: SizedBox(
              height: 26,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    child: CustomPaint(
                      size: const Size(34, 28),
                      painter: _ChestPainter(progress: lidOpen),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 34),
                    child: Transform.translate(
                      offset: Offset(0, textLift),
                      child: Opacity(
                        opacity: textOpacity,
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            color: const Color(0xFFFFE49A),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                            shadows: [
                              Shadow(
                                color: const Color(0xFFFFD36E)
                                    .withOpacity(0.85 * glow),
                                blurRadius: 8 + 10 * glow,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 22,
                    top: 5 - 4 * t,
                    child: Opacity(
                      opacity: glow,
                      child: Container(
                        width: 30 + 12 * t,
                        height: 14 + 8 * t,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF2A6).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFF2A6)
                                  .withOpacity(0.45 * glow),
                              blurRadius: 16,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChestPainter extends CustomPainter {
  _ChestPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final wood = Paint()
      ..color = const Color(0xFF8B4A16)
      ..style = PaintingStyle.fill;

    final darkWood = Paint()
      ..color = const Color(0xFF4A2608)
      ..style = PaintingStyle.fill;

    final gold = Paint()
      ..color = const Color(0xFFFFD36E)
      ..style = PaintingStyle.fill;

    final line = Paint()
      ..color = const Color(0xFF2A1605)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final glow = Paint()
      ..color = const Color(0xFFFFF2A6).withOpacity(0.20 + 0.35 * progress)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.58, size.height * 0.52),
        width: size.width * (0.75 + 0.25 * progress),
        height: size.height * (0.38 + 0.28 * progress),
      ),
      glow,
    );

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.10,
        size.height * 0.47,
        size.width * 0.78,
        size.height * 0.38,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(body, wood);
    canvas.drawRRect(body, line);

    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.10,
        size.height * 0.61,
        size.width * 0.78,
        size.height * 0.07,
      ),
      darkWood,
    );

    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.46,
        size.height * 0.48,
        size.width * 0.08,
        size.height * 0.37,
      ),
      gold,
    );

    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.64),
      2.3,
      gold,
    );

    canvas.save();

    final hinge = Offset(size.width * 0.12, size.height * 0.48);
    canvas.translate(hinge.dx, hinge.dy);
    canvas.rotate(-0.75 * progress);
    canvas.translate(-hinge.dx, -hinge.dy);

    final lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.10,
        size.height * 0.28,
        size.width * 0.78,
        size.height * 0.24,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(lid, darkWood);
    canvas.drawRRect(lid, line);

    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.10,
        size.height * 0.38,
        size.width * 0.78,
        size.height * 0.05,
      ),
      gold,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChestPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
class _GhostSecretTagChip extends StatefulWidget {
  const _GhostSecretTagChip({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  State<_GhostSecretTagChip> createState() => _GhostSecretTagChipState();
}

class _GhostSecretTagChipState extends State<_GhostSecretTagChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(999);

    return InkWell(
      borderRadius: borderRadius,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final floatY = sin(t * 2 * pi) * 2.2;
          final opacity = 0.62 + 0.28 * sin(t * 2 * pi).abs();
          final glow = 0.20 + 0.35 * sin(t * 2 * pi).abs();

          return Opacity(
            opacity: opacity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0E16).withOpacity(0.76),
                borderRadius: borderRadius,
                border: Border.all(
                  color: Colors.white.withOpacity(0.38 + glow),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB8D8FF).withOpacity(glow),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Transform.translate(
                offset: Offset(0, floatY),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size(18, 18),
                      painter: _GhostIconPainter(
                        progress: t,
                        color: Colors.white.withOpacity(0.88),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.94),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        shadows: [
                          Shadow(
                            color: const Color(0xFFB8D8FF).withOpacity(0.8),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GhostIconPainter extends CustomPainter {
  _GhostIconPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final eyePaint = Paint()
      ..color = const Color(0xFF0B0E16)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.18, h * 0.92)
      ..lineTo(w * 0.18, h * 0.42)
      ..cubicTo(w * 0.18, h * 0.12, w * 0.82, h * 0.12, w * 0.82, h * 0.42)
      ..lineTo(w * 0.82, h * 0.92);

    final wave = sin(progress * 2 * pi);
    path
      ..quadraticBezierTo(w * 0.70, h * (0.78 + 0.04 * wave), w * 0.60, h * 0.92)
      ..quadraticBezierTo(w * 0.50, h * (0.78 - 0.04 * wave), w * 0.40, h * 0.92)
      ..quadraticBezierTo(w * 0.30, h * (0.78 + 0.04 * wave), w * 0.18, h * 0.92)
      ..close();

    canvas.drawPath(path, bodyPaint);

    canvas.drawCircle(Offset(w * 0.40, h * 0.43), 1.5, eyePaint);
    canvas.drawCircle(Offset(w * 0.60, h * 0.43), 1.5, eyePaint);
  }

  @override
  bool shouldRepaint(covariant _GhostIconPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
class _NerdSecretTagChip extends StatefulWidget {
  const _NerdSecretTagChip({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  State<_NerdSecretTagChip> createState() => _NerdSecretTagChipState();
}

class _NerdSecretTagChipState extends State<_NerdSecretTagChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(999);

    return InkWell(
      borderRadius: borderRadius,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final glow = 0.35 + 0.45 * sin(t * 2 * pi).abs();

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: borderRadius,
              border: Border.all(
                color: TagChip._neonGreen.withOpacity(0.8),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: TagChip._neonGreen.withOpacity(glow),
                  blurRadius: 10 + 6 * glow,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CodeLinesPainter(progress: t),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '<',
                      style: TextStyle(
                        color: TagChip._neonGreen.withOpacity(0.8),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: TagChip._neonGreen,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '/>',
                      style: TextStyle(
                        color: TagChip._neonGreen.withOpacity(0.8),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CodeLinesPainter extends CustomPainter {
  _CodeLinesPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TagChip._neonGreen.withOpacity(0.13)
      ..strokeWidth = 1;

    const gap = 8.0;
    final offset = progress * gap;

    for (double y = -gap; y < size.height + gap; y += gap) {
      canvas.drawLine(
        Offset(0, y + offset),
        Offset(size.width, y + offset),
        paint,
      );
    }

    final cursorPaint = Paint()
      ..color = TagChip._neonGreen.withOpacity(0.6)
      ..strokeWidth = 2;

    final cursorX = (progress * size.width * 1.4) % size.width;

    canvas.drawLine(
      Offset(cursorX, 2),
      Offset(cursorX, size.height - 2),
      cursorPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CodeLinesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _AppleSecretTagChip extends StatefulWidget {
  const _AppleSecretTagChip({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  State<_AppleSecretTagChip> createState() => _AppleSecretTagChipState();
}

class _AppleSecretTagChipState extends State<_AppleSecretTagChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _rotation(double t) {
    final speed = 0.45 + 0.55 * sin(t * 2 * pi);
    return t * 2 * pi * speed;
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(999);

    return InkWell(
      borderRadius: borderRadius,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final wave = sin(t * 2 * pi);
          final scale = 0.86 + 0.14 * wave.abs();
          final opacity = 0.45 + 0.55 * wave.abs();

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: borderRadius,
              border: Border.all(
                color: const Color(0xFF0057B8),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0057B8).withOpacity(0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: _rotation(t),
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: CustomPaint(
                        size: const Size(18, 18),
                        painter: const _SixPointStarPainter(
                          color: Color(0xFF0057B8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Color(0xFF0057B8),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SixPointStarPainter extends CustomPainter {
  const _SixPointStarPainter({
    required this.color,
  });

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final p1 = Path();
    for (int i = 0; i < 3; i++) {
      final angle = -pi / 2 + i * 2 * pi / 3;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);

      if (i == 0) {
        p1.moveTo(x, y);
      } else {
        p1.lineTo(x, y);
      }
    }
    p1.close();

    final p2 = Path();
    for (int i = 0; i < 3; i++) {
      final angle = pi / 2 + i * 2 * pi / 3;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);

      if (i == 0) {
        p2.moveTo(x, y);
      } else {
        p2.lineTo(x, y);
      }
    }
    p2.close();

    canvas.drawPath(p1, paint);
    canvas.drawPath(p2, paint);
  }

  @override
  bool shouldRepaint(covariant _SixPointStarPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _HoloBackground extends StatefulWidget {
  const _HoloBackground();

  @override
  State<_HoloBackground> createState() => _HoloBackgroundState();
}

class _HoloBackgroundState extends State<_HoloBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final a = 2 * pi * t;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(cos(a), sin(a)),
              end: Alignment(-cos(a), -sin(a)),
              colors: const [
                Color(0xFF00E5FF),
                Color(0xFFFF00E5),
                Color(0xFF00FF85),
                Color(0xFFFFE600),
                Color(0xFF00E5FF),
              ],
            ),
          ),
        );
      },
    );
  }
}