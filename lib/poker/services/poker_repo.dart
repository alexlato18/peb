import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/poker_state.dart';
import 'poker_engine.dart';

class PokerRepo {
  PokerRepo(this.db);
  final FirebaseFirestore db;

  DocumentReference<Map<String, dynamic>> roomRef(String roomId) =>
      db.collection("gameRooms").doc(roomId);

  DocumentReference<Map<String, dynamic>> stateRef(String roomId) =>
      roomRef(roomId).collection("state").doc("current");

  DocumentReference<Map<String, dynamic>> myHandRef(String roomId, String profileId) =>
      roomRef(roomId).collection("privateHands").doc(profileId);

  DocumentReference<Map<String, dynamic>> deckRef(String roomId) =>
      roomRef(roomId).collection("private").doc("host_deck");

  Stream<PokerState?> watchState(String roomId) {
    return stateRef(roomId).snapshots().map((d) {
      final data = d.data();
      if (data == null || data.isEmpty) return null;
      return PokerState.fromMap(data);
    });
  }

  Stream<List<String>> watchMyHand(String roomId, String profileId) {
    return myHandRef(roomId, profileId).snapshots().map((d) {
      final data = d.data();
      if (data == null) return <String>[];
      return (data["cards"] as List?)?.cast<String>() ?? const <String>[];
    });
  }

  Future<void> ensureStateExists({
    required String roomId,
    required String hostProfileId,
  }) async {
    final roomSnap = await roomRef(roomId).get();
    final roomData = roomSnap.data() ?? {};
    final hostId = (roomData["hostProfileId"] ?? "") as String;
    if (hostId != hostProfileId) return;

    final stSnap = await stateRef(roomId).get();
    if (stSnap.exists) return;

    final playerIds = (roomData["playerIds"] as List?)?.cast<String>() ?? <String>[];

    await stateRef(roomId).set({
      "phase": "WAITING",
      "handNo": 0,
      "dealerIndex": 0,
      "sb": 10,
      "bb": 20,
      "turnProfileId": "",
      "pot": 0,
      "currentBet": 0,
      "board": List.filled(5, "??"),
      "revealed": List.filled(5, false),
      "players": playerIds
          .map((id) => {
                "profileId": id,
                "stack": 1000,
                "inHand": true,
                "hasFolded": false,
                "betThisStreet": 0,
                "totalCommitted": 0,
                "ready": false,
              })
          .toList(),
      "sidePots": <dynamic>[],
      "winners": <dynamic>[],
      "showdownText": "",
      "lastActionText": "Sala creada. Pulsa Ready.",
      "actedThisStreet": <dynamic>[],
    });
  }

  Future<void> syncPlayersFromRoomToState({
    required String roomId,
    required String hostProfileId,
  }) async {
    final roomSnap = await roomRef(roomId).get();
    final roomData = roomSnap.data() ?? {};
    final hostId = (roomData["hostProfileId"] ?? "") as String;
    if (hostId != hostProfileId) return;

    final roomPlayerIds = (roomData["playerIds"] as List?)?.cast<String>() ?? <String>[];
    final stSnap = await stateRef(roomId).get();
    final stData = stSnap.data();
    if (stData == null) return;

    final players = List<Map<String, dynamic>>.from(stData["players"] ?? const []);
    bool changed = false;

    for (final pid in roomPlayerIds) {
      final exists = players.any((p) => p["profileId"] == pid);
      if (!exists) {
        players.add({
          "profileId": pid,
          "stack": 1000,
          "inHand": true,
          "hasFolded": false,
          "betThisStreet": 0,
          "totalCommitted": 0,
          "ready": false,
        });
        changed = true;
      }
    }

    if (!changed) return;

    await stateRef(roomId).update({
      "players": players,
      "lastActionText": "Jugador unido a la sala",
    });
  }

  Future<void> joinRoom({
    required String roomId,
    required String profileId,
  }) async {
    await db.runTransaction((tx) async {
      final roomSnap = await tx.get(roomRef(roomId));
      final roomData = roomSnap.data() ?? {};

      final playerIds = List<String>.from(roomData["playerIds"] ?? const []);
      final maxPlayers = (roomData["maxPlayers"] ?? 6) as int;
      final status = (roomData["status"] ?? "OPEN") as String;

      if (status == "CLOSED") throw Exception("La sala está cerrada.");
      if (playerIds.contains(profileId)) return;
      if (playerIds.length >= maxPlayers) throw Exception("Sala llena.");

      playerIds.add(profileId);

      tx.update(roomRef(roomId), {
        "playerIds": playerIds,
        "updatedAt": FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> setReady({
    required String roomId,
    required String profileId,
    required bool ready,
  }) async {
    await db.runTransaction((tx) async {
      final stSnap = await tx.get(stateRef(roomId));
      final data = stSnap.data();
      if (data == null) throw Exception("No existe el estado de la sala.");

      final players = List<Map<String, dynamic>>.from(data["players"] ?? const []);
      final idx = players.indexWhere((p) => p["profileId"] == profileId);
      if (idx < 0) throw Exception("Jugador no encontrado en state/current.");

      players[idx] = {
        ...players[idx],
        "ready": ready,
      };

      tx.update(stateRef(roomId), {
        "players": players,
        "lastActionText": ready ? "$profileId está READY" : "$profileId ya no está READY",
      });
    });
  }

  Future<void> hostStartHand({
    required String roomId,
    required String hostProfileId,
  }) async {
    final roomSnap = await roomRef(roomId).get();
    final roomData = roomSnap.data() ?? {};
    final hostId = (roomData["hostProfileId"] ?? "") as String;

    if (hostId != hostProfileId) {
      throw Exception("Solo el host puede empezar la mano.");
    }

    await ensureStateExists(roomId: roomId, hostProfileId: hostProfileId);
    await syncPlayersFromRoomToState(roomId: roomId, hostProfileId: hostProfileId);

    final stSnap = await stateRef(roomId).get();
    final stData = stSnap.data();
    if (stData == null) throw Exception("No existe state/current.");

    final current = PokerState.fromMap(stData);

    if (current.players.length < 2) {
      throw Exception("Se necesitan al menos 2 jugadores.");
    }

    final allReady = current.players.every((p) => p.ready);
    if (!allReady) {
      throw Exception("No todos los jugadores están READY.");
    }

    final result = PokerEngine.startHand(current);

    final batch = db.batch();

    batch.set(stateRef(roomId), result.state.toMap());
    batch.set(deckRef(roomId), {
      "deck": result.remainingDeck,
    });

    for (final entry in result.privateHands.entries) {
      batch.set(myHandRef(roomId, entry.key), {
        "cards": entry.value,
      });
    }

    batch.update(roomRef(roomId), {
      "status": "IN_GAME",
      "updatedAt": FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> submitAction({
  required String roomId,
  required String actorProfileId,
  required PokerAction action,
}) async {
  await db.runTransaction((tx) async {
    final stSnap = await tx.get(stateRef(roomId));
    final data = stSnap.data();
    if (data == null) throw Exception("No existe state/current.");

    var current = PokerState.fromMap(data);
    var next = PokerEngine.applyAction(current, actorProfileId, action);

    List<String> currentDeck = <String>[];
    bool deckLoaded = false;

    Future<void> ensureDeckLoaded() async {
      if (deckLoaded) return;
      final deckSnap = await tx.get(deckRef(roomId));
      currentDeck = (deckSnap.data()?["deck"] as List?)?.cast<String>() ?? <String>[];
      deckLoaded = true;
    }

    Future<Map<String, List<String>>> loadHands() async {
      final hands = <String, List<String>>{};
      for (final p in next.players) {
        final handSnap = await tx.get(myHandRef(roomId, p.profileId));
        final cards = (handSnap.data()?["cards"] as List?)?.cast<String>() ?? const <String>[];
        if (cards.length == 2) {
          hands[p.profileId] = cards;
        }
      }
      return hands;
    }

    while (true) {
      if (next.phase == PokerPhase.showdown) {
        tx.update(stateRef(roomId), next.toMap());
        if (deckLoaded) {
          tx.set(deckRef(roomId), {"deck": currentDeck});
        }
        return;
      }

      final streetFinished = next.turnProfileId.isEmpty && next.currentBet == 0;

      if (streetFinished) {
        if (next.phase == PokerPhase.river) {
          final hands = await loadHands();
          next = PokerEngine.showdown(next, hands);

          tx.update(stateRef(roomId), next.toMap());
          if (deckLoaded) {
            tx.set(deckRef(roomId), {"deck": currentDeck});
          }
          return;
        }

        await ensureDeckLoaded();
        if (currentDeck.isEmpty) {
          throw Exception("No quedan cartas en el deck privado.");
        }

        final advanced = PokerEngine.advanceStreet(next, currentDeck);
        next = advanced.$1;
        currentDeck = advanced.$2;

        if (PokerEngine.shouldAutoRunoutBoard(next)) {
          final noTurnNeeded = next.turnProfileId.isEmpty || next.players.where((p) => p.inHand && !p.hasFolded && p.stack > 0).length <= 1;
          if (noTurnNeeded) {
            next = next.copyWith(turnProfileId: "");
          }
          continue;
        }

        tx.update(stateRef(roomId), next.toMap());
        tx.set(deckRef(roomId), {"deck": currentDeck});
        return;
      }

      if (PokerEngine.shouldAutoRunoutBoard(next)) {
        next = next.copyWith(turnProfileId: "");
        continue;
      }

      tx.update(stateRef(roomId), next.toMap());
      if (deckLoaded) {
        tx.set(deckRef(roomId), {"deck": currentDeck});
      }
      return;
    }
  });
}

  Future<void> hostAdvanceStreetIfNeeded({
    required String roomId,
    required String hostProfileId,
  }) async {
    final roomSnap = await roomRef(roomId).get();
    final roomData = roomSnap.data() ?? {};
    final hostId = (roomData["hostProfileId"] ?? "") as String;
    if (hostId != hostProfileId) return;

    final stSnap = await stateRef(roomId).get();
    final stData = stSnap.data();
    if (stData == null) return;

    final current = PokerState.fromMap(stData);

    if (current.phase == PokerPhase.waiting || current.phase == PokerPhase.showdown) return;
    if (current.turnProfileId.isNotEmpty) return;
    if (current.currentBet != 0) return;

    if (current.phase == PokerPhase.river) {
      final hands = <String, List<String>>{};
      for (final p in current.players) {
        final handSnap = await myHandRef(roomId, p.profileId).get();
        final cards = (handSnap.data()?["cards"] as List?)?.cast<String>() ?? const <String>[];
        if (cards.length == 2) {
          hands[p.profileId] = cards;
        }
      }

      final showdownState = PokerEngine.showdown(current, hands);
      await stateRef(roomId).update(showdownState.toMap());
      return;
    }

    final deckSnap = await deckRef(roomId).get();
    final deck = (deckSnap.data()?["deck"] as List?)?.cast<String>() ?? <String>[];
    if (deck.isEmpty) return;

    final (nextState, nextDeck) = PokerEngine.advanceStreet(current, deck);

    final batch = db.batch();
    batch.update(stateRef(roomId), nextState.toMap());
    batch.set(deckRef(roomId), {"deck": nextDeck});
    await batch.commit();
  }

  Future<void> closeRoom({
    required String roomId,
    required String hostProfileId,
  }) async {
    await roomRef(roomId).update({
      "status": "CLOSED",
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }
}