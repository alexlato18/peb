enum PartyCardType {
  character,
  event,
}

enum CharacterOrigin {
  terreta,
  chiringuito,
  peb,
  barcelona,
  elx,
  norte,
  vegaBaja,
  sanvi,
  alicante,
  cartagena,
  linkedin,
}

enum CharacterClass {
  
  mioclub,
  cosisMalissimis,
  biotec,
  teamRocket,
  discord,
  korner,
  desfase1,
  ingeniero,
  festival,
  ggs,
  popurri,
  japenu,
  bubbles,
}

enum CardTag {
  male,
  female,
  legendary,

  monty,
  dani,
  juanma,
  maiki,
  peb,
  alfonso,
  paco,
  emilio,
  victor,
  pablo,
  enrique,
  chesco,
  sito,
  alex,
  fede,
  nino,
  ana,
  marina,
  pedro,
  quike,
  cabegos,
  virginia,
  yuri,
  antonio,
  sofia,
  leyre,
  monica,
  ainhoa,
  carol,
  izquierdo,
  paz,
  adrian,
  ferri,
  gracia,
  dini,
  gema,
  pepe,
  carmen,
  zahira,
  indira,
  ivan,
  palmi,
  fulle,
  javierico,
  fosetomas,
  mar,
  abel,
  pablohdz,

  bebida,
  bebidaAlcoholica,
  discoteca,
  festivalEvent,
  hogueras,
  generalEvent,
  adverseEvent,
  favorableEvent,
}

enum CardEffectType {
  gainMoney,
  loseMoney,
  loseScorelater,
  loseMoneylater,
  gainScorelater,
  gainMoneylater,
  gainScore,
  loseScore,
  gainScorePerTag,
  gainScorePerEventTag,
  killCharacter,
  destroyEvent,
  stealEvent,
  stealCharacterByPayingCost,
  embargoCharacter,
  silenceCharacter,
  reviveCharacter,
  skipTurn,
  forceDiscardEvent,
  revealHand,
  stealCardFromHand,
  protectAgainstEvents,
  protectAgainstAdverseEvents,
  copyCard,
  setCharacterScoreToZero,
  setTaggedCharactersScoreToZero,
  startOfRoundIncome,
  nextRoundStarter,
  modifyPlayableCardLimit,
  playExtraCharacter,
  playFreeEvent,
  playFreeCharacter,
  customScript,
}

class CardEffectDefinition {
  const CardEffectDefinition({
    required this.type,
    this.value,
    this.value2,
    this.durationRounds,
    this.targetMode,
    this.tag,
    this.characterClass,
    this.origin,
    this.scriptId,
    this.extra = const {},
    this.text = '',
  });

  final CardEffectType type;
  final int? value;
  final int? value2;
  final int? durationRounds;
  final String? targetMode;
  final CardTag? tag;
  final CharacterClass? characterClass;
  final CharacterOrigin? origin;
  final String? scriptId;
  final Map<String, dynamic> extra;
  final String text;
}

class PartyCardDefinition {
  const PartyCardDefinition({
    required this.id,
    required this.name,
    required this.type,
    required this.imageUrl,
    required this.cost,
    required this.baseScore,
    this.origin,
    this.characterClass,
    this.tags = const [],
    this.effects = const [],
    this.isLegendary = false,
  });

  final String id;
  final String name;
  final PartyCardType type;
  final String imageUrl;
  final int cost;
  final int baseScore;

  final CharacterOrigin? origin;
  final CharacterClass? characterClass;
  final List<CardTag> tags;
  final List<CardEffectDefinition> effects;
  final bool isLegendary;
}

class PartyCardInPlay {
  const PartyCardInPlay({
    required this.instanceId,
    required this.definitionId,
    required this.ownerPlayerId,
    required this.playedRound,
    this.baseScoreOverride,
    this.attachedPermanentScore = 0,
    this.attachedTemporaryScore = 0,
    this.isDead = false,
    this.isEmbargoed = false,
    this.isSilenced = false,
    this.eventShieldCharges = 0,
    this.adverseEventShieldCharges = 0,
    this.customData = const {},
  });

  final String instanceId;
  final String definitionId;
  final String ownerPlayerId;
  final int playedRound;

  final int? baseScoreOverride;
  final int attachedPermanentScore;
  final int attachedTemporaryScore;

  final bool isDead;
  final bool isEmbargoed;
  final bool isSilenced;

  final int eventShieldCharges;
  final int adverseEventShieldCharges;

  final Map<String, dynamic> customData;

  PartyCardInPlay copyWith({
    String? instanceId,
    String? definitionId,
    String? ownerPlayerId,
    int? playedRound,
    int? baseScoreOverride,
    int? attachedPermanentScore,
    int? attachedTemporaryScore,
    bool? isDead,
    bool? isEmbargoed,
    bool? isSilenced,
    int? eventShieldCharges,
    int? adverseEventShieldCharges,
    Map<String, dynamic>? customData,
  }) {
    return PartyCardInPlay(
      instanceId: instanceId ?? this.instanceId,
      definitionId: definitionId ?? this.definitionId,
      ownerPlayerId: ownerPlayerId ?? this.ownerPlayerId,
      playedRound: playedRound ?? this.playedRound,
      baseScoreOverride: baseScoreOverride ?? this.baseScoreOverride,
      attachedPermanentScore:
          attachedPermanentScore ?? this.attachedPermanentScore,
      attachedTemporaryScore:
          attachedTemporaryScore ?? this.attachedTemporaryScore,
      isDead: isDead ?? this.isDead,
      isEmbargoed: isEmbargoed ?? this.isEmbargoed,
      isSilenced: isSilenced ?? this.isSilenced,
      eventShieldCharges: eventShieldCharges ?? this.eventShieldCharges,
      adverseEventShieldCharges:
          adverseEventShieldCharges ?? this.adverseEventShieldCharges,
      customData: customData ?? this.customData,
    );
  }
}

class PartyGameSynergyState {
  const PartyGameSynergyState({
    this.triggeredKeys = const [],
    this.permanentScore = 0,
    this.moneyPerRoundBonus = 0,
    this.blockNextEvents = 0,
  });

  final List<String> triggeredKeys;
  final int permanentScore;
  final int moneyPerRoundBonus;
  final int blockNextEvents;

  PartyGameSynergyState copyWith({
    List<String>? triggeredKeys,
    int? permanentScore,
    int? moneyPerRoundBonus,
    int? blockNextEvents,
  }) {
    return PartyGameSynergyState(
      triggeredKeys: triggeredKeys ?? this.triggeredKeys,
      permanentScore: permanentScore ?? this.permanentScore,
      moneyPerRoundBonus: moneyPerRoundBonus ?? this.moneyPerRoundBonus,
      blockNextEvents: blockNextEvents ?? this.blockNextEvents,
    );
  }
}