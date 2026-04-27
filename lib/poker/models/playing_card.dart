enum Suit { spades, hearts, diamonds, clubs }

class PlayingCard {
  const PlayingCard(this.rank, this.suit);

  /// rank: 2..14 (A=14)
  final int rank;
  final Suit suit;

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
    return PlayingCard(rank, suit);
  }
}
