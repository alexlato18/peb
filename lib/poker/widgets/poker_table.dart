import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/poker_state.dart';
import 'poker_card.dart';

class PokerTable extends StatelessWidget {
  const PokerTable({
    super.key,
    required this.state,
    required this.myProfileId,
  });

  final PokerState state;
  final String myProfileId;

  @override
  Widget build(BuildContext context) {
    final players = state.players;

    if (players.isEmpty) {
      return const Center(child: Text("Esperando jugadores…"));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        final center = Offset(width / 2, height * 0.52);

        final ellipseRx = width * 0.36;
        final ellipseRy = height * 0.30;

        final seats = players.length.clamp(2, 9);

        final seatWidgets = List<Widget>.generate(seats, (i) {
          final p = players[i % players.length];
          final angle = (2 * math.pi * i / seats) - math.pi / 2;

          final dx = center.dx + math.cos(angle) * ellipseRx;
          final dy = center.dy + math.sin(angle) * ellipseRy;

          return Positioned(
            left: dx - 50,
            top: dy - 30,
            width: 100,
            child: _Seat(
              p: p,
              isMe: p.profileId == myProfileId,
              isTurn: state.turnProfileId == p.profileId,
              isDealer: i == state.dealerIndex,
              waiting: state.phase == PokerPhase.waiting,
            ),
          );
        });

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: width * 0.72,
                  height: height * 0.42,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(200),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.24),
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 16,
                right: 16,
                top: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _InfoBadge(
                      label: "Pot",
                      value: "${state.pot}",
                    ),
                    const SizedBox(width: 10),
                    _InfoBadge(
                      label: "Apuesta",
                      value: "${state.currentBet}",
                    ),
                  ],
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                top: height * 0.34,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final shown = state.revealed[i] && state.board[i] != "??";
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        width: 48,
                        child: PokerCardView(
                          faceUp: shown,
                          cardId: shown ? state.board[i] : null,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              ...seatWidgets,
            ],
          ),
        );
      },
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline.withOpacity(0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.p,
    required this.isMe,
    required this.isTurn,
    required this.isDealer,
    required this.waiting,
  });

  final PlayerState p;
  final bool isMe;
  final bool isTurn;
  final bool isDealer;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAllIn = p.inHand && !p.hasFolded && p.stack == 0;

    return Opacity(
      opacity: p.hasFolded ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isTurn
                ? cs.primary
                : isMe
                    ? cs.tertiary
                    : cs.outline.withOpacity(0.22),
            width: isTurn || isMe ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black.withOpacity(0.06),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isMe ? "Tú" : p.profileId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      decoration: p.hasFolded ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (isDealer)
                  Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      "D",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Stack ${p.stack}",
              style: const TextStyle(fontSize: 11),
            ),
            Text(
              "Bet ${p.betThisStreet}",
              style: const TextStyle(fontSize: 11),
            ),
            if (waiting) ...[
              const SizedBox(height: 4),
              _MiniStateBadge(
                text: p.ready ? "READY" : "PENDIENTE",
                color: p.ready ? Colors.green : Colors.orange,
              ),
            ],
            if (isAllIn) ...[
              const SizedBox(height: 4),
              const _MiniStateBadge(
                text: "ALL-IN",
                color: Colors.red,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStateBadge extends StatelessWidget {
  const _MiniStateBadge({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}