import '../models/party_card_models.dart';
import '../models/party_game_match_models.dart';
import 'party_card_catalog.dart';

class PartyGameSynergyResolver {
  PartyGameMatchState recalculateForPlayer({
    required PartyGameMatchState match,
    required String playerId,
    required PartyCardCatalog catalog,
  }) {
    final player = match.players[playerId];
    if (player == null) return match;

    final activeDefs = <PartyCardDefinition>[];

    for (final instanceId in player.tableCharacterCardInstanceIds) {
      final inPlay = match.cardsInPlay[instanceId];
      if (inPlay == null || inPlay.isDead) continue;

      final def = catalog.byId(inPlay.definitionId);
      if (def == null || def.type != PartyCardType.character) continue;

      activeDefs.add(def);
    }

    final originCounts = <CharacterOrigin, int>{};
    final classCounts = <CharacterClass, int>{};

    for (final def in activeDefs) {
      if (def.origin != null) {
        originCounts.update(def.origin!, (v) => v + 1, ifAbsent: () => 1);
      }
      if (def.characterClass != null) {
        classCounts.update(def.characterClass!, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    var synergy = player.synergyState;
    final triggered = synergy.triggeredKeys.toSet();

    void addPermanentScoreOnce(String key, int amount) {
      if (triggered.contains(key)) return;
      triggered.add(key);
      synergy = synergy.copyWith(
        triggeredKeys: triggered.toList(),
        permanentScore: synergy.permanentScore + amount,
      );
    }

    void addMoneyPerRoundOnce(String key, int amount) {
      if (triggered.contains(key)) return;
      triggered.add(key);
      synergy = synergy.copyWith(
        triggeredKeys: triggered.toList(),
        moneyPerRoundBonus: synergy.moneyPerRoundBonus + amount,
      );
    }

    void addBlockedEventsOnce(String key, int amount) {
      if (triggered.contains(key)) return;
      triggered.add(key);
      synergy = synergy.copyWith(
        triggeredKeys: triggered.toList(),
        blockNextEvents: synergy.blockNextEvents + amount,
      );
    }

    final sanvi = originCounts[CharacterOrigin.sanvi] ?? 0;
    if (sanvi >= 3) addPermanentScoreOnce('origin_sanvi_3', 3);
    if (sanvi >= 6) addPermanentScoreOnce('origin_sanvi_6', 6);

    final vegaBaja = originCounts[CharacterOrigin.vegaBaja] ?? 0;
    if (vegaBaja >= 2) addPermanentScoreOnce('origin_vegabaja_2', 4);
    if (vegaBaja >= 4) addPermanentScoreOnce('origin_vegabaja_4', 8);

    final alicante = originCounts[CharacterOrigin.alicante] ?? 0;
    if (alicante >= 2) addPermanentScoreOnce('origin_alicante_2', 4);
    if (alicante >= 3) addPermanentScoreOnce('origin_alicante_3', 6);
    if (alicante >= 4) addPermanentScoreOnce('origin_alicante_4', 10);

    final bubbles = classCounts[CharacterClass.bubbles] ?? 0;
    if (bubbles >= 3) addPermanentScoreOnce('class_bubbles_3', 4);
    if (bubbles >= 5) addPermanentScoreOnce('class_bubbles_5', 8);

    final cartagena = originCounts[CharacterOrigin.cartagena] ?? 0;
    if (cartagena >= 2) {
      addPermanentScoreOnce('origin_cartagena_2', 4);
      addMoneyPerRoundOnce('origin_cartagena_2_income', 3);
    }

    final linkedin = originCounts[CharacterOrigin.linkedin] ?? 0;
    if (linkedin >= 3) addMoneyPerRoundOnce('origin_linkedin_3', 2);
    if (linkedin >= 5) addMoneyPerRoundOnce('origin_linkedin_5', 6);

    final cosis = classCounts[CharacterClass.cosisMalissimis] ?? 0;
    if (cosis >= 3) addMoneyPerRoundOnce('class_cosis_3', 2);
    if (cosis >= 5) addMoneyPerRoundOnce('class_cosis_5', 6);

    final biotec = classCounts[CharacterClass.biotec] ?? 0;
    if (biotec >= 3) addPermanentScoreOnce('class_biotec_3', 4);
    if (biotec >= 5) addPermanentScoreOnce('class_biotec_5', 7);

    final discord = classCounts[CharacterClass.discord] ?? 0;
    if (discord >= 3) addPermanentScoreOnce('class_discord_3', 3);
    if (discord >= 5) addPermanentScoreOnce('class_discord_5', 8);

    final korner = classCounts[CharacterClass.korner] ?? 0;
    if (korner >= 3) addPermanentScoreOnce('class_korner_3', 3);
    if (korner >= 5) addPermanentScoreOnce('class_korner_5', 7);

    final desfase = classCounts[CharacterClass.desfase1] ?? 0;
    if (desfase >= 2) addMoneyPerRoundOnce('class_desfase_2', 2);
    if (desfase >= 4) addMoneyPerRoundOnce('class_desfase_4', 5);

    final festival = classCounts[CharacterClass.festival] ?? 0;
    if (festival >= 3) addPermanentScoreOnce('class_festival_3', 5);

    final teamRocket = classCounts[CharacterClass.teamRocket] ?? 0;
    if (teamRocket >= 2) addBlockedEventsOnce('class_teamrocket_2', 2);
    if (teamRocket >= 4) addBlockedEventsOnce('class_teamrocket_4', 4);

    final popurri = classCounts[CharacterClass.popurri] ?? 0;
    if (popurri >= 2) addBlockedEventsOnce('class_popurri_2', 2);
    if (popurri >= 5) addBlockedEventsOnce('class_popurri_5', 4);

    var updatedMatch = match;

    final ggs = classCounts[CharacterClass.ggs] ?? 0;
    if (ggs >= 2 && !triggered.contains('class_ggs_2')) {
      triggered.add('class_ggs_2');
      synergy = synergy.copyWith(triggeredKeys: triggered.toList());

      final updatedCards = Map<String, PartyCardInPlay>.from(updatedMatch.cardsInPlay);
      for (final instanceId in player.tableCharacterCardInstanceIds) {
        final inPlay = updatedCards[instanceId];
        if (inPlay == null || inPlay.isDead) continue;

        updatedCards[instanceId] = inPlay.copyWith(
          attachedPermanentScore: inPlay.attachedPermanentScore + 4,
        );
      }

      final updatedPlayers = Map<String, PartyGamePlayerState>.from(updatedMatch.players);
      updatedPlayers[playerId] = player.copyWith(synergyState: synergy);

      updatedMatch = updatedMatch.copyWith(
        players: updatedPlayers,
        cardsInPlay: updatedCards,
      );
    }

    final refreshedPlayer = updatedMatch.players[playerId]!;
    final finalPlayers = Map<String, PartyGamePlayerState>.from(updatedMatch.players);
    finalPlayers[playerId] = refreshedPlayer.copyWith(synergyState: synergy);

    return updatedMatch.copyWith(players: finalPlayers);
  }
}