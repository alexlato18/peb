import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/secret_tags.dart';
import '../models/profile.dart';
import 'secret_tag_service.dart';

class DailySecretProgressService {
  DailySecretProgressService(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _progressRef(String profileId) {
    return _db
        .collection('groups')
        .doc('peb')
        .collection('daily_secret_progress')
        .doc(profileId);
  }

  Future<void> registerDailyGameWin({
    required Profile profile,
    required String gameId,
    required List<String> allDailyGameIds,
  }) async {
    final cleanGameId = gameId.trim();
    if (cleanGameId.isEmpty) return;

    final ref = _progressRef(profile.id);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};

      final streaksRaw =
          Map<String, dynamic>.from(data['winStreaks'] ?? const {});

      final current = (streaksRaw[cleanGameId] as num?)?.toInt() ?? 0;
      streaksRaw[cleanGameId] = current + 1;

      tx.set(ref, {
        'profileId': profile.id,
        'winStreaks': streaksRaw,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    await _checkAddictUnlock(
      profile: profile,
      allDailyGameIds: allDailyGameIds,
    );
  }

  Future<void> registerDailyGameLoss({
    required Profile profile,
    required String gameId,
  }) async {
    final cleanGameId = gameId.trim();
    if (cleanGameId.isEmpty) return;

    await _progressRef(profile.id).set({
      'profileId': profile.id,
      'winStreaks': {
        cleanGameId: 0,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _checkAddictUnlock({
    required Profile profile,
    required List<String> allDailyGameIds,
  }) async {
    if (allDailyGameIds.isEmpty) return;

    final snap = await _progressRef(profile.id).get();
    final data = snap.data();
    if (data == null) return;

    final streaks = Map<String, dynamic>.from(data['winStreaks'] ?? const {});

    final hasFiveInEveryGame = allDailyGameIds.every((gameId) {
      final current = (streaks[gameId] as num?)?.toInt() ?? 0;
      return current >= 5;
    });

    if (!hasFiveInEveryGame) return;

    await SecretTagService(_db).unlockSecretTag(
      profile: profile,
      tag: addictTag,
    );
  }
}