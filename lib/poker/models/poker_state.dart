enum PokerPhase { waiting, preflop, flop, turn, river, showdown }

class PlayerState {
  PlayerState({
    required this.profileId,
    required this.stack,
    required this.inHand,
    required this.hasFolded,
    required this.betThisStreet,
    required this.totalCommitted,
    required this.ready,
  });

  final String profileId;
  final int stack;
  final bool inHand;
  final bool hasFolded;
  final int betThisStreet;
  final int totalCommitted;
  final bool ready;

  PlayerState copyWith({
    int? stack,
    bool? inHand,
    bool? hasFolded,
    int? betThisStreet,
    int? totalCommitted,
    bool? ready,
  }) {
    return PlayerState(
      profileId: profileId,
      stack: stack ?? this.stack,
      inHand: inHand ?? this.inHand,
      hasFolded: hasFolded ?? this.hasFolded,
      betThisStreet: betThisStreet ?? this.betThisStreet,
      totalCommitted: totalCommitted ?? this.totalCommitted,
      ready: ready ?? this.ready,
    );
  }

  Map<String, dynamic> toMap() => {
        "profileId": profileId,
        "stack": stack,
        "inHand": inHand,
        "hasFolded": hasFolded,
        "betThisStreet": betThisStreet,
        "totalCommitted": totalCommitted,
        "ready": ready,
      };

  static PlayerState fromMap(Map<String, dynamic> m) => PlayerState(
        profileId: m["profileId"] as String,
        stack: (m["stack"] ?? 0) as int,
        inHand: (m["inHand"] ?? true) as bool,
        hasFolded: (m["hasFolded"] ?? false) as bool,
        betThisStreet: (m["betThisStreet"] ?? 0) as int,
        totalCommitted: (m["totalCommitted"] ?? 0) as int,
        ready: (m["ready"] ?? false) as bool,
      );
}

class PokerState {
  PokerState({
    required this.phase,
    required this.handNo,
    required this.dealerIndex,
    required this.sb,
    required this.bb,
    required this.turnProfileId,
    required this.pot,
    required this.currentBet,
    required this.board,
    required this.revealed,
    required this.players,
    required this.sidePots,
    required this.winners,
    required this.showdownText,
    required this.lastActionText,
    required this.actedThisStreet,
    required this.showdownLines,
  });

  final PokerPhase phase;
  final int handNo;
  final int dealerIndex;
  final int sb;
  final int bb;
  final String turnProfileId;
  final int pot;
  final int currentBet;
  final List<String> board;
  final List<bool> revealed;
  final List<PlayerState> players;
  final List<Map<String, dynamic>> sidePots;
  final List<Map<String, dynamic>> winners;
  final String showdownText;
  final String lastActionText;
  final List<String> actedThisStreet;
  final List<String> showdownLines;

  Map<String, dynamic> toMap() => {
        "phase": phase.name.toUpperCase(),
        "handNo": handNo,
        "dealerIndex": dealerIndex,
        "sb": sb,
        "bb": bb,
        "turnProfileId": turnProfileId,
        "pot": pot,
        "currentBet": currentBet,
        "board": board,
        "revealed": revealed,
        "players": players.map((p) => p.toMap()).toList(),
        "sidePots": sidePots,
        "winners": winners,
        "showdownText": showdownText,
        "lastActionText": lastActionText,
        "actedThisStreet": actedThisStreet,
        "showdownLines": showdownLines,
      };

  static PokerPhase _phaseFrom(String s) {
    switch (s) {
      case "PREFLOP":
        return PokerPhase.preflop;
      case "FLOP":
        return PokerPhase.flop;
      case "TURN":
        return PokerPhase.turn;
      case "RIVER":
        return PokerPhase.river;
      case "SHOWDOWN":
        return PokerPhase.showdown;
      default:
        return PokerPhase.waiting;
    }
  }

  static PokerState fromMap(Map<String, dynamic> m) => PokerState(
        phase: _phaseFrom((m["phase"] ?? "WAITING") as String),
        handNo: (m["handNo"] ?? 0) as int,
        dealerIndex: (m["dealerIndex"] ?? 0) as int,
        sb: (m["sb"] ?? 10) as int,
        bb: (m["bb"] ?? 20) as int,
        turnProfileId: (m["turnProfileId"] ?? "") as String,
        pot: (m["pot"] ?? 0) as int,
        currentBet: (m["currentBet"] ?? 0) as int,
        board: List<String>.from(m["board"] ?? List.filled(5, "??")),
        revealed: List<bool>.from(m["revealed"] ?? List.filled(5, false)),
        players: (m["players"] as List<dynamic>? ?? const [])
            .map((e) => PlayerState.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        sidePots: List<Map<String, dynamic>>.from(m["sidePots"] ?? const []),
        winners: List<Map<String, dynamic>>.from(m["winners"] ?? const []),
        showdownText: (m["showdownText"] ?? "") as String,
        lastActionText: (m["lastActionText"] ?? "") as String,
        actedThisStreet: List<String>.from(m["actedThisStreet"] ?? const []),
        showdownLines: List<String>.from(m["showdownLines"] ?? const []),
      );

  PokerState copyWith({
    PokerPhase? phase,
    int? handNo,
    int? dealerIndex,
    int? sb,
    int? bb,
    String? turnProfileId,
    int? pot,
    int? currentBet,
    List<String>? board,
    List<bool>? revealed,
    List<PlayerState>? players,
    List<Map<String, dynamic>>? sidePots,
    List<Map<String, dynamic>>? winners,
    String? showdownText,
    String? lastActionText,
    List<String>? actedThisStreet,
    List<String>? showdownLines,
  }) {
    return PokerState(
      phase: phase ?? this.phase,
      handNo: handNo ?? this.handNo,
      dealerIndex: dealerIndex ?? this.dealerIndex,
      sb: sb ?? this.sb,
      bb: bb ?? this.bb,
      turnProfileId: turnProfileId ?? this.turnProfileId,
      pot: pot ?? this.pot,
      currentBet: currentBet ?? this.currentBet,
      board: board ?? this.board,
      revealed: revealed ?? this.revealed,
      players: players ?? this.players,
      sidePots: sidePots ?? this.sidePots,
      winners: winners ?? this.winners,
      showdownText: showdownText ?? this.showdownText,
      lastActionText: lastActionText ?? this.lastActionText,
      actedThisStreet: actedThisStreet ?? this.actedThisStreet,
      showdownLines: showdownLines ?? this.showdownLines,
    );
  }

  PokerState replacePlayer(PlayerState updated) {
    final ps = [...players];
    final i = ps.indexWhere((p) => p.profileId == updated.profileId);
    if (i >= 0) ps[i] = updated;
    return copyWith(players: ps);
  }
}