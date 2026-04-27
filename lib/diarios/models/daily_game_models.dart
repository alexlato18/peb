import 'package:cloud_firestore/cloud_firestore.dart';

enum DailyGameId {
  wordle,
  sudoku,
  loldle,
  pokedle,
  queens,
  tango,
  zip,
  patches,
}

extension DailyGameIdX on DailyGameId {
  String get id {
    switch (this) {
      case DailyGameId.wordle:
        return 'wordle';
      case DailyGameId.sudoku:
        return 'sudoku';
      case DailyGameId.loldle:
        return 'loldle';
      case DailyGameId.pokedle:
        return 'pokedle';
      case DailyGameId.queens:
        return 'queens';
      case DailyGameId.tango:
        return 'tango';
      case DailyGameId.zip:
        return 'zip';
      case DailyGameId.patches:
        return 'patches';
    }
  }

  String get label {
    switch (this) {
      case DailyGameId.wordle:
        return 'Wordle';
      case DailyGameId.sudoku:
        return 'Sudoku';
      case DailyGameId.loldle:
        return 'Loldle';
      case DailyGameId.pokedle:
        return 'Pokedle';
      case DailyGameId.queens:
        return 'Queens';
      case DailyGameId.tango:
        return 'Tango';
      case DailyGameId.zip:
        return 'Zip';
      case DailyGameId.patches:
        return 'Patches';
    }
  }

  static DailyGameId fromId(String id) {
    switch (id) {
      case 'wordle':
        return DailyGameId.wordle;
      case 'sudoku':
        return DailyGameId.sudoku;
      case 'loldle':
        return DailyGameId.loldle;
      case 'pokedle':
        return DailyGameId.pokedle;
      case 'queens':
        return DailyGameId.queens;
      case 'tango':
        return DailyGameId.tango;
      case 'zip':
        return DailyGameId.zip;
      case 'patches':
        return DailyGameId.patches;
      default:
        throw ArgumentError('Juego no soportado: $id');
    }
  }
}

enum DailyMetricType {
  attempts,
  time,
}

extension DailyMetricTypeX on DailyMetricType {
  String get id {
    switch (this) {
      case DailyMetricType.attempts:
        return 'ATTEMPTS';
      case DailyMetricType.time:
        return 'TIME';
    }
  }

  static DailyMetricType fromId(String id) {
    switch (id) {
      case 'ATTEMPTS':
        return DailyMetricType.attempts;
      case 'TIME':
        return DailyMetricType.time;
      default:
        return DailyMetricType.time;
    }
  }
}

enum DailySessionStatus {
  notStarted,
  inProgress,
  completed,
}

extension DailySessionStatusX on DailySessionStatus {
  String get id {
    switch (this) {
      case DailySessionStatus.notStarted:
        return 'NOT_STARTED';
      case DailySessionStatus.inProgress:
        return 'IN_PROGRESS';
      case DailySessionStatus.completed:
        return 'COMPLETED';
    }
  }

  static DailySessionStatus fromId(String? id) {
    switch (id) {
      case 'NOT_STARTED':
        return DailySessionStatus.notStarted;
      case 'IN_PROGRESS':
        return DailySessionStatus.inProgress;
      case 'COMPLETED':
        return DailySessionStatus.completed;
      default:
        return DailySessionStatus.notStarted;
    }
  }
}

String dailyDateKey([DateTime? date]) {
  final d = date ?? DateTime.now();
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

DateTime parseDateKey(String dateKey) {
  final parts = dateKey.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String previousDateKey(String dateKey) {
  final d = parseDateKey(dateKey).subtract(const Duration(days: 1));
  return dailyDateKey(d);
}

class DailyGameCatalogItem {
  DailyGameCatalogItem({
    required this.id,
    required this.name,
    required this.metricType,
    required this.enabled,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final DailyMetricType metricType;
  final bool enabled;
  final int sortOrder;

  factory DailyGameCatalogItem.fromMap(String id, Map<String, dynamic> map) {
    return DailyGameCatalogItem(
      id: id,
      name: map['name'] as String? ?? id,
      metricType: DailyMetricTypeX.fromId(
        map['metricType'] as String? ?? 'TIME',
      ),
      enabled: map['enabled'] as bool? ?? true,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'metricType': metricType.id,
      'enabled': enabled,
      'sortOrder': sortOrder,
    };
  }
}

class DailyChallenge {
  DailyChallenge({
    required this.id,
    required this.gameId,
    required this.dateKey,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String gameId;
  final String dateKey;
  final Map<String, dynamic> payload;
  final Timestamp? createdAt;

  factory DailyChallenge.fromMap(String id, Map<String, dynamic> map) {
    return DailyChallenge(
      id: id,
      gameId: map['gameId'] as String? ?? '',
      dateKey: map['dateKey'] as String? ?? '',
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? const {}),
      createdAt: map['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gameId': gameId,
      'dateKey': dateKey,
      'payload': payload,
      'createdAt': createdAt,
    };
  }
}

class DailyGameSession {
  DailyGameSession({
    required this.id,
    required this.gameId,
    required this.dateKey,
    required this.profileId,
    required this.status,
    required this.startedAtMsUtc,
    required this.lastUpdatedAtMsUtc,
    required this.completedAtMsUtc,
    required this.accumulatedTimeMs,
    required this.activeStartedAtMsUtc,
    required this.attempts,
    required this.sessionData,
  });

  final String id;
  final String gameId;
  final String dateKey;
  final String profileId;
  final DailySessionStatus status;
  final int? startedAtMsUtc;
  final int? lastUpdatedAtMsUtc;
  final int? completedAtMsUtc;
  final int accumulatedTimeMs;
  final int? activeStartedAtMsUtc;
  final int attempts;
  final Map<String, dynamic> sessionData;

  bool get isCompleted => status == DailySessionStatus.completed;
  bool get isInProgress => status == DailySessionStatus.inProgress;

  factory DailyGameSession.fromMap(String id, Map<String, dynamic> map) {
    return DailyGameSession(
      id: id,
      gameId: map['gameId'] as String? ?? '',
      dateKey: map['dateKey'] as String? ?? '',
      profileId: map['profileId'] as String? ?? '',
      status: DailySessionStatusX.fromId(map['status'] as String?),
      startedAtMsUtc: (map['startedAtMsUtc'] as num?)?.toInt(),
      lastUpdatedAtMsUtc: (map['lastUpdatedAtMsUtc'] as num?)?.toInt(),
      completedAtMsUtc: (map['completedAtMsUtc'] as num?)?.toInt(),
      accumulatedTimeMs: (map['accumulatedTimeMs'] as num?)?.toInt() ?? 0,
      activeStartedAtMsUtc: (map['activeStartedAtMsUtc'] as num?)?.toInt(),
      attempts: (map['attempts'] as num?)?.toInt() ?? 0,
      sessionData: Map<String, dynamic>.from(
        map['sessionData'] as Map? ?? const {},
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gameId': gameId,
      'dateKey': dateKey,
      'profileId': profileId,
      'status': status.id,
      'startedAtMsUtc': startedAtMsUtc,
      'lastUpdatedAtMsUtc': lastUpdatedAtMsUtc,
      'completedAtMsUtc': completedAtMsUtc,
      'accumulatedTimeMs': accumulatedTimeMs,
      'activeStartedAtMsUtc': activeStartedAtMsUtc,
      'attempts': attempts,
      'sessionData': sessionData,
    };
  }
}

class DailyGameResult {
  DailyGameResult({
    required this.profileId,
    required this.displayName,
    required this.gameId,
    required this.dateKey,
    required this.attempts,
    required this.timeMs,
    required this.rankMetric,
    required this.completedAtMsUtc,
  });

  final String profileId;
  final String displayName;
  final String gameId;
  final String dateKey;
  final int attempts;
  final int timeMs;
  final int rankMetric;
  final int completedAtMsUtc;

  factory DailyGameResult.fromMap(Map<String, dynamic> map) {
    return DailyGameResult(
      profileId: map['profileId'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      gameId: map['gameId'] as String? ?? '',
      dateKey: map['dateKey'] as String? ?? '',
      attempts: (map['attempts'] as num?)?.toInt() ?? 0,
      timeMs: (map['timeMs'] as num?)?.toInt() ?? 0,
      rankMetric: (map['rankMetric'] as num?)?.toInt() ?? 0,
      completedAtMsUtc: (map['completedAtMsUtc'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'profileId': profileId,
      'displayName': displayName,
      'gameId': gameId,
      'dateKey': dateKey,
      'attempts': attempts,
      'timeMs': timeMs,
      'rankMetric': rankMetric,
      'completedAtMsUtc': completedAtMsUtc,
    };
  }
}

class DailyGameStats {
  DailyGameStats({
    required this.id,
    required this.profileId,
    required this.gameId,
    required this.currentStreak,
    required this.bestStreak,
    required this.completedCount,
    required this.lastCompletedDateKey,
    required this.averageAttempts,
    required this.averageTimeMs,
  });

  final String id;
  final String profileId;
  final String gameId;
  final int currentStreak;
  final int bestStreak;
  final int completedCount;
  final String? lastCompletedDateKey;
  final double averageAttempts;
  final double averageTimeMs;

  factory DailyGameStats.empty(String profileId, String gameId) {
    return DailyGameStats(
      id: '${profileId}_$gameId',
      profileId: profileId,
      gameId: gameId,
      currentStreak: 0,
      bestStreak: 0,
      completedCount: 0,
      lastCompletedDateKey: null,
      averageAttempts: 0,
      averageTimeMs: 0,
    );
  }

  factory DailyGameStats.fromMap(String id, Map<String, dynamic> map) {
    return DailyGameStats(
      id: id,
      profileId: map['profileId'] as String? ?? '',
      gameId: map['gameId'] as String? ?? '',
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      bestStreak: (map['bestStreak'] as num?)?.toInt() ?? 0,
      completedCount: (map['completedCount'] as num?)?.toInt() ?? 0,
      lastCompletedDateKey: map['lastCompletedDateKey'] as String?,
      averageAttempts: (map['averageAttempts'] as num?)?.toDouble() ?? 0,
      averageTimeMs: (map['averageTimeMs'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'profileId': profileId,
      'gameId': gameId,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'completedCount': completedCount,
      'lastCompletedDateKey': lastCompletedDateKey,
      'averageAttempts': averageAttempts,
      'averageTimeMs': averageTimeMs,
    };
  }
}