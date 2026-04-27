import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/secret_tags.dart';
import 'secret_tag_service.dart';

class DailyAddictTagService {
  DailyAddictTagService(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _groupDoc =>
      _db.collection('groups').doc('peb');

  CollectionReference<Map<String, dynamic>> get _catalogCol =>
      _groupDoc.collection('daily_games_catalog');

  CollectionReference<Map<String, dynamic>> get _statsCol =>
      _groupDoc.collection('daily_game_stats');

  Future<void> checkAndUnlockAddict({
    required String profileId,
  }) async {
    final catalogSnap = await _catalogCol
        .where('enabled', isEqualTo: true)
        .get();

    final gameIds = catalogSnap.docs.map((d) => d.id).toList();

    if (gameIds.isEmpty) return;

    for (final gameId in gameIds) {
      final statsId = '${profileId}_$gameId';
      final statsDoc = await _statsCol.doc(statsId).get();
      final data = statsDoc.data();

      if (data == null) return;

      final currentStreak =
          (data['currentStreak'] as num?)?.toInt() ?? 0;

      if (currentStreak < 5) {
        return;
      }
    }

    await SecretTagService(_db).unlockSecretTagByProfileId(
      profileId: profileId,
      tag: addictTag,
    );
  }
}