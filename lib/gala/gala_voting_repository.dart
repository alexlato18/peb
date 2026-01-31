import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:peb/albums/models/event_album.dart';


class GalaVotingRepository {
  GalaVotingRepository({
    required FirebaseFirestore firestore,
    this.groupId = 'peb',
  }) : _db = firestore;

  final FirebaseFirestore _db;
  final String groupId;

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('groups').doc(groupId).collection('events');

  /// Votaciones visibles:
  /// - countsForGala == true
  /// - el usuario ES participante (participantIds contiene myProfileId)
  /// - visibles desde el día siguiente al evento
  Stream<List<EventAlbum>> watchMyAvailableGalaVotes({
    required String myProfileId,
    int limit = 80,
  }) {
    final base = _events
        .where('countsForGala', isEqualTo: true)
        .where('participantIds', arrayContains: myProfileId)
        .orderBy('date', descending: true)
        .limit(limit);

    return base.snapshots().map((s) {
      final now = DateTime.now();

      final all = s.docs.map(EventAlbum.fromDoc).toList();

      // día siguiente: event.date + 1 día (local)
      bool isVisible(EventAlbum e) {
        final visibleFrom = DateTime(
          e.date.year,
          e.date.month,
          e.date.day,
        ).add(const Duration(days: 1));

        // visible a partir de las 00:00 del día siguiente
        return !now.isBefore(visibleFrom);
      }

      return all.where(isVisible).toList();
    });
  }

  /// Saber si ya votaste (get directo, sin list)
  Stream<bool> watchHasVoted({
    required String eventId,
    required String myProfileId,
  }) {
    final ref = _events.doc(eventId).collection('galaVotes').doc(myProfileId);
    return ref.snapshots().map((d) => d.exists);
  }

  /// Crear voto UNA sola vez (transacción)
  Future<void> submitVoteOnce({
    required String eventId,
    required String myProfileId,
    required Map<String, dynamic> answers,
  }) async {
    final voteRef = _events.doc(eventId).collection('galaVotes').doc(myProfileId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(voteRef);
      if (snap.exists) {
        throw StateError('Ya has votado en este evento.');
      }

      tx.set(voteRef, {
        'voterProfileId': myProfileId,
        'createdAt': FieldValue.serverTimestamp(),
        'answers': answers,
      });
    });
  }

  /// Resultados: listar eventos de gala (para organizador)
  Stream<List<EventAlbum>> watchAllGalaEventsForResults({int limit = 120}) {
    return _events
        .where('countsForGala', isEqualTo: true)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(EventAlbum.fromDoc).toList());
  }

  /// Resultados: leer TODOS los votos (solo ORGANIZADOR/ADMIN/DIOS por rules)
  Stream<List<Map<String, dynamic>>> watchAllVotesForEvent({
    required String eventId,
    int limit = 500,
  }) {
    final col = _events.doc(eventId).collection('galaVotes').limit(limit);

    return col.snapshots().map((s) {
      return s.docs.map((d) => d.data()).toList();
    });
  }
  DocumentReference<Map<String, dynamic>> get _extrasRoot =>
      _db.collection('groups').doc(groupId).collection('gala_extras').doc('_root');

  CollectionReference<Map<String, dynamic>> get _manualPhrases =>
      _extrasRoot.collection('phrases').doc('items_root').collection('items');

  CollectionReference<Map<String, dynamic>> get _manualMoments =>
      _extrasRoot.collection('moments').doc('items_root').collection('items');

  Stream<List<Map<String, dynamic>>> watchManualPhrases({int limit = 250}) {
    return _manualPhrases
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> addManualPhrase({
    required String text,
    required String createdByProfileId,
  }) async {
    final t = text.trim();
    if (t.isEmpty) return;

    await _manualPhrases.add({
      'text': t,
      'createdBy': createdByProfileId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchManualMoments({int limit = 250}) {
    return _manualMoments
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> addManualMoment({
    required String text,
    required String createdByProfileId,
  }) async {
    final t = text.trim();
    if (t.isEmpty) return;

    await _manualMoments.add({
      'text': t,
      'createdBy': createdByProfileId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
