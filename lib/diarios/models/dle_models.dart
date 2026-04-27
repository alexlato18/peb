enum DleCellState {
  correct,
  partial,
  wrong,
}

extension DleCellStateX on DleCellState {
  String get id {
    switch (this) {
      case DleCellState.correct:
        return 'CORRECT';
      case DleCellState.partial:
        return 'PARTIAL';
      case DleCellState.wrong:
        return 'WRONG';
    }
  }

  static DleCellState fromId(String id) {
    switch (id) {
      case 'CORRECT':
        return DleCellState.correct;
      case 'PARTIAL':
        return DleCellState.partial;
      case 'WRONG':
      default:
        return DleCellState.wrong;
    }
  }
}

enum DleNumericDirection {
  exact,
  up,
  down,
}

extension DleNumericDirectionX on DleNumericDirection {
  String get id {
    switch (this) {
      case DleNumericDirection.exact:
        return 'EXACT';
      case DleNumericDirection.up:
        return 'UP';
      case DleNumericDirection.down:
        return 'DOWN';
    }
  }

  static DleNumericDirection fromId(String id) {
    switch (id) {
      case 'EXACT':
        return DleNumericDirection.exact;
      case 'UP':
        return DleNumericDirection.up;
      case 'DOWN':
        return DleNumericDirection.down;
      default:
        return DleNumericDirection.exact;
    }
  }
}

class DleNumericFeedback {
  const DleNumericFeedback({
    required this.state,
    required this.direction,
  });

  final DleCellState state;
  final DleNumericDirection direction;

  Map<String, dynamic> toMap() {
    return {
      'state': state.id,
      'direction': direction.id,
    };
  }

  factory DleNumericFeedback.fromMap(Map<String, dynamic> map) {
    return DleNumericFeedback(
      state: DleCellStateX.fromId(map['state'] as String? ?? 'WRONG'),
      direction: DleNumericDirectionX.fromId(map['direction'] as String? ?? 'EXACT'),
    );
  }
}

class DleTextFeedback {
  const DleTextFeedback({
    required this.state,
    required this.matchedValues,
  });

  final DleCellState state;
  final List<String> matchedValues;

  Map<String, dynamic> toMap() {
    return {
      'state': state.id,
      'matchedValues': matchedValues,
    };
  }

  factory DleTextFeedback.fromMap(Map<String, dynamic> map) {
    return DleTextFeedback(
      state: DleCellStateX.fromId(map['state'] as String? ?? 'WRONG'),
      matchedValues: List<String>.from(map['matchedValues'] as List? ?? const []),
    );
  }
}

abstract class DleEntry {
  String get id;
  String get displayName;
  int get numericTarget;
  List<String> get textGroupA;
  List<String> get textGroupB;
  List<String> get textGroupC;
}

class DleGuessRow {
  const DleGuessRow({
    required this.guessId,
    required this.displayName,
    required this.nameState,
    required this.numericValue,
    required this.numericFeedback,
    required this.groupAValues,
    required this.groupAFeedback,
    required this.groupBValues,
    required this.groupBFeedback,
    required this.groupCValues,
    required this.groupCFeedback,
  });

  final String guessId;
  final String displayName;
  final DleCellState nameState;
  final int numericValue;
  final DleNumericFeedback numericFeedback;
  final List<String> groupAValues;
  final DleTextFeedback groupAFeedback;
  final List<String> groupBValues;
  final DleTextFeedback groupBFeedback;
  final List<String> groupCValues;
  final DleTextFeedback groupCFeedback;

  Map<String, dynamic> toMap() {
    return {
      'guessId': guessId,
      'displayName': displayName,
      'nameState': nameState.id,
      'numericValue': numericValue,
      'numericFeedback': numericFeedback.toMap(),
      'groupAValues': groupAValues,
      'groupAFeedback': groupAFeedback.toMap(),
      'groupBValues': groupBValues,
      'groupBFeedback': groupBFeedback.toMap(),
      'groupCValues': groupCValues,
      'groupCFeedback': groupCFeedback.toMap(),
    };
  }

  factory DleGuessRow.fromMap(Map<String, dynamic> map) {
    return DleGuessRow(
      guessId: map['guessId'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      nameState: DleCellStateX.fromId(map['nameState'] as String? ?? 'WRONG'),
      numericValue: (map['numericValue'] as num?)?.toInt() ?? 0,
      numericFeedback: DleNumericFeedback.fromMap(
        Map<String, dynamic>.from(map['numericFeedback'] as Map? ?? const {}),
      ),
      groupAValues: List<String>.from(map['groupAValues'] as List? ?? const []),
      groupAFeedback: DleTextFeedback.fromMap(
        Map<String, dynamic>.from(map['groupAFeedback'] as Map? ?? const {}),
      ),
      groupBValues: List<String>.from(map['groupBValues'] as List? ?? const []),
      groupBFeedback: DleTextFeedback.fromMap(
        Map<String, dynamic>.from(map['groupBFeedback'] as Map? ?? const {}),
      ),
      groupCValues: List<String>.from(map['groupCValues'] as List? ?? const []),
      groupCFeedback: DleTextFeedback.fromMap(
        Map<String, dynamic>.from(map['groupCFeedback'] as Map? ?? const {}),
      ),
    );
  }
}