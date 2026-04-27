import 'dart:math';
import '../models/poker_state.dart';

enum ActionType { fold, check, call, raise }

class PokerAction {
  PokerAction(this.type, {this.raiseTo});
  final ActionType type;
  final int? raiseTo;
}

class StartHandResult {
  StartHandResult({
    required this.state,
    required this.privateHands,
    required this.remainingDeck,
  });

  final PokerState state;
  final Map<String, List<String>> privateHands;
  final List<String> remainingDeck;
}

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
      if (kickers[i] != other.kickers[i]) {
        return kickers[i].compareTo(other.kickers[i]);
      }
    }
    return 0;
  }
}

class _Card {
  _Card(this.rank, this.suit);
  final int rank; // 2..14
  final String suit; // S,H,D,C

  static _Card fromId(String id) {
    final r = id.substring(0, 1);
    final s = id.substring(1, 2);
    final rank = switch (r) {
      "A" => 14,
      "K" => 13,
      "Q" => 12,
      "J" => 11,
      "T" => 10,
      _ => int.parse(r),
    };
    return _Card(rank, s);
  }
}

class PokerEngine {
  static List<String> buildShuffledDeck() {
    const suits = ["S", "H", "D", "C"];
    const ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"];
    final deck = <String>[];
    for (final s in suits) {
      for (final r in ranks) {
        deck.add("$r$s");
      }
    }
    final rng = Random.secure();
    deck.shuffle(rng);
    return deck;
  }

  static StartHandResult startHand(PokerState prev) {
    final playing = prev.players.where((p) => p.stack > 0).toList();
    if (playing.length < 2) {
      throw Exception("Se necesitan al menos 2 jugadores con fichas.");
    }

    final dealerIndex = (prev.dealerIndex + 1) % playing.length;
    final deck = buildShuffledDeck();
    int top = 0;

    final hands = <String, List<String>>{};
    for (final p in playing) {
      hands[p.profileId] = [];
    }

    for (int round = 0; round < 2; round++) {
      for (int i = 0; i < playing.length; i++) {
        final idx = (dealerIndex + 1 + i) % playing.length;
        hands[playing[idx].profileId]!.add(deck[top++]);
      }
    }

    var players = playing.map((p) {
      return p.copyWith(
        inHand: true,
        hasFolded: false,
        betThisStreet: 0,
        totalCommitted: 0,
      );
    }).toList();

    int sbIndex;
    int bbIndex;
    int firstToActIndex;

    if (players.length == 2) {
      sbIndex = dealerIndex;
      bbIndex = (dealerIndex + 1) % players.length;
      firstToActIndex = dealerIndex;
    } else {
      sbIndex = (dealerIndex + 1) % players.length;
      bbIndex = (dealerIndex + 2) % players.length;
      firstToActIndex = (dealerIndex + 3) % players.length;
    }

    var pot = 0;

    PlayerState postBlind(PlayerState p, int amount) {
      final paid = min(amount, p.stack);
      pot += paid;
      return p.copyWith(
        stack: p.stack - paid,
        betThisStreet: p.betThisStreet + paid,
        totalCommitted: p.totalCommitted + paid,
      );
    }

    players[sbIndex] = postBlind(players[sbIndex], prev.sb);
    players[bbIndex] = postBlind(players[bbIndex], prev.bb);

    final state = prev.copyWith(
      phase: PokerPhase.preflop,
      handNo: prev.handNo + 1,
      dealerIndex: dealerIndex,
      turnProfileId: players[firstToActIndex].profileId,
      pot: pot,
      currentBet: prev.bb,
      board: List.filled(5, "??"),
      revealed: List.filled(5, false),
      players: players,
      sidePots: const [],
      winners: const [],
      showdownText: "",
      lastActionText: "Mano #${prev.handNo + 1} · Repartiendo cartas",
      actedThisStreet: const [],
    );

    return StartHandResult(
      state: state,
      privateHands: hands,
      remainingDeck: deck.sublist(top),
    );
  }

  static PokerState applyAction(PokerState s, String actorId, PokerAction action) {
  if (s.phase == PokerPhase.waiting || s.phase == PokerPhase.showdown) {
    throw Exception("No se puede actuar ahora.");
  }

  final idx = s.players.indexWhere((p) => p.profileId == actorId);
  if (idx < 0) throw Exception("Jugador no encontrado.");
  final actor = s.players[idx];

  if (s.turnProfileId != actorId) {
    throw Exception("No es tu turno.");
  }
  if (!actor.inHand || actor.hasFolded) {
    throw Exception("Ese jugador ya no está en la mano.");
  }

  final toCall = max(0, s.currentBet - actor.betThisStreet);
  var next = s;
  var acted = [...s.actedThisStreet];

  void markActed(String pid) {
    if (!acted.contains(pid)) {
      acted.add(pid);
    }
  }

  switch (action.type) {
    case ActionType.fold:
      next = next.replacePlayer(actor.copyWith(
        inHand: false,
        hasFolded: true,
      ));
      markActed(actorId);
      next = next.copyWith(
        lastActionText: "$actorId foldea",
        actedThisStreet: acted,
      );
      break;

    case ActionType.check:
      if (toCall != 0) {
        throw Exception("No puedes hacer check.");
      }
      markActed(actorId);
      next = next.copyWith(
        lastActionText: "$actorId check",
        actedThisStreet: acted,
      );
      break;

    case ActionType.call:
      if (toCall == 0) {
        throw Exception("No hay nada que pagar.");
      }
      next = _pay(next, actorId, toCall, "$actorId call $toCall");
      acted = [...next.actedThisStreet];
      markActed(actorId);
      next = next.copyWith(actedThisStreet: acted);
      break;

    case ActionType.raise:
      final raiseTo = action.raiseTo;
      if (raiseTo == null) throw Exception("Falta raiseTo.");
      if (raiseTo <= s.currentBet) {
        throw Exception("La subida debe superar la apuesta actual.");
      }

      final needed = raiseTo - actor.betThisStreet;
      if (needed <= 0) {
        throw Exception("Subida no válida.");
      }

      next = _pay(next, actorId, needed, "$actorId raise a $raiseTo");
      next = next.copyWith(
        currentBet: raiseTo,
        actedThisStreet: [actorId],
      );
      break;
  }

  final alive = next.players.where((p) => p.inHand && !p.hasFolded).toList();
  if (alive.length == 1) {
    final winner = alive.first;
    final awarded = winner.stack + next.pot;
    next = next.replacePlayer(winner.copyWith(stack: awarded));
    return next.copyWith(
      phase: PokerPhase.showdown,
      pot: 0,
      winners: [
        {"profileId": winner.profileId, "amount": next.pot}
      ],
      showdownText: "${winner.profileId} gana porque todos foldearon",
      lastActionText: "${winner.profileId} gana porque todos foldearon",
      turnProfileId: "",
      actedThisStreet: const [],
    );
  }

  if (_isStreetFinished(next)) {
    final resetPlayers = next.players
        .map((p) => p.copyWith(betThisStreet: 0))
        .toList();

    return next.copyWith(
      players: resetPlayers,
      currentBet: 0,
      turnProfileId: "",
      actedThisStreet: const [],
    );
  }

  final nextTurn = _nextActivePlayerId(next, actorId);
  return next.copyWith(turnProfileId: nextTurn);
}

  static PokerState _pay(PokerState s, String actorId, int amount, String text) {
    final idx = s.players.indexWhere((p) => p.profileId == actorId);
    final p = s.players[idx];
    final paid = min(amount, p.stack);

    final updated = p.copyWith(
      stack: p.stack - paid,
      betThisStreet: p.betThisStreet + paid,
      totalCommitted: p.totalCommitted + paid,
    );

    return s.replacePlayer(updated).copyWith(
      pot: s.pot + paid,
      lastActionText: text,
    );
  }
  static bool shouldAutoRunoutBoard(PokerState s) {
  if (s.phase == PokerPhase.waiting || s.phase == PokerPhase.showdown) {
    return false;
  }

  final alive = s.players.where((p) => p.inHand && !p.hasFolded).toList();
  if (alive.length <= 1) return false;

  final playersWhoCanAct = alive.where((p) => p.stack > 0).length;
  return playersWhoCanAct <= 1;
}
  static bool _isStreetFinished(PokerState s) {
  final active = s.players.where((p) => p.inHand && !p.hasFolded).toList();
  if (active.isEmpty) return true;

  final playersWhoCanAct = active.where((p) => p.stack > 0).toList();

  if (playersWhoCanAct.isEmpty) return true;

  for (final p in playersWhoCanAct) {
    final hasActed = s.actedThisStreet.contains(p.profileId);
    if (!hasActed) return false;
    if (p.betThisStreet != s.currentBet) return false;
  }

  return true;
}

  static String _nextActivePlayerId(PokerState s, String currentId) {
    final currentIndex = s.players.indexWhere((p) => p.profileId == currentId);
    for (int i = 1; i <= s.players.length; i++) {
      final idx = (currentIndex + i) % s.players.length;
      final p = s.players[idx];
      if (p.inHand && !p.hasFolded && p.stack > 0) {
        return p.profileId;
      }
    }
    return "";
  }

  static (PokerState, List<String>) advanceStreet(PokerState s, List<String> deck) {
    if (s.phase == PokerPhase.showdown || s.phase == PokerPhase.waiting) {
      return (s, deck);
    }

    final d = [...deck];
    String burn() => d.removeAt(0);
    String draw() => d.removeAt(0);

    PokerState next = s;

    if (s.phase == PokerPhase.preflop) {
      burn();
      final c1 = draw();
      final c2 = draw();
      final c3 = draw();
      next = s.copyWith(
        phase: PokerPhase.flop,
        board: [c1, c2, c3, "??", "??"],
        revealed: [true, true, true, false, false],
        turnProfileId: _firstPostflopPlayer(s),
        lastActionText: "Flop",
        actedThisStreet: const [],
      );
    } else if (s.phase == PokerPhase.flop) {
      burn();
      final c4 = draw();
      next = s.copyWith(
        phase: PokerPhase.turn,
        board: [s.board[0], s.board[1], s.board[2], c4, "??"],
        revealed: [true, true, true, true, false],
        turnProfileId: _firstPostflopPlayer(s),
        lastActionText: "Turn",
        actedThisStreet: const [],
      );
    } else if (s.phase == PokerPhase.turn) {
      burn();
      final c5 = draw();
      next = s.copyWith(
        phase: PokerPhase.river,
        board: [s.board[0], s.board[1], s.board[2], s.board[3], c5],
        revealed: [true, true, true, true, true],
        turnProfileId: _firstPostflopPlayer(s),
        lastActionText: "River",
        actedThisStreet: const [],
      );
    }

    return (next, d);
  }

  static String _firstPostflopPlayer(PokerState s) {
    final start = s.players.length == 2 ? (s.dealerIndex + 1) % s.players.length : (s.dealerIndex + 1) % s.players.length;
    for (int i = 0; i < s.players.length; i++) {
      final idx = (start + i) % s.players.length;
      final p = s.players[idx];
      if (p.inHand && !p.hasFolded && p.stack > 0) {
        return p.profileId;
      }
    }
    return "";
  }

  static PokerState showdown(PokerState s, Map<String, List<String>> privateHands) {
    final board = s.board.where((e) => e != "??").map(_Card.fromId).toList();

    final handByPlayer = <String, HandValue>{};
    for (final p in s.players) {
      if (!p.inHand || p.hasFolded) continue;
      final hand = privateHands[p.profileId];
      if (hand == null || hand.length != 2) continue;
      final cards = [...board, ...hand.map(_Card.fromId).toList()];
      handByPlayer[p.profileId] = _bestOf7(cards);
    }

    final sidePots = _buildSidePots(s.players);
    final winners = <Map<String, dynamic>>[];
    var next = s;

    for (final pot in sidePots) {
      final eligible = (pot["eligible"] as List).cast<String>().where(handByPlayer.containsKey).toList();
      if (eligible.isEmpty) continue;

      HandValue best = handByPlayer[eligible.first]!;
      for (final pid in eligible.skip(1)) {
        final hv = handByPlayer[pid]!;
        if (hv.compareTo(best) > 0) best = hv;
      }

      final tied = eligible.where((pid) => handByPlayer[pid]!.compareTo(best) == 0).toList();
      final amount = pot["amount"] as int;
      final share = amount ~/ tied.length;
      int remainder = amount - (share * tied.length);

      for (final pid in tied) {
        final idx = next.players.indexWhere((p) => p.profileId == pid);
        final pl = next.players[idx];
        next = next.replacePlayer(pl.copyWith(stack: pl.stack + share));
        winners.add({"profileId": pid, "amount": share});
      }

      if (remainder > 0) {
        final firstPid = tied.first;
        final idx = next.players.indexWhere((p) => p.profileId == firstPid);
        final pl = next.players[idx];
        next = next.replacePlayer(pl.copyWith(stack: pl.stack + remainder));
        winners.add({"profileId": firstPid, "amount": remainder});
      }
    }

    final text = winners.isEmpty
        ? "Showdown sin ganador"
        : winners.map((w) => "${w["profileId"]} +${w["amount"]}").join(" • ");

    return next.copyWith(
      phase: PokerPhase.showdown,
      pot: 0,
      sidePots: sidePots,
      winners: winners,
      showdownText: text,
      lastActionText: text,
    );
  }

  static List<Map<String, dynamic>> _buildSidePots(List<PlayerState> players) {
    final levels = players.map((p) => p.totalCommitted).where((v) => v > 0).toSet().toList()..sort();
    final pots = <Map<String, dynamic>>[];
    int prev = 0;

    for (final level in levels) {
      final layer = level - prev;
      if (layer <= 0) continue;

      final contributors = players.where((p) => p.totalCommitted >= level).toList();
      final amount = contributors.length * layer;
      final eligible = contributors
          .where((p) => p.inHand && !p.hasFolded)
          .map((p) => p.profileId)
          .toList();

      pots.add({
        "amount": amount,
        "eligible": eligible,
      });

      prev = level;
    }

    return pots;
  }

  static HandValue _bestOf7(List<_Card> cards7) {
    HandValue? best;
    for (int a = 0; a < 3; a++) {
      for (int b = a + 1; b < 4; b++) {
        for (int c = b + 1; c < 5; c++) {
          for (int d = c + 1; d < 6; d++) {
            for (int e = d + 1; e < 7; e++) {
              final value = _eval5([cards7[a], cards7[b], cards7[c], cards7[d], cards7[e]]);
              if (best == null || value.compareTo(best) > 0) {
                best = value;
              }
            }
          }
        }
      }
    }
    return best!;
  }

  static HandValue _eval5(List<_Card> cs) {
    final ranks = cs.map((c) => c.rank).toList()..sort();
    final suits = cs.map((c) => c.suit).toList();
    final flush = suits.toSet().length == 1;
    final straightHigh = _straightHigh(ranks);
    final straight = straightHigh != null;

    final freq = <int, int>{};
    for (final r in ranks) {
      freq[r] = (freq[r] ?? 0) + 1;
    }

    final groups = freq.entries.toList()
      ..sort((a, b) {
        final byCount = a.value.compareTo(b.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    if (flush && straight) {
      return HandValue(HandCategory.straightFlush, [straightHigh!]);
    }

    if (groups.last.value == 4) {
      return HandValue(HandCategory.quads, [groups.last.key, groups.first.key]);
    }

    if (groups.last.value == 3 && groups[groups.length - 2].value == 2) {
      return HandValue(HandCategory.fullHouse, [
        groups.last.key,
        groups[groups.length - 2].key,
      ]);
    }

    if (flush) {
      final desc = [...ranks]..sort((a, b) => b.compareTo(a));
      return HandValue(HandCategory.flush, desc);
    }

    if (straight) {
      return HandValue(HandCategory.straight, [straightHigh!]);
    }

    if (groups.last.value == 3) {
      final trips = groups.last.key;
      final kickers = groups.where((g) => g.value == 1).map((g) => g.key).toList()
        ..sort((a, b) => b.compareTo(a));
      return HandValue(HandCategory.trips, [trips, ...kickers]);
    }

    if (groups.last.value == 2 && groups[groups.length - 2].value == 2) {
      final p1 = groups.last.key;
      final p2 = groups[groups.length - 2].key;
      final hi = max(p1, p2);
      final lo = min(p1, p2);
      return HandValue(HandCategory.twoPair, [hi, lo, groups.first.key]);
    }

    if (groups.last.value == 2) {
      final pair = groups.last.key;
      final kickers = groups.where((g) => g.value == 1).map((g) => g.key).toList()
        ..sort((a, b) => b.compareTo(a));
      return HandValue(HandCategory.onePair, [pair, ...kickers]);
    }

    final desc = [...ranks]..sort((a, b) => b.compareTo(a));
    return HandValue(HandCategory.highCard, desc);
  }

  static int? _straightHigh(List<int> ranks) {
    final uniq = ranks.toSet().toList()..sort();
    if (uniq.length != 5) return null;

    if (uniq[0] == 2 && uniq[1] == 3 && uniq[2] == 4 && uniq[3] == 5 && uniq[4] == 14) {
      return 5;
    }

    for (int i = 1; i < 5; i++) {
      if (uniq[i] != uniq[0] + i) return null;
    }
    return uniq[4];
  }
}