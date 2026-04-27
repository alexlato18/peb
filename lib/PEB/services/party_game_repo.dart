import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:peb/PEB/models/party_game_room.dart';
import 'package:peb/PEB/models/party_game_match_state.dart';

class PartyGameRoomsRepo {
  PartyGameRoomsRepo(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('partyGameRooms');
  CollectionReference<Map<String, dynamic>> get _matches =>
    _db.collection('partyGameMatches');    

  Stream<List<PartyGameRoom>> watchPublicRooms() {
    return _rooms
        .where('isPublic', isEqualTo: true)
        .where('status', isEqualTo: 'lobby')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => PartyGameRoom.fromMap(d.id, d.data()))
              .where((room) => !room.isFull)
              .toList(),
        );
  }

  Stream<PartyGameMatchState> watchMatch(String roomId) {
  return _matches.doc(roomId).snapshots().map((snap) {
    if (!snap.exists || snap.data() == null) {
      throw Exception('La partida no existe.');
    }

    return PartyGameMatchState.fromMap(snap.data()!);
  });
}
  Future<void> deleteRoom(String roomId) async {
  await _rooms.doc(roomId).delete();
}
  Future<String> createRoom({
    required String title,
    required String hostProfileId,
    required int maxPlayers,
    required bool isPublic,
  }) async {
    final doc = _rooms.doc();

    final room = PartyGameRoom(
      id: doc.id,
      title: title,
      hostProfileId: hostProfileId,
      playerIds: [hostProfileId],
      maxPlayers: maxPlayers,
      isPublic: isPublic,
      joinCode: _generateJoinCode(),
      status: 'lobby',
      createdAt: DateTime.now(),
    );

    await doc.set(room.toMap());
    return doc.id;
  }

  Future<void> startGame({
  required String roomId,
}) async {
  final roomRef = _rooms.doc(roomId);
  final matchRef = _matches.doc(roomId);

  await _db.runTransaction((tx) async {
    final roomSnap = await tx.get(roomRef);

    if (!roomSnap.exists || roomSnap.data() == null) {
      throw Exception('La sala no existe.');
    }

    final room = PartyGameRoom.fromMap(roomSnap.id, roomSnap.data()!);

    if (room.status != 'lobby') {
      throw Exception('La sala ya no está en lobby.');
    }

    if (room.playerIds.length < 2) {
      throw Exception('Se necesitan al menos 2 jugadores.');
    }

    final playerOrder = List<String>.from(room.playerIds);

    final players = <String, PartyGamePlayerState>{
      for (final playerId in playerOrder)
        playerId: PartyGamePlayerState(
          profileId: playerId,
          money: 8,
          score: 0,
          handCharacterCardIds: const [],
          handEventCardIds: const [],
          tableCharacterCardIds: const [],
          tableEventCardIds: const [],
        ),
    };

    final match = PartyGameMatchState(
      roomId: roomId,
      status: 'playing',
      round: 1,
      turnPlayerId: playerOrder.first,
      playerOrder: playerOrder,
      players: players,
    );

    tx.set(matchRef, match.toMap());
    tx.update(roomRef, {'status': 'playing'});
  });
}

  Future<void> joinRoom({
    required String roomId,
    required String profileId,
  }) async {
    final ref = _rooms.doc(roomId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('La sala no existe.');
      }

      final room = PartyGameRoom.fromMap(snap.id, snap.data()!);

      if (room.status != 'lobby') {
        throw Exception('La partida ya no está en lobby.');
      }

      if (room.playerIds.contains(profileId)) {
        return;
      }

      if (room.isFull) {
        throw Exception('La sala está llena.');
      }

      final updatedIds = [...room.playerIds, profileId];
      tx.update(ref, {'playerIds': updatedIds});
    });
  }

  Stream<PartyGameRoom> watchRoom(String roomId) {
    return _rooms.doc(roomId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        throw Exception('La sala no existe.');
      }
      return PartyGameRoom.fromMap(snap.id, snap.data()!);
    });
  }

  Future<String?> findRoomIdByCode(String joinCode) async {
    final query = await _rooms
        .where('joinCode', isEqualTo: joinCode.trim().toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return query.docs.first.id;
  }

  String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}