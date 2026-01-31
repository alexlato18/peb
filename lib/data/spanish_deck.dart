import 'dart:math';
import 'spanish_card.dart';

class SpanishDeck {
  final Random _rng = Random();
  final List<SpanishCard> _cards;

  SpanishDeck._(this._cards);

  factory SpanishDeck.shuffled40() {
    const values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
    final cards = <SpanishCard>[];

    for (final suit in SpanishSuit.values) {
      for (final v in values) {
        cards.add(SpanishCard(suit: suit, value: v));
      }
    }

    cards.shuffle(Random());
    return SpanishDeck._(cards);
  }

  int get remaining => _cards.length;

  bool get isEmpty => _cards.isEmpty;

  /// Roba 1 carta sin reposición
  SpanishCard? draw() {
    if (_cards.isEmpty) return null;
    // Ya está mezclado; podemos sacar la última
    return _cards.removeLast();
  }

  void reset() {
    final fresh = SpanishDeck.shuffled40();
    _cards
      ..clear()
      ..addAll(fresh._cards);
  }
}
