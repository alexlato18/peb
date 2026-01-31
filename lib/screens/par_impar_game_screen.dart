import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:peb/data/spanish_card_painter.dart';
import '../data/spanish_card.dart';
import '../data/spanish_deck.dart';

enum GamePhase { phase1, phase2, phase3, phase4, win, lose }
enum RevealAnim { flip, slide }

class ParImparGameScreen extends StatefulWidget {
  const ParImparGameScreen({super.key});

  @override
  State<ParImparGameScreen> createState() => _ParImparGameScreenState();
}

class _ParImparGameScreenState extends State<ParImparGameScreen> {
  late SpanishDeck _deck;
  bool _isFirstDrawOfGame = true;
  GamePhase _phase = GamePhase.phase1;

  SpanishCard? _c1;
  SpanishCard? _c2;
  SpanishCard? _c3;
  SpanishCard? _c4;

  SpanishCard? _shownCard;

  // Anim state
  bool _showBack = true;               // solo afecta al flip
  RevealAnim _revealAnim = RevealAnim.flip;

  String _statusText = "Fase 1: Elige Par o Impar y roba una carta.";

  @override
  void initState() {
    super.initState();
    _deck = SpanishDeck.shuffled40();
  }

  void _setLose(String message) {
    setState(() {
      _phase = GamePhase.lose;
      _statusText = message;
    });
  }

  void _setWin(String message) {
    setState(() {
      _phase = GamePhase.win;
      _statusText = message;
    });
  }

  SpanishCard? _drawOrLose() {
    final card = _deck.draw();
    if (card == null) {
      _setLose("Derrota: no quedan cartas en la baraja.");
      return null;
    }
    return card;
  }

  Future<void> _revealCard(SpanishCard card) async {
  if (!mounted) return;

  if (_isFirstDrawOfGame) {
    // 1) Primero forzamos a que se pinte el DORSO (sin posibilidad de cara)
    setState(() {
      _shownCard = null;  // 👈 clave: evita que la cara pueda pintar 1 frame
      _showBack = true;
    });

    // Espera 1 frame real
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    // 2) Ahora ya podemos asignar la carta, seguimos mostrando dorso
    setState(() {
      _shownCard = card;
      _showBack = true;
    });

    await Future.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;

    // 3) Flip a cara
    setState(() {
      _showBack = false;
    });

    await Future.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;

    setState(() {
      _isFirstDrawOfGame = false;
    });
  } else {
    // Para el resto: slide/fade
    setState(() {
      _shownCard = card;
      _showBack = false;
    });
  }
}




  // ----------- FASE 1: PAR / IMPAR -----------
  Future<void> _playPhase1({required bool chooseEven}) async {
    final card = _drawOrLose();
    if (card == null) return;

    await _revealCard(card);

    final ok = (card.isEven == chooseEven);

    setState(() {
      _c1 = card;
      _c2 = null;
      _c3 = null;
      _c4 = null;

      if (ok) {
        _phase = GamePhase.phase2;
        _statusText = "✅ Acertaste. Fase 2: ¿Mayor o Menor que ${_c1!.valueLabel}?";
      } else {
        _phase = GamePhase.phase1;
        _statusText = "❌ Fallaste (salió ${card.toString()}). Sigues en Fase 1.";
      }
    });
  }

  // ----------- FASE 2: MAYOR / MENOR (vs carta 1) -----------
  Future<void> _playPhase2({required bool chooseHigher}) async {
    if (_c1 == null) {
      setState(() {
        _phase = GamePhase.phase1;
        _statusText = "Reinicio: vuelve a fase 1.";
      });
      return;
    }

    final card = _drawOrLose();
    if (card == null) return;

    await _revealCard(card);

    final r1 = _c1!.rank;
    final r2 = card.rank;

    // Igual a carta 1 = derrota (vuelve a fase 1)
    if (r2 == r1) {
      setState(() {
        _c2 = card;
        _phase = GamePhase.phase1;
        _statusText =
            "❌ Salió igual que la carta 1 (${card.toString()}). Vuelves a Fase 1.";
      });
      return;
    }

    final ok = chooseHigher ? (r2 > r1) : (r2 < r1);

    setState(() {
      _c2 = card;

      if (ok) {
        _phase = GamePhase.phase3;
        _statusText =
            "✅ Acertaste. Fase 3: ¿Entre o Fuera (comparado con ${_c1!.valueLabel} y ${_c2!.valueLabel})?";
      } else {
        _phase = GamePhase.phase1;
        _statusText = "❌ Fallaste (salió ${card.toString()}). Vuelves a Fase 1.";
      }
    });
  }

  // ----------- FASE 3: ENTRE / FUERA (vs carta 1 y 2) -----------
  Future<void> _playPhase3({required bool chooseBetween}) async {
    if (_c1 == null || _c2 == null) {
      setState(() {
        _phase = GamePhase.phase1;
        _statusText = "Reinicio: vuelve a fase 1.";
      });
      return;
    }

    final card = _drawOrLose();
    if (card == null) return;

    await _revealCard(card);

    final r1 = _c1!.rank;
    final r2 = _c2!.rank;
    final r3 = card.rank;

    // Si es igual a carta 1 o carta 2 = derrota y vuelve a fase 1
    if (r3 == r1 || r3 == r2) {
      setState(() {
        _c3 = card;
        _phase = GamePhase.phase1;
        _statusText =
            "❌ Salió igual que una carta anterior (${card.toString()}). Vuelves a Fase 1.";
      });
      return;
    }

    final low = (r1 < r2) ? r1 : r2;
    final high = (r1 > r2) ? r1 : r2;

    final isBetween = (r3 > low && r3 < high);
    final isOutside = !isBetween;

    final ok = chooseBetween ? isBetween : isOutside;

    setState(() {
      _c3 = card;

      if (ok) {
        _phase = GamePhase.phase4;
        _statusText = "✅ Acertaste. Fase 4: Adivina el palo de la siguiente carta.";
      } else {
        _phase = GamePhase.phase1;
        _statusText = "❌ Fallaste (salió ${card.toString()}). Vuelves a Fase 1.";
      }
    });
  }

  // ----------- FASE 4: ADIVINAR PALO -----------
  Future<void> _playPhase4(SpanishSuit chosenSuit) async {
    if (_c1 == null || _c2 == null || _c3 == null) {
      setState(() {
        _phase = GamePhase.phase1;
        _statusText = "Reinicio: vuelve a fase 1.";
      });
      return;
    }

    final card = _drawOrLose();
    if (card == null) return;

    await _revealCard(card);

    final ok = (card.suit == chosenSuit);

    setState(() {
      _c4 = card;

      if (ok) {
        _setWin("🎉 ¡Victoria! Adivinaste el palo: ${card.toString()}");
      } else {
        _phase = GamePhase.phase1;
        _statusText = "❌ Fallaste (salió ${card.toString()}). Vuelves a Fase 1.";
      }
    });
  }

  void _resetGame() {
  setState(() {
    _deck.reset();
    _phase = GamePhase.phase1;
    _c1 = null;
    _c2 = null;
    _c3 = null;
    _c4 = null;

    _shownCard = null;
    _showBack = true;

    _isFirstDrawOfGame = true; // 👈 importante
    _statusText = "Fase 1: Elige Par o Impar y roba una carta.";
  });
}


  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final remaining = _deck.remaining;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Par o Impar"),
        actions: [
          IconButton(
            tooltip: "Reiniciar",
            onPressed: _resetGame,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _phaseLabel(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _RemainingBadge(remaining: remaining),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
  child: Center(
    child: AspectRatio(
      aspectRatio: 3 / 4,
      child: (_shownCard == null)
          ? CustomPaint(
              painter: PEBCardBackPainter(theme: Theme.of(context)),
            )
          : (_isFirstDrawOfGame
              ? FlipCardView(
                  card: _shownCard,
                  showBack: _showBack,
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) {
                    final offsetAnim = Tween<Offset>(
                      begin: const Offset(0.18, 0),
                      end: Offset.zero,
                    ).animate(anim);

                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(position: offsetAnim, child: child),
                    );
                  },
                  child: SizedBox.expand(
                    key: ValueKey("${_shownCard!.suit.name}-${_shownCard!.value}"),
                    child: CustomPaint(
                      painter: SpanishCardPainter(
                        card: _shownCard,
                        theme: Theme.of(context),
                      ),
                    ),
                  ),
                )),
    ),
  ),
),



              const SizedBox(height: 12),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),

              _buildButtons(),
            ],
          ),
        ),
      ),
    );
  }

  String _phaseLabel() {
    switch (_phase) {
      case GamePhase.phase1:
        return "Fase 1 · Par o Impar";
      case GamePhase.phase2:
        return "Fase 2 · Mayor o Menor";
      case GamePhase.phase3:
        return "Fase 3 · Entre o Fuera";
      case GamePhase.phase4:
        return "Fase 4 · Adivina el Palo";
      case GamePhase.win:
        return "✅ Victoria";
      case GamePhase.lose:
        return "❌ Derrota";
    }
  }

  Widget _buildButtons() {
    if (_phase == GamePhase.win || _phase == GamePhase.lose) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _resetGame,
          child: const Text("Jugar otra vez"),
        ),
      );
    }

    switch (_phase) {
      case GamePhase.phase1:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _playPhase1(chooseEven: true),
                child: const Text("PAR"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _playPhase1(chooseEven: false),
                child: const Text("IMPAR"),
              ),
            ),
          ],
        );

      case GamePhase.phase2:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _playPhase2(chooseHigher: false),
                child: const Text("MENOR"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _playPhase2(chooseHigher: true),
                child: const Text("MAYOR"),
              ),
            ),
          ],
        );

      case GamePhase.phase3:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _playPhase3(chooseBetween: true),
                child: const Text("ENTRE"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _playPhase3(chooseBetween: false),
                child: const Text("FUERA"),
              ),
            ),
          ],
        );

      case GamePhase.phase4:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _playPhase4(SpanishSuit.oros),
                    child: const Text("OROS"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _playPhase4(SpanishSuit.copas),
                    child: const Text("COPAS"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _playPhase4(SpanishSuit.espadas),
                    child: const Text("ESPADAS"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _playPhase4(SpanishSuit.bastos),
                    child: const Text("BASTOS"),
                  ),
                ),
              ],
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// -------- UI --------

class _RemainingBadge extends StatelessWidget {
  const _RemainingBadge({required this.remaining});
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        "Quedan: $remaining",
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

/// Stage: si revealAnim == flip -> FlipCardView
/// si revealAnim == slide -> AnimatedSwitcher (slide+fade desde derecha)
class CardRevealStage extends StatelessWidget {
  const CardRevealStage({
    super.key,
    required this.card,
    required this.showBack,
    required this.revealAnim,
  });

  final SpanishCard? card;
  final bool showBack;
  final RevealAnim revealAnim;

  @override
  Widget build(BuildContext context) {
    // Tamaño consistente
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: revealAnim == RevealAnim.flip
          ? FlipCardView(card: card, showBack: showBack)
          : _SlideFadeCard(card: card),
    );
  }
}

class _SlideFadeCard extends StatelessWidget {
  const _SlideFadeCard({required this.card});

  final SpanishCard? card;

  @override
  Widget build(BuildContext context) {
    // key por carta para que AnimatedSwitcher detecte cambio
    final key = ValueKey(card == null ? "back" : "${card!.suit.name}-${card!.value}");

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        final offsetAnim = Tween<Offset>(
          begin: const Offset(0.18, 0), // entra desde la derecha
          end: Offset.zero,
        ).animate(anim);

        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: offsetAnim, child: child),
        );
      },
      child: CustomPaint(
        key: key,
        painter: card == null
            ? PEBCardBackPainter(theme: Theme.of(context))
            : SpanishCardPainter(card: card, theme: Theme.of(context)),
      ),
    );
  }
}

/// Flip (dorso -> cara) usado SOLO para la primera carta
class FlipCardView extends StatefulWidget {
  const FlipCardView({
    super.key,
    required this.card,
    required this.showBack,
    this.duration = const Duration(milliseconds: 520),
  });

  final SpanishCard? card;
  final bool showBack;
  final Duration duration;

  @override
  State<FlipCardView> createState() => _FlipCardViewState();
}

class _FlipCardViewState extends State<FlipCardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Guardamos transición real: de (from) -> (to)
  late bool _fromBack;
  late bool _toBack;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    // Estado inicial estable
    _fromBack = widget.showBack;
    _toBack = widget.showBack;
    _ctrl.value = 1.0; // completado (sin animación visible)
  }

  @override
  void didUpdateWidget(covariant FlipCardView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si cambia showBack, iniciamos flip guardando from/to
    if (oldWidget.showBack != widget.showBack) {
      _fromBack = oldWidget.showBack;
      _toBack = widget.showBack;

      _ctrl
        ..reset()
        ..forward();
    } else {
      // Si no hay cambio, mantenemos estable
      _fromBack = widget.showBack;
      _toBack = widget.showBack;
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        // 0..1
        final t = Curves.easeInOut.transform(_ctrl.value);

        // 0..pi
        final angle = t * math.pi;

        final isFirstHalf = angle < (math.pi / 2);

        // Lado que toca en esta mitad
        final showBackNow = isFirstHalf ? _fromBack : _toBack;

        // Perspectiva + rotación
        final m = Matrix4.identity()
          ..setEntry(3, 2, 0.0017)
          ..rotateY(angle);

        // Pintamos el lado que toca
        Widget face = CustomPaint(
          painter: showBackNow
              ? PEBCardBackPainter(theme: Theme.of(context))
              : SpanishCardPainter(card: widget.card, theme: Theme.of(context)),
        );

        // En la segunda mitad hay espejo: compensamos
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


/// Dorso negro con PEB y detalles dorados
class PEBCardBackPainter extends CustomPainter {
  PEBCardBackPainter({required this.theme});
  final ThemeData theme;

  static const _gold = Color(0xFFD4AF37);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.save();
    canvas.translate(0, 6);
    canvas.drawRRect(rrect, shadowPaint);
    canvas.restore();

    final bgPaint = Paint()..color = const Color(0xFF0B0B0E);
    canvas.drawRRect(rrect, bgPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = _gold.withOpacity(0.95);
    canvas.drawRRect(rrect.deflate(6), borderPaint);

    final innerBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _gold.withOpacity(0.55);
    canvas.drawRRect(rrect.deflate(14), innerBorderPaint);

    _drawPattern(canvas, size);

    final center = Offset(size.width / 2, size.height / 2);
    final medRadius = size.shortestSide * 0.22;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.02
      ..color = _gold.withOpacity(0.9);
    canvas.drawCircle(center, medRadius, ringPaint);

    final ringPaint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.01
      ..color = _gold.withOpacity(0.45);
    canvas.drawCircle(center, medRadius * 0.82, ringPaint2);

    final tp = TextPainter(
      text: TextSpan(
        text: "PEB",
        style: theme.textTheme.displaySmall?.copyWith(
          color: _gold.withOpacity(0.98),
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width * 0.8);

    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));

    _drawTopBottomDetails(canvas, size);
  }

  void _drawPattern(Canvas canvas, Size size) {
    final clip = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(18),
      ));
    canvas.save();
    canvas.clipPath(clip);

    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _gold.withOpacity(0.08);

    final step = size.shortestSide * 0.12;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        p,
      );
    }

    canvas.restore();
  }

  void _drawTopBottomDetails(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _gold.withOpacity(0.55);

    final yTop = h * 0.14;
    final yBot = h * 0.86;

    canvas.drawLine(Offset(w * 0.30, yTop), Offset(w * 0.70, yTop), paint);
    canvas.drawLine(Offset(w * 0.30, yBot), Offset(w * 0.70, yBot), paint);

    final dotPaint = Paint()..color = _gold.withOpacity(0.75);
    canvas.drawCircle(Offset(w * 0.28, yTop), 3.2, dotPaint);
    canvas.drawCircle(Offset(w * 0.72, yTop), 3.2, dotPaint);
    canvas.drawCircle(Offset(w * 0.28, yBot), 3.2, dotPaint);
    canvas.drawCircle(Offset(w * 0.72, yBot), 3.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant PEBCardBackPainter oldDelegate) {
    return oldDelegate.theme != theme;
  }
}
