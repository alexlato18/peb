import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/secret_tags.dart';
import '../models/profile.dart';
import 'secret_tag_service.dart';

class GhostService {
  GhostService(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _progressRef(String profileId) {
    return _db
        .collection('groups')
        .doc('peb')
        .collection('ghost_progress')
        .doc(profileId);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> registerSilentVisit(Profile profile) async {
    final ref = _progressRef(profile.id);
    final today = _todayKey();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();

      if (data == null) {
        tx.set(ref, {
          'profileId': profile.id,
          'lastVisitDay': today,
          'silentDays': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final lastDay = data['lastVisitDay'] as String?;
      final current = (data['silentDays'] as num?)?.toInt() ?? 0;

      if (lastDay == today) return;

      tx.set(ref, {
        'profileId': profile.id,
        'lastVisitDay': today,
        'silentDays': current + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    final after = await ref.get();
    final silentDays = (after.data()?['silentDays'] as num?)?.toInt() ?? 0;

    if (silentDays >= 7 && !profile.tags.contains(ghostTag)) {
      await SecretTagService(_db).unlockSecretTag(
        profile: profile,
        tag: ghostTag,
      );
    }
  }

  Future<void> resetBecauseUserPosted(String profileId) async {
    await _progressRef(profileId).set({
      'profileId': profileId,
      'silentDays': 0,
      'lastResetAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}