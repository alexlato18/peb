import 'package:peb/PEB/widgets/party_game_score_helpers.dart';
import 'package:peb/PEB/widgets/party_game_sinergy_calculator.dart';

import '../models/party_card_models.dart';
import '../models/party_game_match_models.dart';
import 'party_card_catalog.dart';

class PlayCharacterCommand {
  const PlayCharacterCommand({
    this.targetPlayerId,
    this.targetCharacterInstanceId,
    this.chosenMode,
  });

  final String? targetPlayerId;
  final String? targetCharacterInstanceId;
  final String? chosenMode;
}

class PlayEventCommand {
  const PlayEventCommand({
    this.targetPlayerId,
    this.targetCharacterInstanceId,
    this.chosenMode,
  });

  final String? targetPlayerId;
  final String? targetCharacterInstanceId;
  final String? chosenMode;
}

class PartyGameEngine {
  PartyGameEngine({
    required this.catalog,
    PartyGameSynergyResolver? synergyResolver,
  }) : synergyResolver = synergyResolver ?? PartyGameSynergyResolver();

  final PartyCardCatalog catalog;
  final PartyGameSynergyResolver synergyResolver;

  PartyGameMatchState playCharacter({
    required PartyGameMatchState match,
    required String actorPlayerId,
    required String cardDefinitionId,
    PlayCharacterCommand command = const PlayCharacterCommand(),
  }) {
    _assertPlaying(match);
    _assertTurn(match, actorPlayerId);

    final actor = _requirePlayer(match, actorPlayerId);
    final card = _requireCard(cardDefinitionId);

    if (card.type != PartyCardType.character) {
      throw StateError('La carta no es de personaje.');
    }

    if (!actor.handCharacterCardIds.contains(cardDefinitionId)) {
      throw StateError('La carta no está en la mano.');
    }

    if (actor.money < card.cost) {
      throw StateError('No hay dinero suficiente.');
    }

    if (!_canPlayCharacter(match, actor)) {
      throw StateError('Ya has alcanzado el límite de personajes este turno.');
    }

    final instanceId = _newInstanceId();

    final inPlay = PartyCardInPlay(
      instanceId: instanceId,
      definitionId: cardDefinitionId,
      ownerPlayerId: actorPlayerId,
      playedRound: match.round,
    );

    final updatedActor = actor.copyWith(
      money: actor.money - card.cost,
      handCharacterCardIds: List<String>.from(actor.handCharacterCardIds)
        ..remove(cardDefinitionId),
      tableCharacterCardInstanceIds: [
        ...actor.tableCharacterCardInstanceIds,
        instanceId,
      ],
      cardsPlayedThisTurn: actor.cardsPlayedThisTurn + 1,
      characterCardsPlayedThisTurn: actor.characterCardsPlayedThisTurn + 1,
    );

    final updatedPlayers = Map<String, PartyGamePlayerState>.from(match.players)
      ..[actorPlayerId] = updatedActor;

    var updatedMatch = match.copyWith(
      players: updatedPlayers,
      cardsInPlay: Map<String, PartyCardInPlay>.from(match.cardsInPlay)
        ..[instanceId] = inPlay,
    );

    updatedMatch = _applyCardEffects(
      match: updatedMatch,
      sourcePlayerId: actorPlayerId,
      sourceCardInstanceId: instanceId,
      effects: card.effects,
      targetPlayerId: command.targetPlayerId,
      targetCharacterInstanceId: command.targetCharacterInstanceId,
      chosenMode: command.chosenMode,
    );

    updatedMatch = synergyResolver.recalculateForPlayer(
      match: updatedMatch,
      playerId: actorPlayerId,
      catalog: catalog,
    );

    updatedMatch = _refreshAllScores(updatedMatch);

    return updatedMatch;
  }

  PartyGameMatchState playEvent({
    required PartyGameMatchState match,
    required String actorPlayerId,
    required String cardDefinitionId,
    PlayEventCommand command = const PlayEventCommand(),
  }) {
    _assertPlaying(match);
    _assertTurn(match, actorPlayerId);

    final actor = _requirePlayer(match, actorPlayerId);
    final card = _requireCard(cardDefinitionId);

    if (card.type != PartyCardType.event) {
      throw StateError('La carta no es de evento.');
    }

    if (!actor.handEventCardIds.contains(cardDefinitionId)) {
      throw StateError('La carta no está en la mano.');
    }

    if (actor.money < card.cost) {
      throw StateError('No hay dinero suficiente.');
    }

    if (!_canPlayEvent(match, actor)) {
      throw StateError('Ya has alcanzado el límite de cartas este turno.');
    }

    final targetPlayerId = command.targetPlayerId ?? actorPlayerId;
    final targetPlayer = _requirePlayer(match, targetPlayerId);

    if (targetPlayer.synergyState.blockNextEvents > 0) {
      final reducedTarget = targetPlayer.copyWith(
        synergyState: targetPlayer.synergyState.copyWith(
          blockNextEvents: targetPlayer.synergyState.blockNextEvents - 1,
        ),
      );

      final updatedActor = actor.copyWith(
        money: actor.money - card.cost,
        handEventCardIds: List<String>.from(actor.handEventCardIds)
          ..remove(cardDefinitionId),
        cardsPlayedThisTurn: actor.cardsPlayedThisTurn + 1,
        eventCardsPlayedThisTurn: actor.eventCardsPlayedThisTurn + 1,
      );

      final updatedPlayers = Map<String, PartyGamePlayerState>.from(match.players)
        ..[actorPlayerId] = updatedActor
        ..[targetPlayerId] = reducedTarget;

      return _refreshAllScores(match.copyWith(players: updatedPlayers));
    }

    final instanceId = _newInstanceId();

    final inPlay = PartyCardInPlay(
      instanceId: instanceId,
      definitionId: cardDefinitionId,
      ownerPlayerId: actorPlayerId,
      playedRound: match.round,
    );

    final updatedActor = actor.copyWith(
      money: actor.money - card.cost,
      handEventCardIds: List<String>.from(actor.handEventCardIds)
        ..remove(cardDefinitionId),
      cardsPlayedThisTurn: actor.cardsPlayedThisTurn + 1,
      eventCardsPlayedThisTurn: actor.eventCardsPlayedThisTurn + 1,
    );

    final updatedTarget = targetPlayer.copyWith(
      tableEventCardInstanceIds: [
        ...targetPlayer.tableEventCardInstanceIds,
        instanceId,
      ],
    );

    var updatedMatch = match.copyWith(
      players: Map<String, PartyGamePlayerState>.from(match.players)
        ..[actorPlayerId] = updatedActor
        ..[targetPlayerId] = updatedTarget,
      cardsInPlay: Map<String, PartyCardInPlay>.from(match.cardsInPlay)
        ..[instanceId] = inPlay,
    );

    updatedMatch = _applyCardEffects(
      match: updatedMatch,
      sourcePlayerId: actorPlayerId,
      sourceCardInstanceId: instanceId,
      effects: card.effects,
      targetPlayerId: targetPlayerId,
      targetCharacterInstanceId: command.targetCharacterInstanceId,
      chosenMode: command.chosenMode,
    );

    updatedMatch = _refreshAllScores(updatedMatch);

    return updatedMatch;
  }

  PartyGameMatchState endTurn({
    required PartyGameMatchState match,
    required String actorPlayerId,
  }) {
    _assertPlaying(match);
    _assertTurn(match, actorPlayerId);

    final updatedPlayers = Map<String, PartyGamePlayerState>.from(match.players);
    final currentPlayer = _requirePlayer(match, actorPlayerId);

    updatedPlayers[actorPlayerId] = currentPlayer.copyWith(
      cardsPlayedThisTurn: 0,
      characterCardsPlayedThisTurn: 0,
      eventCardsPlayedThisTurn: 0,
    );

    final currentIndex = match.playerOrder.indexOf(actorPlayerId);
    final nextIndex = (currentIndex + 1) % match.playerOrder.length;
    final nextPlayerId = match.playerOrder[nextIndex];

    if (nextPlayerId == match.startingPlayerIdOfRound) {
      return endRound(match: match.copyWith(players: updatedPlayers));
    }

    final nextPlayer = _requirePlayer(match.copyWith(players: updatedPlayers), nextPlayerId);

    if (nextPlayer.skipNextTurn) {
      updatedPlayers[nextPlayerId] = nextPlayer.copyWith(skipNextTurn: false);

      final skippedIndex = (nextIndex + 1) % match.playerOrder.length;
      return match.copyWith(
        players: updatedPlayers,
        turnPlayerId: match.playerOrder[skippedIndex],
      );
    }

    return match.copyWith(
      players: updatedPlayers,
      turnPlayerId: nextPlayerId,
    );
  }

  PartyGameMatchState endRound({
    required PartyGameMatchState match,
  }) {
    if (match.status != 'playing') return match;

    final nextRound = match.round + 1;
    final updatedPlayers = Map<String, PartyGamePlayerState>.from(match.players);

    for (final entry in updatedPlayers.entries) {
      final player = entry.value;
      updatedPlayers[entry.key] = player.copyWith(
        money: player.money + 8 + player.synergyState.moneyPerRoundBonus,
        cardsPlayedThisTurn: 0,
        characterCardsPlayedThisTurn: 0,
        eventCardsPlayedThisTurn: 0,
      );
    }

    final nextStarter = match.nextRoundStartingPlayerId ??
        _playerToRight(match.playerOrder, match.startingPlayerIdOfRound);

    var updatedMatch = match.copyWith(
      round: nextRound,
      status: nextRound > 6 ? 'finished' : 'playing',
      startingPlayerIdOfRound: nextStarter,
      turnPlayerId: nextStarter,
      players: updatedPlayers,
      nextRoundStartingPlayerId: null,
    );

    updatedMatch = _clearTemporaryRoundModifiers(updatedMatch);
    updatedMatch = _refreshAllScores(updatedMatch);

    return updatedMatch;
  }

  PartyGameMatchState _applyCardEffects({
    required PartyGameMatchState match,
    required String sourcePlayerId,
    required String sourceCardInstanceId,
    required List<CardEffectDefinition> effects,
    required String? targetPlayerId,
    required String? targetCharacterInstanceId,
    required String? chosenMode,
  }) {
    var updatedMatch = match;

    for (final effect in effects) {
      switch (effect.type) {
        case CardEffectType.gainMoney:
          updatedMatch = _changeMoney(
            updatedMatch,
            playerId: _resolveTargetPlayerId(sourcePlayerId, targetPlayerId, effect.targetMode),
            delta: effect.value ?? 0,
          );
          break;

        case CardEffectType.loseMoney:
          updatedMatch = _changeMoney(
            updatedMatch,
            playerId: _resolveTargetPlayerId(sourcePlayerId, targetPlayerId, effect.targetMode),
            delta: -(effect.value ?? 0),
          );
          break;

        case CardEffectType.gainScore:
          updatedMatch = _changePlayerScore(
            updatedMatch,
            playerId: _resolveTargetPlayerId(sourcePlayerId, targetPlayerId, effect.targetMode),
            delta: effect.value ?? 0,
          );
          break;

        case CardEffectType.loseScore:
          updatedMatch = _changePlayerScore(
            updatedMatch,
            playerId: _resolveTargetPlayerId(sourcePlayerId, targetPlayerId, effect.targetMode),
            delta: -(effect.value ?? 0),
          );
          break;

        case CardEffectType.gainScorePerTag:
          if (effect.tag == null) break;
          final playerId = _resolveTargetPlayerId(sourcePlayerId, targetPlayerId, effect.targetMode);
          final count = _countCharacterTag(
            updatedMatch,
            playerId: playerId,
            tag: effect.tag!,
          );
          updatedMatch = _changePlayerScore(
            updatedMatch,
            playerId: playerId,
            delta: count * (effect.value ?? 0),
          );
          break;

        case CardEffectType.gainScorePerEventTag:
          if (effect.tag == null) break;
          final playerId = _resolveTargetPlayerId(sourcePlayerId, targetPlayerId, effect.targetMode);
          final count = _countEventTag(
            updatedMatch,
            playerId: playerId,
            tag: effect.tag!,
          );
          updatedMatch = _changePlayerScore(
            updatedMatch,
            playerId: playerId,
            delta: count * (effect.value ?? 0),
          );
          break;

        case CardEffectType.killCharacter:
          if (targetCharacterInstanceId == null) {
            throw StateError('Falta personaje objetivo.');
          }
          updatedMatch = _killCharacter(updatedMatch, targetCharacterInstanceId);
          break;

        case CardEffectType.destroyEvent:
          if (targetCharacterInstanceId == null) {
            throw StateError('Falta evento objetivo.');
          }
          updatedMatch = _destroyEvent(updatedMatch, targetCharacterInstanceId);
          break;

        case CardEffectType.embargoCharacter:
          if (targetCharacterInstanceId == null) {
            throw StateError('Falta personaje objetivo.');
          }
          updatedMatch = _embargoCharacter(updatedMatch, targetCharacterInstanceId);
          break;

        case CardEffectType.silenceCharacter:
          if (targetCharacterInstanceId == null) {
            throw StateError('Falta personaje objetivo.');
          }
          updatedMatch = _silenceCharacter(updatedMatch, targetCharacterInstanceId);
          break;

        case CardEffectType.skipTurn:
          final playerId = _resolveTargetPlayerId(sourcePlayerId, targetPlayerId, effect.targetMode);
          updatedMatch = _setSkipTurn(updatedMatch, playerId, true);
          break;

        case CardEffectType.protectAgainstEvents:
          if (targetCharacterInstanceId != null) {
            updatedMatch = _addEventShield(
              updatedMatch,
              targetCharacterInstanceId,
              effect.value ?? 1,
            );
          }
          break;

        case CardEffectType.protectAgainstAdverseEvents:
          if (targetCharacterInstanceId != null) {
            updatedMatch = _addAdverseEventShield(
              updatedMatch,
              targetCharacterInstanceId,
              effect.value ?? 1,
            );
          }
          break;

        case CardEffectType.setCharacterScoreToZero:
          if (targetCharacterInstanceId == null) {
            throw StateError('Falta personaje objetivo.');
          }
          updatedMatch = _setCharacterScoreToZero(updatedMatch, targetCharacterInstanceId);
          break;

        case CardEffectType.setTaggedCharactersScoreToZero:
          if (effect.tag == null) break;
          updatedMatch = _setTaggedCharactersScoreToZero(updatedMatch, effect.tag!);
          break;

        case CardEffectType.nextRoundStarter:
          final playerId = _resolveTargetPlayerId(sourcePlayerId, targetPlayerId, effect.targetMode);
          updatedMatch = updatedMatch.copyWith(nextRoundStartingPlayerId: playerId);
          break;

        case CardEffectType.startOfRoundIncome:
          final playerId = _resolveTargetPlayerId(sourcePlayerId, targetPlayerId, effect.targetMode);
          updatedMatch = _addMoneyPerRoundBonus(updatedMatch, playerId, effect.value ?? 0);
          break;

        case CardEffectType.customScript:
          updatedMatch = _runCustomScript(
            updatedMatch,
            sourcePlayerId: sourcePlayerId,
            sourceCardInstanceId: sourceCardInstanceId,
            targetPlayerId: targetPlayerId,
            targetCharacterInstanceId: targetCharacterInstanceId,
            chosenMode: chosenMode,
            effect: effect,
          );
          break;

        default:
          break;
      }
    }

    return updatedMatch;
  }

  PartyGameMatchState _changeMoney(
    PartyGameMatchState match, {
    required String playerId,
    required int delta,
  }) {
    final player = _requirePlayer(match, playerId);
    return match.copyWith(
      players: Map<String, PartyGamePlayerState>.from(match.players)
        ..[playerId] = player.copyWith(money: player.money + delta),
    );
  }

  PartyGameMatchState _changePlayerScore(
    PartyGameMatchState match, {
    required String playerId,
    required int delta,
  }) {
    final player = _requirePlayer(match, playerId);
    return match.copyWith(
      players: Map<String, PartyGamePlayerState>.from(match.players)
        ..[playerId] = player.copyWith(score: player.score + delta),
    );
  }

  PartyGameMatchState _killCharacter(
    PartyGameMatchState match,
    String instanceId,
  ) {
    final card = match.cardsInPlay[instanceId];
    if (card == null) throw StateError('No existe la carta en mesa.');
    return match.copyWith(
      cardsInPlay: Map<String, PartyCardInPlay>.from(match.cardsInPlay)
        ..[instanceId] = card.copyWith(isDead: true),
    );
  }

  PartyGameMatchState _destroyEvent(
    PartyGameMatchState match,
    String instanceId,
  ) {
    final card = match.cardsInPlay[instanceId];
    if (card == null) throw StateError('No existe el evento en mesa.');
    return match.copyWith(
      cardsInPlay: Map<String, PartyCardInPlay>.from(match.cardsInPlay)
        ..[instanceId] = card.copyWith(isDead: true),
    );
  }

  PartyGameMatchState _embargoCharacter(
    PartyGameMatchState match,
    String instanceId,
  ) {
    final card = match.cardsInPlay[instanceId];
    if (card == null) throw StateError('No existe la carta en mesa.');
    return match.copyWith(
      cardsInPlay: Map<String, PartyCardInPlay>.from(match.cardsInPlay)
        ..[instanceId] = card.copyWith(isEmbargoed: true),
    );
  }

  PartyGameMatchState _silenceCharacter(
    PartyGameMatchState match,
    String instanceId,
  ) {
    final card = match.cardsInPlay[instanceId];
    if (card == null) throw StateError('No existe la carta en mesa.');
    return match.copyWith(
      cardsInPlay: Map<String, PartyCardInPlay>.from(match.cardsInPlay)
        ..[instanceId] = card.copyWith(isSilenced: true),
    );
  }

  PartyGameMatchState _addEventShield(
    PartyGameMatchState match,
    String instanceId,
    int amount,
  ) {
    final card = match.cardsInPlay[instanceId];
    if (card == null) throw StateError('No existe la carta en mesa.');
    return match.copyWith(
      cardsInPlay: Map<String, PartyCardInPlay>.from(match.cardsInPlay)
        ..[instanceId] = card.copyWith(
          eventShieldCharges: card.eventShieldCharges + amount,
        ),
    );
  }

  PartyGameMatchState _addAdverseEventShield(
    PartyGameMatchState match,
    String instanceId,
    int amount,
  ) {
    final card = match.cardsInPlay[instanceId];
    if (card == null) throw StateError('No existe la carta en mesa.');
    return match.copyWith(
      cardsInPlay: Map<String, PartyCardInPlay>.from(match.cardsInPlay)
        ..[instanceId] = card.copyWith(
          adverseEventShieldCharges: card.adverseEventShieldCharges + amount,
        ),
    );
  }

  PartyGameMatchState _setCharacterScoreToZero(
    PartyGameMatchState match,
    String instanceId,
  ) {
    final card = match.cardsInPlay[instanceId];
    if (card == null) throw StateError('No existe la carta en mesa.');

    return match.copyWith(
      cardsInPlay: Map<String, PartyCardInPlay>.from(match.cardsInPlay)
        ..[instanceId] = card.copyWith(baseScoreOverride: 0),
    );
  }

  PartyGameMatchState _setTaggedCharactersScoreToZero(
    PartyGameMatchState match,
    CardTag tag,
  ) {
    final updatedCards = Map<String, PartyCardInPlay>.from(match.cardsInPlay);

    for (final entry in updatedCards.entries) {
      final inPlay = entry.value;
      if (inPlay.isDead) continue;

      final def = catalog.byId(inPlay.definitionId);
      if (def == null) continue;
      if (def.type != PartyCardType.character) continue;
      if (!def.tags.contains(tag)) continue;

      updatedCards[entry.key] = inPlay.copyWith(baseScoreOverride: 0);
    }

    return match.copyWith(cardsInPlay: updatedCards);
  }

  PartyGameMatchState _setSkipTurn(
    PartyGameMatchState match,
    String playerId,
    bool value,
  ) {
    final player = _requirePlayer(match, playerId);
    return match.copyWith(
      players: Map<String, PartyGamePlayerState>.from(match.players)
        ..[playerId] = player.copyWith(skipNextTurn: value),
    );
  }

  PartyGameMatchState _addMoneyPerRoundBonus(
    PartyGameMatchState match,
    String playerId,
    int amount,
  ) {
    final player = _requirePlayer(match, playerId);

    return match.copyWith(
      players: Map<String, PartyGamePlayerState>.from(match.players)
        ..[playerId] = player.copyWith(
          synergyState: player.synergyState.copyWith(
            moneyPerRoundBonus: player.synergyState.moneyPerRoundBonus + amount,
          ),
        ),
    );
  }

  PartyGameMatchState _clearTemporaryRoundModifiers(PartyGameMatchState match) {
    final updatedCards = Map<String, PartyCardInPlay>.from(match.cardsInPlay);

    for (final entry in updatedCards.entries) {
      updatedCards[entry.key] = entry.value.copyWith(
        attachedTemporaryScore: 0,
      );
    }

    return match.copyWith(cardsInPlay: updatedCards);
  }

  PartyGameMatchState _refreshAllScores(PartyGameMatchState match) {
    final updatedPlayers = Map<String, PartyGamePlayerState>.from(match.players);

    for (final playerId in match.playerOrder) {
      final player = updatedPlayers[playerId];
      if (player == null) continue;

      final score = PartyGameScoreHelper.calculatePlayerScore(
        match: match.copyWith(players: updatedPlayers),
        playerId: playerId,
        catalog: catalog,
      );

      updatedPlayers[playerId] = player.copyWith(score: score);
    }

    return match.copyWith(players: updatedPlayers);
  }

  int _countCharacterTag(
    PartyGameMatchState match, {
    required String playerId,
    required CardTag tag,
  }) {
    final player = _requirePlayer(match, playerId);
    int count = 0;

    for (final instanceId in player.tableCharacterCardInstanceIds) {
      final inPlay = match.cardsInPlay[instanceId];
      if (inPlay == null || inPlay.isDead) continue;

      final def = catalog.byId(inPlay.definitionId);
      if (def == null) continue;
      if (def.tags.contains(tag)) count++;
    }

    return count;
  }

  int _countEventTag(
    PartyGameMatchState match, {
    required String playerId,
    required CardTag tag,
  }) {
    final player = _requirePlayer(match, playerId);
    int count = 0;

    for (final instanceId in player.tableEventCardInstanceIds) {
      final inPlay = match.cardsInPlay[instanceId];
      if (inPlay == null || inPlay.isDead) continue;

      final def = catalog.byId(inPlay.definitionId);
      if (def == null) continue;
      if (def.tags.contains(tag)) count++;
    }

    return count;
  }

  PartyGameMatchState _runCustomScript(
    PartyGameMatchState match, {
    required String sourcePlayerId,
    required String sourceCardInstanceId,
    required String? targetPlayerId,
    required String? targetCharacterInstanceId,
    required String? chosenMode,
    required CardEffectDefinition effect,
  }) {
    switch (effect.scriptId) {
      case 'coin_flip_each_round':
      case 'cycle_every_two_turns':
      case 'revive_after_two_rounds':
      default:
        return match;
    }
  }

  bool _canPlayCharacter(
    PartyGameMatchState match,
    PartyGamePlayerState player,
  ) {
    final maxCards = _maxCardsThisTurn(match.round);
    final maxCharacters = _maxCharactersThisTurn(match.round);

    return player.cardsPlayedThisTurn < maxCards &&
        player.characterCardsPlayedThisTurn < maxCharacters;
  }

  bool _canPlayEvent(
    PartyGameMatchState match,
    PartyGamePlayerState player,
  ) {
    final maxCards = _maxCardsThisTurn(match.round);
    return player.cardsPlayedThisTurn < maxCards;
  }

  int _maxCardsThisTurn(int round) {
    if (round == 2 || round == 4) return 3;
    if (round == 6) return 4;
    return 2;
  }

  int _maxCharactersThisTurn(int round) {
    if (round == 2 || round == 4) return 2;
    if (round == 6) return 3;
    return 1;
  }

  void _assertPlaying(PartyGameMatchState match) {
    if (match.status != 'playing') {
      throw StateError('La partida no está en estado playing.');
    }
  }

  void _assertTurn(PartyGameMatchState match, String actorPlayerId) {
    if (match.turnPlayerId != actorPlayerId) {
      throw StateError('No es el turno de ese jugador.');
    }
  }

  PartyGamePlayerState _requirePlayer(
    PartyGameMatchState match,
    String playerId,
  ) {
    final player = match.players[playerId];
    if (player == null) {
      throw StateError('No existe el jugador $playerId');
    }
    return player;
  }

  PartyCardDefinition _requireCard(String cardId) {
    final card = catalog.byId(cardId);
    if (card == null) {
      throw StateError('No existe la carta $cardId');
    }
    return card;
  }

  String _resolveTargetPlayerId(
    String sourcePlayerId,
    String? targetPlayerId,
    String? targetMode,
  ) {
    if (targetMode == 'self') return sourcePlayerId;
    return targetPlayerId ?? sourcePlayerId;
  }

  String _playerToRight(List<String> order, String playerId) {
    final index = order.indexOf(playerId);
    if (index == -1) return order.first;
    return order[(index + 1) % order.length];
  }

  String _newInstanceId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}