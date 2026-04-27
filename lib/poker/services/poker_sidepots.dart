import '../models/poker_state.dart';

class SidePot {
  SidePot({required this.amount, required this.eligibleProfileIds});

  final int amount;
  final List<String> eligibleProfileIds;

  Map<String, dynamic> toMap() => {
    "amount": amount,
    "eligible": eligibleProfileIds,
  };
}

class SidePotBuilder {
  static List<SidePot> build(List<PlayerState> players) {
    final levels = players.map((p) => p.totalCommitted).where((v) => v > 0).toSet().toList()..sort();
    if (levels.isEmpty) return [];

    final result = <SidePot>[];
    int prev = 0;

    for (final level in levels) {
      final layer = level - prev;
      if (layer <= 0) continue;

      final contributors = players.where((p) => p.totalCommitted >= level).toList();
      final amount = layer * contributors.length;

      final eligible = contributors
          .where((p) => p.inHand && !p.hasFolded)
          .map((p) => p.profileId)
          .toList();

      result.add(SidePot(amount: amount, eligibleProfileIds: eligible));
      prev = level;
    }

    return result;
  }
}
