import '../models/dle_models.dart';

class DleCompareService {
  const DleCompareService();

  DleGuessRow compare<T extends DleEntry>({
    required T guess,
    required T target,
  }) {
    return DleGuessRow(
      guessId: guess.id,
      displayName: guess.displayName,
      nameState: guess.id == target.id ? DleCellState.correct : DleCellState.wrong,
      numericValue: guess.numericTarget,
      numericFeedback: _compareNumeric(
        guess.numericTarget,
        target.numericTarget,
      ),
      groupAValues: guess.textGroupA,
      groupAFeedback: _compareTextLists(
        guess.textGroupA,
        target.textGroupA,
      ),
      groupBValues: guess.textGroupB,
      groupBFeedback: _compareTextLists(
        guess.textGroupB,
        target.textGroupB,
      ),
      groupCValues: guess.textGroupC,
      groupCFeedback: _compareTextLists(
        guess.textGroupC,
        target.textGroupC,
      ),
    );
  }

  DleNumericFeedback _compareNumeric(int guessValue, int targetValue) {
    if (guessValue == targetValue) {
      return const DleNumericFeedback(
        state: DleCellState.correct,
        direction: DleNumericDirection.exact,
      );
    }

    if (guessValue < targetValue) {
      return const DleNumericFeedback(
        state: DleCellState.wrong,
        direction: DleNumericDirection.up,
      );
    }

    return const DleNumericFeedback(
      state: DleCellState.wrong,
      direction: DleNumericDirection.down,
    );
  }

  DleTextFeedback _compareTextLists(
    List<String> guessValues,
    List<String> targetValues,
  ) {
    final normalizedGuess = guessValues.map(_normalize).toSet();
    final normalizedTarget = targetValues.map(_normalize).toSet();
    final matches = normalizedGuess.intersection(normalizedTarget).toList();

    if (matches.isEmpty) {
      return const DleTextFeedback(
        state: DleCellState.wrong,
        matchedValues: [],
      );
    }

    if (normalizedGuess.length == normalizedTarget.length &&
        normalizedGuess.containsAll(normalizedTarget)) {
      return DleTextFeedback(
        state: DleCellState.correct,
        matchedValues: matches,
      );
    }

    return DleTextFeedback(
      state: DleCellState.partial,
      matchedValues: matches,
    );
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }
}