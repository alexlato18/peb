import '../models/party_card_models.dart';
import '../models/party_game_match_models.dart';
import 'party_card_catalog.dart';

class PartyGameScoreHelper {
  static int calculatePlayerScore({
    required PartyGameMatchState match,
    required String playerId,
    required PartyCardCatalog catalog,
  }) {
    final player = match.players[playerId];
    if (player == null) return 0;

    int total = 0;

    total += player.synergyState.permanentScore;

    for (final instanceId in player.tableCharacterCardInstanceIds) {
      final inPlay = match.cardsInPlay[instanceId];
      if (inPlay == null) continue;
      if (inPlay.isDead) continue;
      if (inPlay.isEmbargoed) continue;

      final def = catalog.byId(inPlay.definitionId);
      if (def == null) continue;

      total += inPlay.baseScoreOverride ?? def.baseScore;
      total += inPlay.attachedPermanentScore;
      total += inPlay.attachedTemporaryScore;
    }

    for (final instanceId in player.tableEventCardInstanceIds) {
      final inPlay = match.cardsInPlay[instanceId];
      if (inPlay == null) continue;
      if (inPlay.isDead) continue;

      final def = catalog.byId(inPlay.definitionId);
      if (def == null) continue;

      total += def.baseScore;
      total += inPlay.attachedPermanentScore;
      total += inPlay.attachedTemporaryScore;
    }

    return total;
  }
}