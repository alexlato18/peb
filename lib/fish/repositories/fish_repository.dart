import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/fish_definitions.dart';
import '../models/fish_models.dart';

class FishRepository {
  FishRepository(this._db);

  final FirebaseFirestore _db;
  final Random _random = Random();

  DocumentReference<Map<String, dynamic>> get _groupDoc =>
      _db.collection('groups').doc('peb');

  CollectionReference<Map<String, dynamic>> _inventoryCol(String profileId) =>
      _groupDoc.collection('profiles').doc(profileId).collection('fish_inventory');

  CollectionReference<Map<String, dynamic>> _fishbowlCol(String profileId) =>
      _groupDoc.collection('profiles').doc(profileId).collection('fishbowl');

  DocumentReference<Map<String, dynamic>> _metaDoc(String profileId) =>
      _groupDoc.collection('profiles').doc(profileId).collection('fish_meta').doc('state');

  Stream<List<FishInstance>> watchInventory(String profileId) {
    return _inventoryCol(profileId)
        .orderBy('obtainedAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) => FishInstance.fromMap(d.id, d.data())).toList();
    });
  }

  Stream<List<FishInstance>> watchFishbowl(String profileId) {
    return _fishbowlCol(profileId).snapshots().map((snap) {
      return snap.docs.map((d) => FishInstance.fromMap(d.id, d.data())).toList();
    });
  }

  Future<bool> canOpenPackToday(String profileId) async {
    final doc = await _metaDoc(profileId).get();
    final today = _todayKey();

    if (!doc.exists || doc.data() == null) return true;

    return doc.data()!['lastPackDate'] != today;
  }

  Future<List<FishInstance>> generatePackOptions(String profileId) async {
  final metaSnap = await _metaDoc(profileId).get();
  final today = _todayKey();

  if (metaSnap.exists && metaSnap.data()?['lastPackDate'] == today) {
    throw Exception('Ya has abierto el sobre de hoy.');
  }

  final pendingDate = metaSnap.data()?['pendingPackDate'];
  final pendingRaw = metaSnap.data()?['pendingPackOptions'];

  if (pendingDate == today && pendingRaw is List) {
    return pendingRaw
        .map((e) => FishInstance.fromPendingMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  final options = <FishInstance>[];

  while (options.length < 5) {
    final fish = _randomFishByRarity();
    if (options.any((e) => e.fishId == fish.id)) continue;

    final shiny = _rollShiny();

    options.add(
      FishInstance(
        id: _newId(),
        fishId: fish.id,
        shiny: shiny,
        shinyHue: shiny ? _rollShinyHue() : null,
        modifiers: _rollModifiers(),
        ownerProfileId: profileId,
        obtainedAt: Timestamp.now(),
      ),
    );
  }

  await _metaDoc(profileId).set({
    'pendingPackDate': today,
    'pendingPackOptions': options.map((e) => e.toPendingMap()).toList(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  return options;
}
  double _rollShinyHue() {
  return _random.nextDouble() * 360;
}
  Future<void> claimFish({
    required String profileId,
    required FishInstance fish,
    required bool addToOwnFishbowl,
  }) async {
    final canOpen = await canOpenPackToday(profileId);
    if (!canOpen) {
      throw Exception('Ya has abierto el sobre de hoy.');
    }

    final invRef = _inventoryCol(profileId).doc(fish.id);
    final metaRef = _metaDoc(profileId);

    await _db.runTransaction((tx) async {
      tx.set(invRef, fish.toMap());

      if (addToOwnFishbowl) {
        tx.set(_fishbowlCol(profileId).doc(fish.id), fish.toMap());
      }

      tx.set(metaRef, {
        'lastPackDate': _todayKey(),
        'pendingPackDate': FieldValue.delete(),
        'pendingPackOptions': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> sendFishToProfile({
    required String fromProfileId,
    required String toProfileId,
    required FishInstance fish,
  }) async {
    final canOpen = await canOpenPackToday(fromProfileId);
    if (!canOpen) {
      throw Exception('Ya has usado el sobre de hoy.');
    }

    final sentFish = fish.copyWith(
      ownerProfileId: toProfileId,
      senderProfileId: fromProfileId,
      obtainedAt: Timestamp.now(),
    );

    await _db.runTransaction((tx) async {
      tx.set(_fishbowlCol(toProfileId).doc(sentFish.id), sentFish.toMap());

      tx.set(_metaDoc(fromProfileId), {
        'lastPackDate': _todayKey(),
        'pendingPackDate': FieldValue.delete(),
        'pendingPackOptions': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  FishDefinition _randomFishByRarity() {
    final rarity = _rollRarity();
    final candidates = fishDefinitions.where((e) => e.rarity == rarity).toList();

    if (candidates.isEmpty) {
      return fishDefinitions[_random.nextInt(fishDefinitions.length)];
    }

    return candidates[_random.nextInt(candidates.length)];
  }

  FishRarity _rollRarity() {
    final roll = _random.nextDouble() * 100;

    if (roll < 65) return FishRarity.comun;
    if (roll < 90) return FishRarity.pocoComun;
    if (roll < 98.5) return FishRarity.epico;
    return FishRarity.legendario;
  }

  bool _rollShiny() {
    return _random.nextDouble() < 0.01;
  }

  List<String> _rollModifiers() {
    final roll = _random.nextDouble() * 100;

    int amount;
    if (roll < 72) {
      amount = 0;
    } else if (roll < 95) {
      amount = 1;
    } else if (roll < 99.5) {
      amount = 2;
    } else {
      amount = 3;
    }

    final values = FishModifier.values.map((e) => e.name).toList();
    values.shuffle(_random);

    return values.take(amount).toList();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _newId() {
    return 'fish_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(999999)}';
  }
}