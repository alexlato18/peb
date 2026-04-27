import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class PokerRoomLite {
  PokerRoomLite({
    required this.id,
    required this.title,
    required this.maxPlayers,
    required this.playerCount,
    required this.visibility,
    this.inviteCode,
  });

  final String id;
  final String title;
  final int maxPlayers;
  final int playerCount;
  final String visibility; // "PUBLIC" | "INVITE_ONLY"
  final String? inviteCode;

  static PokerRoomLite fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final ids = List<String>.from(d["playerIds"] ?? const []);
    return PokerRoomLite(
      id: doc.id,
      title: (d["title"] ?? "") as String,
      maxPlayers: (d["maxPlayers"] ?? 6) as int,
      playerCount: ids.length,
      visibility: (d["visibility"] ?? "PUBLIC") as String,
      inviteCode: d["inviteCode"] as String?,
    );
  }
}

class PokerRoomsRepo {
  PokerRoomsRepo(this.db);
  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get _rooms => db.collection("gameRooms");

  Stream<List<PokerRoomLite>> watchPublicRooms() {
    return _rooms
        .where("gameType", isEqualTo: "POKER_HOLDEM")
        .where("visibility", isEqualTo: "PUBLIC")
        .where("status", isEqualTo: "OPEN")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((s) => s.docs.map(PokerRoomLite.fromDoc).toList());
  }

  String _inviteCode() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<String> createRoom({
    required String title,
    required String hostProfileId,
    required String visibility, // "PUBLIC" | "INVITE_ONLY"
    int maxPlayers = 6,
  }) async {
    final ref = _rooms.doc();
    await ref.set({
      "gameType": "POKER_HOLDEM",
      "title": title,
      "hostProfileId": hostProfileId,
      "visibility": visibility,
      "inviteCode": visibility == "INVITE_ONLY" ? _inviteCode() : null,
      "status": "OPEN",
      "maxPlayers": maxPlayers,
      "playerIds": [hostProfileId],
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> joinRoom({required String roomId, required String profileId}) async {
    await db.runTransaction((tx) async {
      final ref = _rooms.doc(roomId);
      final snap = await tx.get(ref);
      final d = snap.data()!;
      final ids = List<String>.from(d["playerIds"] ?? const []);
      final maxPlayers = (d["maxPlayers"] ?? 6) as int;
      final status = (d["status"] ?? "OPEN") as String;
      if (status != "OPEN" && status != "IN_GAME") throw Exception("Sala cerrada.");
      if (ids.contains(profileId)) return;
      if (ids.length >= maxPlayers) throw Exception("Sala llena.");
      ids.add(profileId);
      tx.update(ref, {"playerIds": ids, "updatedAt": FieldValue.serverTimestamp()});
    });
  }

  Future<String?> findRoomByInviteCode(String code) async {
    final q = await _rooms
        .where("gameType", isEqualTo: "POKER_HOLDEM")
        .where("visibility", isEqualTo: "INVITE_ONLY")
        .where("inviteCode", isEqualTo: code)
        .where("status", isEqualTo: "OPEN")
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.id;
  }
}
