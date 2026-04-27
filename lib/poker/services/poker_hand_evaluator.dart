import '../widgets/poker_card.dart' show PlayingCard, Suit;

enum HandCategory {
  highCard,
  onePair,
  twoPair,
  trips,
  straight,
  flush,
  fullHouse,
  quads,
  straightFlush,
}

class HandValue implements Comparable<HandValue> {
  HandValue(this.category, this.kickers);

  final HandCategory category;
  final List<int> kickers;

  @override
  int compareTo(HandValue other) {
    if (category.index != other.category.index) {
      return category.index.compareTo(other.category.index);
    }
    final n = kickers.length < other.kickers.length ? kickers.length : other.kickers.length;
    for (int i = 0; i < n; i++) {
      if (kickers[i] != other.kickers[i]) return kickers[i].compareTo(other.kickers[i]);
    }
    return 0;
  }
}

class PokerHandEvaluator {
  static HandValue bestOf7(List<PlayingCard> cards7) {
    HandValue? best;
    for (int a = 0; a < 3; a++) {
      for (int b = a + 1; b < 4; b++) {
        for (int c = b + 1; c < 5; c++) {
          for (int d = c + 1; d < 6; d++) {
            for (int e = d + 1; e < 7; e++) {
              final hv = _eval5([cards7[a], cards7[b], cards7[c], cards7[d], cards7[e]]);
              if (best == null || hv.compareTo(best) > 0) best = hv;
            }
          }
        }
      }
    }
    return best!;
  }

  static HandValue _eval5(List<PlayingCard> cs) {
    final ranks = cs.map((c) => c.rank).toList()..sort();
    final isFlush = cs.map((c) => c.suit).toSet().length == 1;

    final straightHigh = _straightHigh(ranks);
    final isStraight = straightHigh != null;

    final freq = <int, int>{};
    for (final r in ranks) {
      freq[r] = (freq[r] ?? 0) + 1;
    }

    final groups = freq.entries.toList()
      ..sort((a, b) {
        final c = a.value.compareTo(b.value);
        if (c != 0) return c;
        return a.key.compareTo(b.key);
      });

    if (isFlush && isStraight) return HandValue(HandCategory.straightFlush, [straightHigh!]);

    if (groups.last.value == 4) {
      final quad = groups.last.key;
      final kicker = groups.first.key;
      return HandValue(HandCategory.quads, [quad, kicker]);
    }

    if (groups.last.value == 3 && groups[groups.length - 2].value == 2) {
      return HandValue(HandCategory.fullHouse, [groups.last.key, groups[groups.length - 2].key]);
    }

    if (isFlush) {
      final desc = ranks.toList()..sort((a, b) => b.compareTo(a));
      return HandValue(HandCategory.flush, desc);
    }

    if (isStraight) return HandValue(HandCategory.straight, [straightHigh!]);

    if (groups.last.value == 3) {
      final trips = groups.last.key;
      final kick = groups.where((g) => g.value == 1).map((g) => g.key).toList()
        ..sort((a, b) => b.compareTo(a));
      return HandValue(HandCategory.trips, [trips, ...kick]);
    }

    if (groups.last.value == 2 && groups[groups.length - 2].value == 2) {
      final p1 = groups.last.key;
      final p2 = groups[groups.length - 2].key;
      final hi = p1 > p2 ? p1 : p2;
      final lo = p1 > p2 ? p2 : p1;
      return HandValue(HandCategory.twoPair, [hi, lo, groups.first.key]);
    }

    if (groups.last.value == 2) {
      final pair = groups.last.key;
      final kick = groups.where((g) => g.value == 1).map((g) => g.key).toList()
        ..sort((a, b) => b.compareTo(a));
      return HandValue(HandCategory.onePair, [pair, ...kick]);
    }

    final desc = ranks.toList()..sort((a, b) => b.compareTo(a));
    return HandValue(HandCategory.highCard, desc);
  }

  static int? _straightHigh(List<int> sortedAsc) {
    final uniq = sortedAsc.toSet().toList()..sort();
    if (uniq.length != 5) return null;

    // Wheel: A-2-3-4-5
    if (uniq[0] == 2 && uniq[1] == 3 && uniq[2] == 4 && uniq[3] == 5 && uniq[4] == 14) return 5;

    for (int i = 1; i < 5; i++) {
      if (uniq[i] != uniq[0] + i) return null;
    }
    return uniq[4];
  }
}
