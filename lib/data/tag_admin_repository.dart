import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/profile.dart';

class TagAdminRepository {
  TagAdminRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _db.collection('groups').doc('peb').collection('profiles');

  Stream<List<Profile>> watchProfiles() {
    return _profiles.orderBy('name').snapshots().map(
          (snap) => snap.docs.map((d) => Profile.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<void> addTagToProfile({
    required String profileId,
    required String tag,
  }) async {
    final clean = tag.trim();
    if (clean.isEmpty) return;

    await _profiles.doc(profileId).update({
      'tags': FieldValue.arrayUnion([clean]),
    });
  }

  Future<void> removeTagFromProfile({
    required String profileId,
    required String tag,
  }) async {
    final clean = tag.trim();
    if (clean.isEmpty) return;

    await _profiles.doc(profileId).update({
      'tags': FieldValue.arrayRemove([clean]),
    });
  }
  Future<void> removeTagEverywhere({
  required String tag,
  required List<Profile> profiles,
}) async {
  final clean = tag.trim();
  if (clean.isEmpty) return;

  final batch = _db.batch();

  // 1) Quitar el tag de todos los perfiles
  for (final p in profiles) {
    if (p.tags.contains(clean)) {
      batch.update(_profiles.doc(p.id), {
        'tags': FieldValue.arrayRemove([clean]),
      });
    }
  }

  // 2) Quitar de la lista global de tags
  final configDoc =
      _db.collection('groups').doc('peb').collection('config').doc('tags');

  batch.set(configDoc, {
    'allTags': FieldValue.arrayRemove([clean]),
    'styles': {clean: FieldValue.delete()},
  }, SetOptions(merge: true));

  await batch.commit();
}

  Future<void> applyMembersDelta({
    required String tag,
    required Set<String> addToProfileIds,
    required Set<String> removeFromProfileIds,
  }) async {
    final clean = tag.trim();
    if (clean.isEmpty) return;

    final batch = _db.batch();

    for (final id in addToProfileIds) {
      batch.update(_profiles.doc(id), {
        'tags': FieldValue.arrayUnion([clean]),
      });
    }

    for (final id in removeFromProfileIds) {
      batch.update(_profiles.doc(id), {
        'tags': FieldValue.arrayRemove([clean]),
      });
    }

    await batch.commit();
  }
}
