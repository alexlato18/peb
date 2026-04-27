import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/secret_tags.dart';
import '../../services/secret_tag_service.dart';
import '../models/feedback_entry.dart';

class FeedbackRepository {
  FeedbackRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('groups').doc('peb').collection('feedback_entries');

  Stream<List<FeedbackEntry>> watchMine(String profileId) {
    return _col
        .where('profileId', isEqualTo: profileId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => FeedbackEntry.fromMap(d.id, d.data())).toList());
  }

  Stream<List<FeedbackEntry>> watchPendingForGod() {
    return _col
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => FeedbackEntry.fromMap(d.id, d.data())).toList());
  }

  Future<void> createEntry({
    required String profileId,
    required String type,
    required String text,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    await _col.add({
      'profileId': profileId,
      'type': type,
      'text': clean,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reviewEntry({
    required FeedbackEntry entry,
    required String reviewerProfileId,
    required bool valid,
  }) async {
    await _col.doc(entry.id).update({
      'status': valid ? 'valid' : 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': reviewerProfileId,
    });

    if (!valid) return;

    final validCount = await _countValidEntries(entry.profileId);

    if (validCount >= 3) {
      await SecretTagService(_db).unlockSecretTagByProfileId(
        profileId: entry.profileId,
        tag: betaTesterTag,
      );
    }
  }

  Future<int> _countValidEntries(String profileId) async {
    final snap = await _col
        .where('profileId', isEqualTo: profileId)
        .where('status', isEqualTo: 'valid')
        .get();

    return snap.docs.length;
  }
}