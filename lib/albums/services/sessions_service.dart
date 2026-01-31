import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionService {
  SessionService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    this.groupId = 'peb',
  })  : _auth = auth,
        _db = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final String groupId;

  Future<void> bindProfileToCurrentUid({
    required String profileId,
    required String role,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No hay usuario autenticado.');

    await _db.doc('groups/$groupId/sessions/${user.uid}').set({
      'profileId': profileId,
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
