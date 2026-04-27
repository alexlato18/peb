import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/secret_tags.dart';
import '../models/profile.dart';

class SecretTagService {
  SecretTagService(this._db);

  final FirebaseFirestore _db;

  Future<void> unlockSecretTag({
    required Profile profile,
    required String tag,
  }) async {
    final clean = normalizeTagKey(tag);
    if (!isSecretTag(clean)) return;

    final ref = _db
        .collection('groups')
        .doc('peb')
        .collection('profiles')
        .doc(profile.id);

    final updates = <String, dynamic>{
      'tags': FieldValue.arrayUnion([clean]),
    };

    if (profile.visibleTags != null) {
      updates['visibleTags'] = FieldValue.arrayUnion([clean]);
    }

    await ref.update(updates);

    await checkAndUnlockExplorer(profileId: profile.id);
  }

  Future<void> unlockSecretTagByProfileId({
    required String profileId,
    required String tag,
  }) async {
    final clean = normalizeTagKey(tag);
    if (!isSecretTag(clean)) return;

    final ref = _db
        .collection('groups')
        .doc('peb')
        .collection('profiles')
        .doc(profileId);

    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return;

    final visibleTags = data['visibleTags'];

    final updates = <String, dynamic>{
      'tags': FieldValue.arrayUnion([clean]),
    };

    if (visibleTags != null) {
      updates['visibleTags'] = FieldValue.arrayUnion([clean]);
    }

    await ref.update(updates);

    await checkAndUnlockExplorer(profileId: profileId);
  }

  Future<void> checkAndUnlockExplorer({
    required String profileId,
  }) async {
    final ref = _db
        .collection('groups')
        .doc('peb')
        .collection('profiles')
        .doc(profileId);

    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return;

    final rawTags = List<String>.from(data['tags'] ?? const []);
    final tags = rawTags.map(normalizeTagKey).toSet();

    if (tags.contains(explorerTag)) return;

    final hasAllRequired = explorerRequiredTags.every(tags.contains);

    if (!hasAllRequired) return;

    final visibleTags = data['visibleTags'];

    final updates = <String, dynamic>{
      'tags': FieldValue.arrayUnion([explorerTag]),
    };

    if (visibleTags != null) {
      updates['visibleTags'] = FieldValue.arrayUnion([explorerTag]);
    }

    await ref.update(updates);
  }
}