class PartyGameMatchState {
  const PartyGameMatchState({
    required this.roomId,
    required this.status,
    required this.round,
    required this.turnPlayerId,
    required this.playerOrder,
    required this.players,
  });

  final String roomId;
  final String status; // playing | finished
  final int round;
  final String turnPlayerId;
  final List<String> playerOrder;
  final Map<String, PartyGamePlayerState> players;

  factory PartyGameMatchState.fromMap(Map<String, dynamic> map) {
    final rawPlayers = (map['players'] as Map<String, dynamic>? ?? {});

    return PartyGameMatchState(
      roomId: (map['roomId'] ?? '') as String,
      status: (map['status'] ?? 'playing') as String,
      round: (map['round'] ?? 1) as int,
      turnPlayerId: (map['turnPlayerId'] ?? '') as String,
      playerOrder: List<String>.from(map['playerOrder'] ?? const []),
      players: rawPlayers.map(
        (key, value) => MapEntry(
          key,
          PartyGamePlayerState.fromMap(Map<String, dynamic>.from(value)),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'status': status,
      'round': round,
      'turnPlayerId': turnPlayerId,
      'playerOrder': playerOrder,
      'players': players.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
    };
  }
}

class PartyGamePlayerState {
  const PartyGamePlayerState({
    required this.profileId,
    required this.money,
    required this.score,
    required this.handCharacterCardIds,
    required this.handEventCardIds,
    required this.tableCharacterCardIds,
    required this.tableEventCardIds,
  });

  final String profileId;
  final int money;
  final int score;
  final List<String> handCharacterCardIds;
  final List<String> handEventCardIds;
  final List<String> tableCharacterCardIds;
  final List<String> tableEventCardIds;

  factory PartyGamePlayerState.fromMap(Map<String, dynamic> map) {
    return PartyGamePlayerState(
      profileId: (map['profileId'] ?? '') as String,
      money: (map['money'] ?? 8) as int,
      score: (map['score'] ?? 0) as int,
      handCharacterCardIds: List<String>.from(
        map['handCharacterCardIds'] ?? const [],
      ),
      handEventCardIds: List<String>.from(
        map['handEventCardIds'] ?? const [],
      ),
      tableCharacterCardIds: List<String>.from(
        map['tableCharacterCardIds'] ?? const [],
      ),
      tableEventCardIds: List<String>.from(
        map['tableEventCardIds'] ?? const [],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'profileId': profileId,
      'money': money,
      'score': score,
      'handCharacterCardIds': handCharacterCardIds,
      'handEventCardIds': handEventCardIds,
      'tableCharacterCardIds': tableCharacterCardIds,
      'tableEventCardIds': tableEventCardIds,
    };
  }
}