import 'package:cloud_firestore/cloud_firestore.dart';

class PartyGameRoom {
  const PartyGameRoom({
    required this.id,
    required this.title,
    required this.hostProfileId,
    required this.playerIds,
    required this.maxPlayers,
    required this.isPublic,
    required this.joinCode,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String hostProfileId;
  final List<String> playerIds;
  final int maxPlayers;
  final bool isPublic;
  final String joinCode;
  final String status; // lobby | playing | finished
  final DateTime? createdAt;

  int get playerCount => playerIds.length;

  bool get isFull => playerCount >= maxPlayers;

  factory PartyGameRoom.fromMap(String id, Map<String, dynamic> map) {
    final createdAtRaw = map['createdAt'];

    return PartyGameRoom(
      id: id,
      title: (map['title'] ?? '') as String,
      hostProfileId: (map['hostProfileId'] ?? '') as String,
      playerIds: List<String>.from(map['playerIds'] ?? const []),
      maxPlayers: (map['maxPlayers'] ?? 6) as int,
      isPublic: (map['isPublic'] ?? true) as bool,
      joinCode: (map['joinCode'] ?? '') as String,
      status: (map['status'] ?? 'lobby') as String,
      createdAt: createdAtRaw is Timestamp ? createdAtRaw.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'hostProfileId': hostProfileId,
      'playerIds': playerIds,
      'maxPlayers': maxPlayers,
      'isPublic': isPublic,
      'joinCode': joinCode,
      'status': status,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    };
  }
}