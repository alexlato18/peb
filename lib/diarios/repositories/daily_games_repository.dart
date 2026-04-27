import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:peb/diarios/models/dle_models.dart';
import 'package:peb/diarios/models/loldle_entry.dart';
import 'package:peb/diarios/models/pokedle_entry.dart';
import 'package:peb/diarios/repositories/dle_data_repository.dart';
import 'package:peb/diarios/services/dle_compare_service.dart';
import 'package:peb/services/daily_addict_tag_service.dart';

import '../../data/profile_repository.dart';
import '../models/daily_game_models.dart';

class WordleSubmitResult {
  WordleSubmitResult({
    required this.ok,
    required this.message,
    required this.solved,
  });

  final bool ok;
  final String? message;
  final bool solved;
}

class DleSubmitResult {
  DleSubmitResult({
    required this.ok,
    required this.message,
    required this.solved,
  });

  final bool ok;
  final String? message;
  final bool solved;
}

class DailyGamesRepository {
  DailyGamesRepository(
    this._db,
    this._functions,
    this._profileRepository,
  );

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final ProfileRepository _profileRepository;

  final DleDataRepository _dleDataRepository = const DleDataRepository();
  final DleCompareService _dleCompareService = const DleCompareService();

  DocumentReference<Map<String, dynamic>> get _groupDoc =>
      _db.collection('groups').doc('peb');

  CollectionReference<Map<String, dynamic>> get _catalogCol =>
      _groupDoc.collection('daily_games_catalog');

  CollectionReference<Map<String, dynamic>> get _challengesCol =>
      _groupDoc.collection('daily_game_challenges');

  CollectionReference<Map<String, dynamic>> get _sessionsCol =>
      _groupDoc.collection('daily_game_sessions');

  CollectionReference<Map<String, dynamic>> get _resultsRootCol =>
      _groupDoc.collection('daily_game_results');

  CollectionReference<Map<String, dynamic>> get _statsCol =>
      _groupDoc.collection('daily_game_stats');

  Future<void> seedCatalogIfNeeded() async {
    final batch = _db.batch();

    batch.set(_catalogCol.doc(DailyGameId.wordle.id), {
      'name': 'Wordle',
      'metricType': DailyMetricType.attempts.id,
      'enabled': true,
      'sortOrder': 1,
    }, SetOptions(merge: true));

    batch.set(_catalogCol.doc(DailyGameId.sudoku.id), {
      'name': 'Sudoku',
      'metricType': DailyMetricType.time.id,
      'enabled': true,
      'sortOrder': 2,
    }, SetOptions(merge: true));

    batch.set(_catalogCol.doc(DailyGameId.loldle.id), {
      'name': 'Loldle',
      'metricType': DailyMetricType.attempts.id,
      'enabled': true,
      'sortOrder': 3,
    }, SetOptions(merge: true));

    batch.set(_catalogCol.doc(DailyGameId.pokedle.id), {
      'name': 'Pokedle',
      'metricType': DailyMetricType.attempts.id,
      'enabled': true,
      'sortOrder': 4,
    }, SetOptions(merge: true));

    batch.set(_catalogCol.doc(DailyGameId.queens.id), {
      'name': 'Queens',
      'metricType': DailyMetricType.time.id,
      'enabled': true,
      'sortOrder': 5,
    }, SetOptions(merge: true));

    batch.set(_catalogCol.doc(DailyGameId.tango.id), {
      'name': 'Tango',
      'metricType': DailyMetricType.time.id,
      'enabled': true,
      'sortOrder': 6,
    }, SetOptions(merge: true));

    batch.set(_catalogCol.doc(DailyGameId.zip.id), {
      'name': 'Zip',
      'metricType': DailyMetricType.time.id,
      'enabled': true,
      'sortOrder': 7,
    }, SetOptions(merge: true));

    batch.set(_catalogCol.doc(DailyGameId.patches.id), {
      'name': 'Patches',
      'metricType': DailyMetricType.time.id,
      'enabled': true,
      'sortOrder': 8,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> ensureTodayChallenges() async {
    await seedCatalogIfNeeded();

    final res = await _functions.httpsCallable('ensureTodayDailyGames').call();
    debugPrint('ensureTodayDailyGames response: ${res.data}');

    final data = Map<String, dynamic>.from(res.data as Map);
    if (data['ok'] != true) {
      throw Exception('Falló ensureTodayDailyGames: ${data['failed']}');
    }
  }

  Stream<List<DailyGameCatalogItem>> watchCatalog() {
    return _catalogCol.orderBy('sortOrder').snapshots().map((snap) {
      return snap.docs
          .map((d) => DailyGameCatalogItem.fromMap(d.id, d.data()))
          .where((e) => e.enabled)
          .toList();
    });
  }

  Stream<DailyChallenge?> watchTodayChallenge(String gameId) {
    final id = '${gameId}_${dailyDateKey()}';
    return _challengesCol.doc(id).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return DailyChallenge.fromMap(doc.id, data);
    });
  }

  Stream<DailyGameSession?> watchTodaySession(String gameId, String profileId) {
    final id = '${gameId}_${dailyDateKey()}_$profileId';
    return _sessionsCol.doc(id).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return DailyGameSession.fromMap(doc.id, data);
    });
  }

  Stream<DailyGameStats> watchStats(String gameId, String profileId) {
    final id = '${profileId}_$gameId';
    return _statsCol.doc(id).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) {
        return DailyGameStats.empty(profileId, gameId);
      }
      return DailyGameStats.fromMap(doc.id, data);
    });
  }

  Stream<List<DailyGameResult>> watchTodayRanking(String gameId) {
    final rootId = '${gameId}_${dailyDateKey()}';
    return _resultsRootCol.doc(rootId).collection('entries').snapshots().map((
      snap,
    ) {
      final items = snap.docs.map((d) => DailyGameResult.fromMap(d.data())).toList();

      items.sort((a, b) {
        final cmpMetric = a.rankMetric.compareTo(b.rankMetric);
        if (cmpMetric != 0) return cmpMetric;

        final cmpTime = a.timeMs.compareTo(b.timeMs);
        if (cmpTime != 0) return cmpTime;

        return a.completedAtMsUtc.compareTo(b.completedAtMsUtc);
      });

      return items;
    });
  }

  Future<DailyGameSession> startOrResumeSession({
    required String gameId,
    required String profileId,
  }) async {
    await ensureTodayChallenges();

    final challengeId = '${gameId}_${dailyDateKey()}';
    final challengeDoc = await _challengesCol.doc(challengeId).get();

    debugPrint('Buscando challengeId: $challengeId');
    debugPrint('Challenge exists: ${challengeDoc.exists}');
    debugPrint('Challenge data: ${challengeDoc.data()}');

    final data = challengeDoc.data();
    if (!challengeDoc.exists || data == null) {
      throw Exception('No existe el reto diario esperado: $challengeId');
    }

    final challenge = DailyChallenge.fromMap(challengeDoc.id, data);

    final sessionId = '${gameId}_${dailyDateKey()}_$profileId';
    final sessionRef = _sessionsCol.doc(sessionId);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    final existing = await sessionRef.get();
    if (existing.exists && existing.data() != null) {
      final session = DailyGameSession.fromMap(existing.id, existing.data()!);

      if (!session.isCompleted && session.activeStartedAtMsUtc == null) {
        await sessionRef.set({
          'status': DailySessionStatus.inProgress.id,
          'lastUpdatedAtMsUtc': now,
          'activeStartedAtMsUtc': now,
        }, SetOptions(merge: true));
      }

      final fresh = await sessionRef.get();
      final freshData = fresh.data();
      if (!fresh.exists || freshData == null) {
        throw Exception('No se pudo recuperar la sesión diaria: $sessionId');
      }

      return DailyGameSession.fromMap(fresh.id, freshData);
    }

    final sessionData = _initialSessionDataForGame(
      gameId: gameId,
      challenge: challenge,
    );

    final newSession = DailyGameSession(
      id: sessionId,
      gameId: gameId,
      dateKey: dailyDateKey(),
      profileId: profileId,
      status: DailySessionStatus.inProgress,
      startedAtMsUtc: now,
      lastUpdatedAtMsUtc: now,
      completedAtMsUtc: null,
      accumulatedTimeMs: 0,
      activeStartedAtMsUtc: now,
      attempts: 0,
      sessionData: sessionData,
    );

    await sessionRef.set(newSession.toMap());
    return newSession;
  }

  Map<String, dynamic> _initialSessionDataForGame({
    required String gameId,
    required DailyChallenge challenge,
  }) {
    if (gameId == DailyGameId.wordle.id) {
      return {
        'guesses': <String>[],
        'currentInput': '',
      };
    }

    if (gameId == DailyGameId.sudoku.id) {
      final puzzle = challenge.payload['puzzle'] as String? ?? '';
      return {
        'currentBoard': puzzle,
        'selectedIndex': -1,
      };
    }

    if (gameId == DailyGameId.loldle.id || gameId == DailyGameId.pokedle.id) {
      return {
        'guessIds': <String>[],
        'rows': <Map<String, dynamic>>[],
      };
    }

    if (gameId == DailyGameId.queens.id) {
      return {
        'queens': <String>[],
        'marks': <String>[],
      };
    }

    if (gameId == DailyGameId.tango.id) {
      final rawRows =
          List<String>.from(challenge.payload['initialBoardRows'] as List? ?? const []);
      return {
        'currentBoardRows': rawRows,
      };
    }

    if (gameId == DailyGameId.zip.id) {
      return {
        'path': <Map<String, dynamic>>[],
      };
    }

    if (gameId == DailyGameId.patches.id) {
      return {
        'placements': <String, dynamic>{},
      };
    }

    return {};
  }

  Future<void> pauseSession({
    required String gameId,
    required String profileId,
  }) async {
    final sessionId = '${gameId}_${dailyDateKey()}_$profileId';
    final sessionRef = _sessionsCol.doc(sessionId);
    final doc = await sessionRef.get();

    if (!doc.exists || doc.data() == null) return;

    final session = DailyGameSession.fromMap(doc.id, doc.data()!);
    if (session.isCompleted) return;
    if (session.activeStartedAtMsUtc == null) return;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final delta = now - session.activeStartedAtMsUtc!;
    final nextAccumulated = session.accumulatedTimeMs + (delta > 0 ? delta : 0);

    await sessionRef.set({
      'accumulatedTimeMs': nextAccumulated,
      'activeStartedAtMsUtc': null,
      'lastUpdatedAtMsUtc': now,
      'status': DailySessionStatus.inProgress.id,
    }, SetOptions(merge: true));
  }

  Future<void> saveWordleCurrentInput({
    required String profileId,
    required String input,
  }) async {
    final sessionId = '${DailyGameId.wordle.id}_${dailyDateKey()}_$profileId';
    await _sessionsCol.doc(sessionId).set({
      'sessionData': {
        'currentInput': input.toUpperCase(),
      },
    }, SetOptions(merge: true));
  }

  Future<WordleSubmitResult> submitWordleGuess({
    required String profileId,
    required String guess,
  }) async {
    final gameId = DailyGameId.wordle.id;
    final challengeId = '${gameId}_${dailyDateKey()}';
    final sessionId = '${gameId}_${dailyDateKey()}_$profileId';

    final challengeDoc = await _challengesCol.doc(challengeId).get();
    final sessionDoc = await _sessionsCol.doc(sessionId).get();

    if (!challengeDoc.exists || challengeDoc.data() == null) {
      return WordleSubmitResult(
        ok: false,
        message: 'No existe reto de hoy.',
        solved: false,
      );
    }

    if (!sessionDoc.exists || sessionDoc.data() == null) {
      await startOrResumeSession(gameId: gameId, profileId: profileId);
      return submitWordleGuess(profileId: profileId, guess: guess);
    }

    final challenge = DailyChallenge.fromMap(
      challengeDoc.id,
      challengeDoc.data()!,
    );
    final session = DailyGameSession.fromMap(sessionDoc.id, sessionDoc.data()!);

    if (session.isCompleted) {
      return WordleSubmitResult(
        ok: false,
        message: 'Ya has completado el Wordle de hoy.',
        solved: true,
      );
    }

    final cleanGuess = guess.trim().toUpperCase();
    final solution = (challenge.payload['solution'] as String? ?? '').toUpperCase();
    final wordLength = (challenge.payload['wordLength'] as num?)?.toInt() ?? 5;

    if (cleanGuess.length != wordLength) {
      return WordleSubmitResult(
        ok: false,
        message: 'La palabra debe tener $wordLength letras.',
        solved: false,
      );
    }

    final regex = RegExp(r'^[A-ZÁÉÍÓÚÜÑ]+$');
    if (!regex.hasMatch(cleanGuess)) {
      return WordleSubmitResult(
        ok: false,
        message: 'Solo se permiten letras.',
        solved: false,
      );
    }

    final guesses = List<String>.from(
      session.sessionData['guesses'] as List? ?? const [],
    );
    guesses.add(cleanGuess);

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _sessionsCol.doc(sessionId).set({
      'attempts': guesses.length,
      'lastUpdatedAtMsUtc': now,
      'sessionData': {
        'guesses': guesses,
        'currentInput': '',
      },
      'status': DailySessionStatus.inProgress.id,
    }, SetOptions(merge: true));

    final solved = cleanGuess == solution;
    if (solved) {
      await _completeGame(
        gameId: gameId,
        profileId: profileId,
        attempts: guesses.length,
      );
    }

    return WordleSubmitResult(
      ok: true,
      message: null,
      solved: solved,
    );
  }

  Future<void> saveSudokuProgress({
    required String profileId,
    required String currentBoard,
    required int selectedIndex,
  }) async {
    final gameId = DailyGameId.sudoku.id;
    final challengeId = '${gameId}_${dailyDateKey()}';
    final sessionId = '${gameId}_${dailyDateKey()}_$profileId';

    final challengeDoc = await _challengesCol.doc(challengeId).get();
    final sessionDoc = await _sessionsCol.doc(sessionId).get();

    if (!challengeDoc.exists || challengeDoc.data() == null) return;
    if (!sessionDoc.exists || sessionDoc.data() == null) {
      await startOrResumeSession(gameId: gameId, profileId: profileId);
      return saveSudokuProgress(
        profileId: profileId,
        currentBoard: currentBoard,
        selectedIndex: selectedIndex,
      );
    }

    final challenge = DailyChallenge.fromMap(
      challengeDoc.id,
      challengeDoc.data()!,
    );
    final session = DailyGameSession.fromMap(sessionDoc.id, sessionDoc.data()!);

    if (session.isCompleted) return;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _sessionsCol.doc(sessionId).set({
      'lastUpdatedAtMsUtc': now,
      'sessionData': {
        'currentBoard': currentBoard,
        'selectedIndex': selectedIndex,
      },
      'status': DailySessionStatus.inProgress.id,
    }, SetOptions(merge: true));

    final solution = challenge.payload['solution'] as String? ?? '';
    if (currentBoard == solution) {
      await _completeGame(
        gameId: gameId,
        profileId: profileId,
        attempts: 0,
      );
    }
  }

  Future<DleSubmitResult> submitLoldleGuess({
    required String profileId,
    required String guessId,
  }) async {
    return _submitDleGuess<LoldleEntry>(
      gameId: DailyGameId.loldle.id,
      profileId: profileId,
      guessId: guessId,
      findEntryById: _dleDataRepository.findLolById,
    );
  }

  Future<DleSubmitResult> submitPokedleGuess({
    required String profileId,
    required String guessId,
  }) async {
    return _submitDleGuess<PokedleEntry>(
      gameId: DailyGameId.pokedle.id,
      profileId: profileId,
      guessId: guessId,
      findEntryById: _dleDataRepository.findPokemonById,
    );
  }

  Future<DleSubmitResult> _submitDleGuess<T extends DleEntry>({
    required String gameId,
    required String profileId,
    required String guessId,
    required T? Function(String id) findEntryById,
  }) async {
    final challengeId = '${gameId}_${dailyDateKey()}';
    final sessionId = '${gameId}_${dailyDateKey()}_$profileId';

    final challengeDoc = await _challengesCol.doc(challengeId).get();
    final sessionDoc = await _sessionsCol.doc(sessionId).get();

    if (!challengeDoc.exists || challengeDoc.data() == null) {
      return DleSubmitResult(
        ok: false,
        message: 'No existe reto de hoy.',
        solved: false,
      );
    }

    if (!sessionDoc.exists || sessionDoc.data() == null) {
      await startOrResumeSession(gameId: gameId, profileId: profileId);
      return _submitDleGuess<T>(
        gameId: gameId,
        profileId: profileId,
        guessId: guessId,
        findEntryById: findEntryById,
      );
    }

    final challenge = DailyChallenge.fromMap(
      challengeDoc.id,
      challengeDoc.data()!,
    );
    final session = DailyGameSession.fromMap(sessionDoc.id, sessionDoc.data()!);

    if (session.isCompleted) {
      return DleSubmitResult(
        ok: false,
        message: 'Ya has completado este juego hoy.',
        solved: true,
      );
    }

    final targetId = challenge.payload['targetId'] as String? ?? '';
    final guessEntry = findEntryById(guessId);
    final targetEntry = findEntryById(targetId);

    if (guessEntry == null || targetEntry == null) {
      return DleSubmitResult(
        ok: false,
        message: 'No se han encontrado los datos del intento o del objetivo.',
        solved: false,
      );
    }

    final currentGuessIds = List<String>.from(
      session.sessionData['guessIds'] as List? ?? const [],
    );
    final currentRowsRaw = List<Map<String, dynamic>>.from(
      session.sessionData['rows'] as List? ?? const [],
    );

    final alreadyGuessed = currentGuessIds.contains(guessId);
    if (alreadyGuessed) {
      return DleSubmitResult(
        ok: false,
        message: 'Ese personaje ya ha sido probado.',
        solved: false,
      );
    }

    final row = _dleCompareService.compare<T>(
      guess: guessEntry,
      target: targetEntry,
    );

    currentGuessIds.add(guessId);
    currentRowsRaw.add(row.toMap());

    final attempts = currentGuessIds.length;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _sessionsCol.doc(sessionId).set({
      'attempts': attempts,
      'lastUpdatedAtMsUtc': now,
      'sessionData': {
        'guessIds': currentGuessIds,
        'rows': currentRowsRaw,
      },
      'status': DailySessionStatus.inProgress.id,
    }, SetOptions(merge: true));

    final solved = guessId == targetId;
    if (solved) {
      await _completeGame(
        gameId: gameId,
        profileId: profileId,
        attempts: attempts,
      );
    }

    return DleSubmitResult(
      ok: true,
      message: null,
      solved: solved,
    );
  }

  Future<void> saveQueensProgress({
    required String profileId,
    required List<String> queens,
    required List<String> marks,
  }) async {
    final gameId = DailyGameId.queens.id;
    final challengeId = '${gameId}_${dailyDateKey()}';
    final sessionId = '${gameId}_${dailyDateKey()}_$profileId';

    final challengeDoc = await _challengesCol.doc(challengeId).get();
    final sessionDoc = await _sessionsCol.doc(sessionId).get();

    if (!challengeDoc.exists || challengeDoc.data() == null) return;

    if (!sessionDoc.exists || sessionDoc.data() == null) {
      await startOrResumeSession(gameId: gameId, profileId: profileId);
      return saveQueensProgress(
        profileId: profileId,
        queens: queens,
        marks: marks,
      );
    }

    final challenge = DailyChallenge.fromMap(
      challengeDoc.id,
      challengeDoc.data()!,
    );
    final session = DailyGameSession.fromMap(sessionDoc.id, sessionDoc.data()!);

    if (session.isCompleted) return;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _sessionsCol.doc(sessionId).set({
      'lastUpdatedAtMsUtc': now,
      'sessionData': {
        'queens': queens,
        'marks': marks,
      },
      'status': DailySessionStatus.inProgress.id,
    }, SetOptions(merge: true));

    final solutionRaw = List<Map<String, dynamic>>.from(
      challenge.payload['solution'] as List? ?? const [],
    );

    final solutionCells = solutionRaw
        .map((e) => '${e['row']}_${e['col']}')
        .toSet();

    final queensSet = queens.toSet();

    if (queensSet.length == solutionCells.length &&
        queensSet.containsAll(solutionCells) &&
        solutionCells.containsAll(queensSet)) {
      await _completeGame(
        gameId: gameId,
        profileId: profileId,
        attempts: 0,
      );
    }
  }

  Future<void> saveTangoProgress({
    required String profileId,
    required List<List<int?>> currentBoard,
  }) async {
    final gameId = DailyGameId.tango.id;
    final challengeId = '${gameId}_${dailyDateKey()}';
    final sessionId = '${gameId}_${dailyDateKey()}_$profileId';

    final challengeDoc = await _challengesCol.doc(challengeId).get();
    final sessionDoc = await _sessionsCol.doc(sessionId).get();

    if (!challengeDoc.exists || challengeDoc.data() == null) return;

    if (!sessionDoc.exists || sessionDoc.data() == null) {
      await startOrResumeSession(gameId: gameId, profileId: profileId);
      return saveTangoProgress(
        profileId: profileId,
        currentBoard: currentBoard,
      );
    }

    final challenge = DailyChallenge.fromMap(
      challengeDoc.id,
      challengeDoc.data()!,
    );
    final session = DailyGameSession.fromMap(sessionDoc.id, sessionDoc.data()!);

    if (session.isCompleted) return;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final currentBoardRows = _encodeNullableIntGridRows(currentBoard);

    await _sessionsCol.doc(sessionId).set({
      'lastUpdatedAtMsUtc': now,
      'sessionData': {
        'currentBoardRows': currentBoardRows,
      },
      'status': DailySessionStatus.inProgress.id,
    }, SetOptions(merge: true));

    final solutionRows =
        List<String>.from(challenge.payload['solutionRows'] as List? ?? const []);
    final solutionBoard = _parseNullableIntGridRows(solutionRows);

    if (_boardsEqual(currentBoard, solutionBoard)) {
      await _completeGame(
        gameId: gameId,
        profileId: profileId,
        attempts: 0,
      );
    }
  }

  Future<void> saveZipProgress({
    required String profileId,
    required List<Map<String, int>> path,
  }) async {
    final gameId = DailyGameId.zip.id;
    final challengeId = '${gameId}_${dailyDateKey()}';
    final sessionId = '${gameId}_${dailyDateKey()}_$profileId';

    final challengeDoc = await _challengesCol.doc(challengeId).get();
    final sessionDoc = await _sessionsCol.doc(sessionId).get();

    if (!challengeDoc.exists || challengeDoc.data() == null) return;

    if (!sessionDoc.exists || sessionDoc.data() == null) {
      await startOrResumeSession(gameId: gameId, profileId: profileId);
      return saveZipProgress(profileId: profileId, path: path);
    }

    final challenge = DailyChallenge.fromMap(
      challengeDoc.id,
      challengeDoc.data()!,
    );
    final session = DailyGameSession.fromMap(sessionDoc.id, sessionDoc.data()!);

    if (session.isCompleted) return;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _sessionsCol.doc(sessionId).set({
      'lastUpdatedAtMsUtc': now,
      'sessionData': {
        'path': path,
      },
      'status': DailySessionStatus.inProgress.id,
    }, SetOptions(merge: true));

    final solutionPath = List<Map<String, dynamic>>.from(
      challenge.payload['solutionPath'] as List? ?? const [],
    );

    if (_pathEquals(path, solutionPath)) {
      await _completeGame(
        gameId: gameId,
        profileId: profileId,
        attempts: 0,
      );
    }
  }

  Future<void> savePatchesProgress({
    required String profileId,
    required Map<String, Map<String, int>> placements,
  }) async {
    final gameId = DailyGameId.patches.id;
    final challengeId = '${gameId}_${dailyDateKey()}';
    final sessionId = '${gameId}_${dailyDateKey()}_$profileId';

    final challengeDoc = await _challengesCol.doc(challengeId).get();
    final sessionDoc = await _sessionsCol.doc(sessionId).get();

    if (!challengeDoc.exists || challengeDoc.data() == null) return;

    if (!sessionDoc.exists || sessionDoc.data() == null) {
      await startOrResumeSession(gameId: gameId, profileId: profileId);
      return savePatchesProgress(
        profileId: profileId,
        placements: placements,
      );
    }

    final challenge = DailyChallenge.fromMap(
      challengeDoc.id,
      challengeDoc.data()!,
    );
    final session = DailyGameSession.fromMap(sessionDoc.id, sessionDoc.data()!);

    if (session.isCompleted) return;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _sessionsCol.doc(sessionId).set({
      'lastUpdatedAtMsUtc': now,
      'sessionData': {
        'placements': placements,
      },
      'status': DailySessionStatus.inProgress.id,
    }, SetOptions(merge: true));

    final solutionRects = List<Map<String, dynamic>>.from(
      challenge.payload['solutionRects'] as List? ?? const [],
    );

    final solutionMap = <String, Map<String, int>>{};
    for (final rect in solutionRects) {
      final pieceId = rect['pieceId'] as String? ?? '';
      solutionMap[pieceId] = {
        'row': (rect['row'] as num).toInt(),
        'col': (rect['col'] as num).toInt(),
        'width': (rect['width'] as num).toInt(),
        'height': (rect['height'] as num).toInt(),
      };
    }

    if (_placementsEqual(placements, solutionMap)) {
      await _completeGame(
        gameId: gameId,
        profileId: profileId,
        attempts: 0,
      );
    }
  }

  Future<void> _completeGame({
    required String gameId,
    required String profileId,
    required int attempts,
  }) async {
    final dateKey = dailyDateKey();
    final sessionId = '${gameId}_${dateKey}_$profileId';
    final sessionRef = _sessionsCol.doc(sessionId);
    final sessionDoc = await sessionRef.get();

    if (!sessionDoc.exists || sessionDoc.data() == null) return;

    final session = DailyGameSession.fromMap(sessionDoc.id, sessionDoc.data()!);
    if (session.isCompleted) return;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    int finalTimeMs = session.accumulatedTimeMs;

    if (session.activeStartedAtMsUtc != null) {
      final delta = now - session.activeStartedAtMsUtc!;
      finalTimeMs += delta > 0 ? delta : 0;
    }

    final displayName = await _fetchDisplayName(profileId);

    final resultRef = _resultsRootCol
        .doc('${gameId}_$dateKey')
        .collection('entries')
        .doc(profileId);

    final statsRef = _statsCol.doc('${profileId}_$gameId');

    await _db.runTransaction((tx) async {
      final statsSnap = await tx.get(statsRef);
      final prevStats = statsSnap.exists && statsSnap.data() != null
          ? DailyGameStats.fromMap(statsSnap.id, statsSnap.data()!)
          : DailyGameStats.empty(profileId, gameId);

      int nextStreak = 1;
      if (prevStats.lastCompletedDateKey == previousDateKey(dateKey)) {
        nextStreak = prevStats.currentStreak + 1;
      } else if (prevStats.lastCompletedDateKey == dateKey) {
        nextStreak = prevStats.currentStreak;
      }

      final nextCompletedCount = prevStats.completedCount + 1;
      final nextAvgAttempts =
          ((prevStats.averageAttempts * prevStats.completedCount) + attempts) /
              nextCompletedCount;
      final nextAvgTime =
          ((prevStats.averageTimeMs * prevStats.completedCount) + finalTimeMs) /
              nextCompletedCount;

      final isTimeGame =
          gameId == DailyGameId.sudoku.id ||
          gameId == DailyGameId.queens.id ||
          gameId == DailyGameId.tango.id ||
          gameId == DailyGameId.zip.id ||
          gameId == DailyGameId.patches.id;

      tx.set(sessionRef, {
        'status': DailySessionStatus.completed.id,
        'attempts': attempts,
        'accumulatedTimeMs': finalTimeMs,
        'activeStartedAtMsUtc': null,
        'completedAtMsUtc': now,
        'lastUpdatedAtMsUtc': now,
      }, SetOptions(merge: true));

      tx.set(resultRef, {
        'profileId': profileId,
        'displayName': displayName,
        'gameId': gameId,
        'dateKey': dateKey,
        'attempts': attempts,
        'timeMs': finalTimeMs,
        'rankMetric': isTimeGame ? finalTimeMs : attempts,
        'completedAtMsUtc': now,
      });

      tx.set(statsRef, {
        'profileId': profileId,
        'gameId': gameId,
        'currentStreak': nextStreak,
        'bestStreak': nextStreak > prevStats.bestStreak
            ? nextStreak
            : prevStats.bestStreak,
        'completedCount': nextCompletedCount,
        'lastCompletedDateKey': dateKey,
        'averageAttempts': nextAvgAttempts,
        'averageTimeMs': nextAvgTime,
      }, SetOptions(merge: true));
    });
    await DailyAddictTagService(_db).checkAndUnlockAddict(
      profileId: profileId,
    );
  }

  Future<String> _fetchDisplayName(String profileId) async {
    final profile = await _profileRepository.getProfileById(profileId);
    return profile?.name ?? profileId;
  }

  static List<List<int?>> _parseNullableIntGridRows(List<String> rows) {
    return rows.map((row) {
      return row.split(',').map<int?>((cell) {
        final value = cell.trim();
        if (value == '_') return null;
        return int.parse(value);
      }).toList();
    }).toList();
  }

  static List<String> _encodeNullableIntGridRows(List<List<int?>> board) {
    return board
        .map((row) => row.map((cell) => cell == null ? '_' : '$cell').join(','))
        .toList();
  }

  static bool _boardsEqual(List<List<int?>> a, List<List<int?>> b) {
    if (a.length != b.length) return false;
    for (int r = 0; r < a.length; r++) {
      if (a[r].length != b[r].length) return false;
      for (int c = 0; c < a[r].length; c++) {
        if (a[r][c] != b[r][c]) return false;
      }
    }
    return true;
  }

  static bool _pathEquals(
    List<Map<String, int>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final ar = a[i]['row'];
      final ac = a[i]['col'];
      final br = (b[i]['row'] as num).toInt();
      final bc = (b[i]['col'] as num).toInt();
      if (ar != br || ac != bc) return false;
    }
    return true;
  }

  static bool _placementsEqual(
    Map<String, Map<String, int>> a,
    Map<String, Map<String, int>> b,
  ) {
    if (a.length != b.length) return false;

    for (final entry in b.entries) {
      final mine = a[entry.key];
      if (mine == null) return false;
      if (mine['row'] != entry.value['row']) return false;
      if (mine['col'] != entry.value['col']) return false;
      if (mine['width'] != entry.value['width']) return false;
      if (mine['height'] != entry.value['height']) return false;
    }

    return true;
  }
}