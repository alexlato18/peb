import 'party_card_models.dart';

class PartyGameMatchState {
  const PartyGameMatchState({
    required this.roomId,
    required this.status, // playing | finished
    required this.round,
    required this.turnPlayerId,
    required this.startingPlayerIdOfRound,
    required this.playerOrder,
    required this.players,
    required this.cardsInPlay,
    required this.characterDeck,
    required this.eventDeck,
    required this.characterDiscard,
    required this.eventDiscard,
    this.nextRoundStartingPlayerId,
  });

  final String roomId;
  final String status;
  final int round;
  final String turnPlayerId;
  final String startingPlayerIdOfRound;
  final List<String> playerOrder;
  final Map<String, PartyGamePlayerState> players;

  final Map<String, PartyCardInPlay> cardsInPlay;

  final List<String> characterDeck;
  final List<String> eventDeck;
  final List<String> characterDiscard;
  final List<String> eventDiscard;

  final String? nextRoundStartingPlayerId;

  factory PartyGameMatchState.fromMap(Map<String, dynamic> map) {
    final rawPlayers = (map['players'] as Map<String, dynamic>? ?? {});
    final rawCardsInPlay = (map['cardsInPlay'] as Map<String, dynamic>? ?? {});

    return PartyGameMatchState(
      roomId: (map['roomId'] ?? '') as String,
      status: (map['status'] ?? 'playing') as String,
      round: (map['round'] ?? 1) as int,
      turnPlayerId: (map['turnPlayerId'] ?? '') as String,
      startingPlayerIdOfRound:
          (map['startingPlayerIdOfRound'] ?? '') as String,
      playerOrder: List<String>.from(map['playerOrder'] ?? const []),
      players: rawPlayers.map(
        (key, value) => MapEntry(
          key,
          PartyGamePlayerState.fromMap(Map<String, dynamic>.from(value)),
        ),
      ),
      cardsInPlay: rawCardsInPlay.map(
        (key, value) => MapEntry(
          key,
          PartyCardInPlayMapper.fromMap(Map<String, dynamic>.from(value)),
        ),
      ),
      characterDeck: List<String>.from(map['characterDeck'] ?? const []),
      eventDeck: List<String>.from(map['eventDeck'] ?? const []),
      characterDiscard: List<String>.from(map['characterDiscard'] ?? const []),
      eventDiscard: List<String>.from(map['eventDiscard'] ?? const []),
      nextRoundStartingPlayerId: map['nextRoundStartingPlayerId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'status': status,
      'round': round,
      'turnPlayerId': turnPlayerId,
      'startingPlayerIdOfRound': startingPlayerIdOfRound,
      'playerOrder': playerOrder,
      'players': players.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'cardsInPlay': cardsInPlay.map(
        (key, value) => MapEntry(key, PartyCardInPlayMapper.toMap(value)),
      ),
      'characterDeck': characterDeck,
      'eventDeck': eventDeck,
      'characterDiscard': characterDiscard,
      'eventDiscard': eventDiscard,
      'nextRoundStartingPlayerId': nextRoundStartingPlayerId,
    };
  }

  PartyGameMatchState copyWith({
    String? roomId,
    String? status,
    int? round,
    String? turnPlayerId,
    String? startingPlayerIdOfRound,
    List<String>? playerOrder,
    Map<String, PartyGamePlayerState>? players,
    Map<String, PartyCardInPlay>? cardsInPlay,
    List<String>? characterDeck,
    List<String>? eventDeck,
    List<String>? characterDiscard,
    List<String>? eventDiscard,
    String? nextRoundStartingPlayerId,
  }) {
    return PartyGameMatchState(
      roomId: roomId ?? this.roomId,
      status: status ?? this.status,
      round: round ?? this.round,
      turnPlayerId: turnPlayerId ?? this.turnPlayerId,
      startingPlayerIdOfRound:
          startingPlayerIdOfRound ?? this.startingPlayerIdOfRound,
      playerOrder: playerOrder ?? this.playerOrder,
      players: players ?? this.players,
      cardsInPlay: cardsInPlay ?? this.cardsInPlay,
      characterDeck: characterDeck ?? this.characterDeck,
      eventDeck: eventDeck ?? this.eventDeck,
      characterDiscard: characterDiscard ?? this.characterDiscard,
      eventDiscard: eventDiscard ?? this.eventDiscard,
      nextRoundStartingPlayerId:
          nextRoundStartingPlayerId ?? this.nextRoundStartingPlayerId,
    );
  }
}

class PartyGamePlayerState {
  const PartyGamePlayerState({
    required this.profileId,
    required this.money,
    required this.score,
    required this.handCharacterCardIds,
    required this.handEventCardIds,
    required this.tableCharacterCardInstanceIds,
    required this.tableEventCardInstanceIds,
    required this.synergyState,
    this.skipNextTurn = false,
    this.cardsPlayedThisTurn = 0,
    this.characterCardsPlayedThisTurn = 0,
    this.eventCardsPlayedThisTurn = 0,
  });

  final String profileId;
  final int money;
  final int score;

  final List<String> handCharacterCardIds;
  final List<String> handEventCardIds;

  final List<String> tableCharacterCardInstanceIds;
  final List<String> tableEventCardInstanceIds;

  final PartyGameSynergyState synergyState;

  final bool skipNextTurn;
  final int cardsPlayedThisTurn;
  final int characterCardsPlayedThisTurn;
  final int eventCardsPlayedThisTurn;

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
      tableCharacterCardInstanceIds: List<String>.from(
        map['tableCharacterCardInstanceIds'] ?? const [],
      ),
      tableEventCardInstanceIds: List<String>.from(
        map['tableEventCardInstanceIds'] ?? const [],
      ),
      synergyState: PartyGameSynergyStateMapper.fromMap(
        Map<String, dynamic>.from(map['synergyState'] ?? const {}),
      ),
      skipNextTurn: (map['skipNextTurn'] ?? false) as bool,
      cardsPlayedThisTurn: (map['cardsPlayedThisTurn'] ?? 0) as int,
      characterCardsPlayedThisTurn:
          (map['characterCardsPlayedThisTurn'] ?? 0) as int,
      eventCardsPlayedThisTurn:
          (map['eventCardsPlayedThisTurn'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'profileId': profileId,
      'money': money,
      'score': score,
      'handCharacterCardIds': handCharacterCardIds,
      'handEventCardIds': handEventCardIds,
      'tableCharacterCardInstanceIds': tableCharacterCardInstanceIds,
      'tableEventCardInstanceIds': tableEventCardInstanceIds,
      'synergyState': PartyGameSynergyStateMapper.toMap(synergyState),
      'skipNextTurn': skipNextTurn,
      'cardsPlayedThisTurn': cardsPlayedThisTurn,
      'characterCardsPlayedThisTurn': characterCardsPlayedThisTurn,
      'eventCardsPlayedThisTurn': eventCardsPlayedThisTurn,
    };
  }

  PartyGamePlayerState copyWith({
    String? profileId,
    int? money,
    int? score,
    List<String>? handCharacterCardIds,
    List<String>? handEventCardIds,
    List<String>? tableCharacterCardInstanceIds,
    List<String>? tableEventCardInstanceIds,
    PartyGameSynergyState? synergyState,
    bool? skipNextTurn,
    int? cardsPlayedThisTurn,
    int? characterCardsPlayedThisTurn,
    int? eventCardsPlayedThisTurn,
  }) {
    return PartyGamePlayerState(
      profileId: profileId ?? this.profileId,
      money: money ?? this.money,
      score: score ?? this.score,
      handCharacterCardIds: handCharacterCardIds ?? this.handCharacterCardIds,
      handEventCardIds: handEventCardIds ?? this.handEventCardIds,
      tableCharacterCardInstanceIds:
          tableCharacterCardInstanceIds ?? this.tableCharacterCardInstanceIds,
      tableEventCardInstanceIds:
          tableEventCardInstanceIds ?? this.tableEventCardInstanceIds,
      synergyState: synergyState ?? this.synergyState,
      skipNextTurn: skipNextTurn ?? this.skipNextTurn,
      cardsPlayedThisTurn: cardsPlayedThisTurn ?? this.cardsPlayedThisTurn,
      characterCardsPlayedThisTurn:
          characterCardsPlayedThisTurn ?? this.characterCardsPlayedThisTurn,
      eventCardsPlayedThisTurn:
          eventCardsPlayedThisTurn ?? this.eventCardsPlayedThisTurn,
    );
  }
}

class PartyCardInPlayMapper {
  static PartyCardInPlay fromMap(Map<String, dynamic> map) {
    return PartyCardInPlay(
      instanceId: (map['instanceId'] ?? '') as String,
      definitionId: (map['definitionId'] ?? '') as String,
      ownerPlayerId: (map['ownerPlayerId'] ?? '') as String,
      playedRound: (map['playedRound'] ?? 1) as int,
      baseScoreOverride: map['baseScoreOverride'] as int?,
      attachedPermanentScore: (map['attachedPermanentScore'] ?? 0) as int,
      attachedTemporaryScore: (map['attachedTemporaryScore'] ?? 0) as int,
      isDead: (map['isDead'] ?? false) as bool,
      isEmbargoed: (map['isEmbargoed'] ?? false) as bool,
      isSilenced: (map['isSilenced'] ?? false) as bool,
      eventShieldCharges: (map['eventShieldCharges'] ?? 0) as int,
      adverseEventShieldCharges:
          (map['adverseEventShieldCharges'] ?? 0) as int,
      customData: Map<String, dynamic>.from(map['customData'] ?? const {}),
    );
  }

  static Map<String, dynamic> toMap(PartyCardInPlay card) {
    return {
      'instanceId': card.instanceId,
      'definitionId': card.definitionId,
      'ownerPlayerId': card.ownerPlayerId,
      'playedRound': card.playedRound,
      'baseScoreOverride': card.baseScoreOverride,
      'attachedPermanentScore': card.attachedPermanentScore,
      'attachedTemporaryScore': card.attachedTemporaryScore,
      'isDead': card.isDead,
      'isEmbargoed': card.isEmbargoed,
      'isSilenced': card.isSilenced,
      'eventShieldCharges': card.eventShieldCharges,
      'adverseEventShieldCharges': card.adverseEventShieldCharges,
      'customData': card.customData,
    };
  }
}

class PartyGameSynergyStateMapper {
  static PartyGameSynergyState fromMap(Map<String, dynamic> map) {
    return PartyGameSynergyState(
      triggeredKeys: List<String>.from(map['triggeredKeys'] ?? const []),
      permanentScore: (map['permanentScore'] ?? 0) as int,
      moneyPerRoundBonus: (map['moneyPerRoundBonus'] ?? 0) as int,
      blockNextEvents: (map['blockNextEvents'] ?? 0) as int,
    );
  }

  static Map<String, dynamic> toMap(PartyGameSynergyState state) {
    return {
      'triggeredKeys': state.triggeredKeys,
      'permanentScore': state.permanentScore,
      'moneyPerRoundBonus': state.moneyPerRoundBonus,
      'blockNextEvents': state.blockNextEvents,
    };
  }
}