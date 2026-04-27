enum PokerActionType { fold, check, call, raise }

class PokerAction {
  PokerAction({
    required this.type,
    this.raiseTo,
  });

  final PokerActionType type;
  final int? raiseTo; // total bet amount for this street (not increment)

  Map<String, dynamic> toMap() => {
        "type": type.name.toUpperCase(),
        "raiseTo": raiseTo,
      };

  static PokerAction fromMap(Map<String, dynamic> m) {
    final t = (m["type"] as String).toUpperCase();
    final type = switch (t) {
      "FOLD" => PokerActionType.fold,
      "CHECK" => PokerActionType.check,
      "CALL" => PokerActionType.call,
      _ => PokerActionType.raise,
    };
    return PokerAction(type: type, raiseTo: m["raiseTo"] as int?);
  }
}
