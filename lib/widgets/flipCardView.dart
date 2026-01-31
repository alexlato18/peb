import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:peb/data/spanish_card.dart';
import 'package:peb/data/spanish_card_painter.dart';

class FlipCardView extends StatefulWidget {
  const FlipCardView({
    super.key,
    required this.card,
    required this.showBack,
    this.onFlipFinished,
    this.duration = const Duration(milliseconds: 520),
  });

  final SpanishCard? card;

  /// true = dorso, false = cara
  final bool showBack;

  final VoidCallback? onFlipFinished;
  final Duration duration;

  @override
  State<FlipCardView> createState() => _FlipCardViewState();
}

class _FlipCardViewState extends State<FlipCardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;

  bool _showingBack = true;

  @override
  void initState() {
    super.initState();
    _showingBack = widget.showBack;

    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        widget.onFlipFinished?.call();
      }
    });
  }

  @override
  void didUpdateWidget(covariant FlipCardView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si cambia showBack -> animamos un flip
    if (oldWidget.showBack != widget.showBack) {
      _startFlip(toBack: widget.showBack);
    } else {
      _showingBack = widget.showBack;
    }
  }

  void _startFlip({required bool toBack}) {
    // Queremos terminar mostrando toBack
    // Antes del flip mostramos el estado actual
    // Durante el flip, cuando pase por 0.5 cambiamos el contenido
    _ctrl.reset();
    _ctrl.forward();

    // El cambio visual lo hacemos en build según t<0.5
    // pero necesitamos saber el objetivo final
    _showingBack = toBack;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (_, __) {
        final v = _t.value; // 0..1
        final angle = v * math.pi; // 0..180°

        // Perspectiva (sin esto el flip se ve "plano")
        final m = Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateY(angle);

        // En la primera mitad mostramos "lo que estaba"
        // En la segunda mitad mostramos "lo que va a quedar"
        final isFirstHalf = v < 0.5;

        final showBackNow = isFirstHalf ? ! _showingBack : _showingBack;
        // OJO: aquí invertimos porque _showingBack representa el estado final

        Widget face = AspectRatio(
          aspectRatio: 3 / 4,
          child: CustomPaint(
            painter: SpanishCardPainter(
              card: showBackNow ? null : widget.card,
              theme: Theme.of(context),
            ),
          ),
        );

        // Cuando la carta está girada más de 90°, el contenido se ve al revés.
        // Solución: si estamos en la segunda mitad, giramos 180° extra el contenido.
        if (!isFirstHalf) {
          face = Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi),
            child: face,
          );
        }

        return Transform(
          alignment: Alignment.center,
          transform: m,
          child: face,
        );
      },
    );
  }
}
