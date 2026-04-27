import 'dart:math';
import 'spanish_card.dart';

class SpanishDeck {
  final Random _rng = Random();
  final List<SpanishCard> _cards;

  SpanishDeck._(this._cards);

  factory SpanishDeck.shuffled40() {
    const values = [1, 2, 3, 4, 5, 6, 7, 10, 11, 12];
    final cards = <SpanishCard>[];

    for (final suit in SpanishSuit.values) {
      for (final v in values) {
        cards.add(SpanishCard(suit: suit, value: v));
      }
    }

    cards.shuffle(Random());
    return SpanishDeck._(cards);
  }

  factory SpanishDeck.fromCards(List<SpanishCard> cards, {bool shuffle = false}) {
    final cloned = List<SpanishCard>.from(cards);
    if (shuffle) {
      cloned.shuffle(Random());
    }
    return SpanishDeck._(cloned);
  }

  int get remaining => _cards.length;

  bool get isEmpty => _cards.isEmpty;

  SpanishCard? draw() {
    if (_cards.isEmpty) return null;
    return _cards.removeLast();
  }

  void reset() {
    final fresh = SpanishDeck.shuffled40();
    _cards
      ..clear()
      ..addAll(fresh._cards);
  }

  List<SpanishCard> get cardsSnapshot => List<SpanishCard>.from(_cards);
}