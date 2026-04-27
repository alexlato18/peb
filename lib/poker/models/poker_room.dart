import 'package:cloud_firestore/cloud_firestore.dart';

enum RoomVisibility { public, inviteOnly }
enum RoomStatus { open, inGame, closed }

class PokerRoom {
  PokerRoom({
    required this.id,
    required this.title,
    required this.hostUid,
    required this.hostProfileId,
    required this.visibility,
    required this.status,
    required this.maxPlayers,
    required this.playerIds,
    required this.createdAt,
    required this.updatedAt,
    this.inviteCode,
  });

  final String id;
  final String title;
  final String hostUid;
  final String hostProfileId;
  final RoomVisibility visibility;
  final RoomStatus status;
  final int maxPlayers;
  final List<String> playerIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? inviteCode;

  static RoomVisibility _visFrom(String s) =>
      s == "INVITE_ONLY" ? RoomVisibility.inviteOnly : RoomVisibility.public;

  static RoomStatus _statusFrom(String s) {
    switch (s) {
      case "IN_GAME":
        return RoomStatus.inGame;
      case "CLOSED":
        return RoomStatus.closed;
      default:
        return RoomStatus.open;
    }
  }

  static PokerRoom fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return PokerRoom(
      id: doc.id,
      title: (d["title"] ?? "") as String,
      hostUid: (d["hostUid"] ?? "") as String,
      hostProfileId: (d["hostProfileId"] ?? "") as String,
      visibility: _visFrom((d["visibility"] ?? "PUBLIC") as String),
      status: _statusFrom((d["status"] ?? "OPEN") as String),
      maxPlayers: (d["maxPlayers"] ?? 6) as int,
      playerIds: List<String>.from(d["playerIds"] ?? const []),
      inviteCode: d["inviteCode"] as String?,
      createdAt: (d["createdAt"] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d["updatedAt"] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
