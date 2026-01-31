import 'dart:math';
import 'package:flutter/material.dart';
import '../data/tag_style_repository.dart';

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

  @override
  Widget build(BuildContext context) {
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
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    // Holo: el tamaño lo define el texto con padding (child no posicionado),
    // y el fondo lo rellenamos con Positioned.fill.
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
                label,
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
