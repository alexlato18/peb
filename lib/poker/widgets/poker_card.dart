import 'package:flutter/material.dart';

enum Suit { spades, hearts, diamonds, clubs }

class PlayingCard {
  const PlayingCard({required this.rank, required this.suit});

  final int rank; // 2..14
  final Suit suit;

  String get rankLabel => switch (rank) {
        14 => "A",
        13 => "K",
        12 => "Q",
        11 => "J",
        10 => "10",
        _ => rank.toString(),
      };

  String get suitLabel => switch (suit) {
        Suit.spades => "♠",
        Suit.hearts => "♥",
        Suit.diamonds => "♦",
        Suit.clubs => "♣",
      };

  Color get suitColor =>
      (suit == Suit.hearts || suit == Suit.diamonds)
          ? const Color(0xFFC62828)
          : const Color(0xFF111111);

  String get id {
    final r = switch (rank) {
      14 => "A",
      13 => "K",
      12 => "Q",
      11 => "J",
      10 => "T",
      _ => rank.toString(),
    };
    final s = switch (suit) {
      Suit.spades => "S",
      Suit.hearts => "H",
      Suit.diamonds => "D",
      Suit.clubs => "C",
    };
    return "$r$s";
  }

  static PlayingCard fromId(String id) {
    final rChar = id.substring(0, 1);
    final sChar = id.substring(1, 2);

    final rank = switch (rChar) {
      "A" => 14,
      "K" => 13,
      "Q" => 12,
      "J" => 11,
      "T" => 10,
      _ => int.parse(rChar),
    };

    final suit = switch (sChar) {
      "S" => Suit.spades,
      "H" => Suit.hearts,
      "D" => Suit.diamonds,
      _ => Suit.clubs,
    };

    return PlayingCard(rank: rank, suit: suit);
  }
}

class PokerCardView extends StatelessWidget {
  const PokerCardView({
    super.key,
    required this.faceUp,
    this.cardId,
  });

  final bool faceUp;
  final String? cardId;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.72,
      child: faceUp && cardId != null
          ? _PokerFront(card: PlayingCard.fromId(cardId!))
          : const _PokerBack(),
    );
  }
}

class _PokerFront extends StatelessWidget {
  const _PokerFront({required this.card});

  final PlayingCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD7D7D7),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.rankLabel,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: card.suitColor,
                    ),
                  ),
                  Text(
                    card.suitLabel,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: card.suitColor,
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Transform.rotate(
                angle: 3.1415926535,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      card.rankLabel,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: card.suitColor,
                      ),
                    ),
                    Text(
                      card.suitLabel,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: card.suitColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PokerBack extends StatelessWidget {
  const _PokerBack();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF060606),
                    Color(0xFF161616),
                  ],
                ),
              ),
            ),

            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: const Color(0xFFE0B63F),
                    width: 1.8,
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Opacity(
                  opacity: 0.95,
                  child: Image.asset(
                    'lib/assets/reverso.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBackPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const spacing = 10.0;

    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }

    for (double x = 0; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}