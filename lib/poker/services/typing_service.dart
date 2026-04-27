import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class TypingService {
  TypingService(this.db);

  final FirebaseFirestore db;

  Timer? _debounce;

  DocumentReference<Map<String, dynamic>> _presenceRef(String roomId, String profileId) =>
      db.collection("gameRooms").doc(roomId).collection("presence").doc(profileId);

  Stream<List<Map<String, dynamic>>> typingStream(String roomId) {
    return db.collection("gameRooms").doc(roomId).collection("presence")
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());
  }

  Future<void> onTypingChanged({
    required String roomId,
    required String profileId,
    required String displayName,
    required String text,
  }) async {
    final ref = _presenceRef(roomId, profileId);

    // user is typing if text not empty AND just edited
    await ref.set({
      "typing": true,
      "displayName": displayName,
      "lastActiveAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1800), () async {
      await ref.set({
        "typing": false,
        "displayName": displayName,
        "lastActiveAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> forceStopTyping({
    required String roomId,
    required String profileId,
    required String displayName,
  }) async {
    await _presenceRef(roomId, profileId).set({
      "typing": false,
      "displayName": displayName,
      "lastActiveAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
