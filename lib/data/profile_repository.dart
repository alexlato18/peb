import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/profile.dart';

class ProfileRepository {
  ProfileRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('groups').doc('peb').collection('profiles');

  Stream<List<Profile>> watchProfiles() {
    return _col.orderBy('name').snapshots().map(
          (snap) => snap.docs.map((d) => Profile.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<Profile?> getProfileById(String profileId) async {
    final doc = await _col.doc(profileId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Profile.fromMap(doc.id, doc.data()!);
  }
}
