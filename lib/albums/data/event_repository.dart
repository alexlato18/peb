import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_album.dart';

class EventRepository {
  EventRepository({
    required FirebaseFirestore firestore,
    this.groupId = 'peb',
  }) : _db = firestore;

  final FirebaseFirestore _db;
  final String groupId;

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('groups').doc(groupId).collection('events');

  // ✅ DIOS: puede ver todo sin problemas
  Stream<List<EventAlbum>> watchAllEvents({int limit = 60}) {
    return _events
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(EventAlbum.fromDoc).toList());
  }

  // ✅ RESTO: dos queries seguras + merge
  Stream<List<EventAlbum>> watchVisibleEvents({
    required String myProfileId,
    required String myRole,
    int limitPublic = 60,
    int limitMine = 60,
  }) {
    if (myRole == 'DIOS') {
      return watchAllEvents(limit: (limitPublic > limitMine ? limitPublic : limitMine));
    }

    final publicStream = _events
        .where('visibility', isEqualTo: 'PUBLIC')
        .orderBy('date', descending: true)
        .limit(limitPublic)
        .snapshots()
        .map((s) => s.docs.map(EventAlbum.fromDoc).toList());

    final mineStream = _events
        .where('participantIds', arrayContains: myProfileId)
        .orderBy('date', descending: true)
        .limit(limitMine)
        .snapshots()
        .map((s) => s.docs.map(EventAlbum.fromDoc).toList());

    final controller = StreamController<List<EventAlbum>>();
    List<EventAlbum> latestPublic = const [];
    List<EventAlbum> latestMine = const [];

    void emitMerged() {
      final map = <String, EventAlbum>{};

      for (final e in latestPublic) {
        map[e.id] = e;
      }
      for (final e in latestMine) {
        map[e.id] = e;
      }

      final merged = map.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      controller.add(merged);
    }

    late final StreamSubscription sub1;
    late final StreamSubscription sub2;

    sub1 = publicStream.listen((list) {
      latestPublic = list;
      emitMerged();
    }, onError: controller.addError);

    sub2 = mineStream.listen((list) {
      latestMine = list;
      emitMerged();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await sub1.cancel();
      await sub2.cancel();
    };

    return controller.stream;
  }

  Stream<EventAlbum> watchEvent(String eventId) {
    return _events.doc(eventId).snapshots().map((d) => EventAlbum.fromDoc(d));
  }

  Future<String> createEvent({
    required String name,
    required DateTime date,
    required String visibility, // PUBLIC/PRIVATE
    required bool countsForGala,
    required List<String> participantIds,
    required String createdByProfileId,
  }) async {
    final doc = _events.doc();
    final now = DateTime.now();

    await doc.set({
      'name': name.trim(),
      'date': Timestamp.fromDate(date),
      'visibility': visibility,
      'countsForGala': countsForGala,
      'participantIds': participantIds,
      'createdBy': createdByProfileId,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'photoCount': 0,
      'coverPhotoUrl': null,
    });

    return doc.id;
  }

  Future<void> addParticipants({
    required String eventId,
    required List<String> participantIds,
  }) async {
    await _events.doc(eventId).update({
      'participantIds': FieldValue.arrayUnion(participantIds),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEventWithPhotos({required String eventId}) async {
    final eventRef = _events.doc(eventId);
    final photos = await eventRef.collection('photos').get();
    for (final p in photos.docs) {
      await p.reference.delete();
    }
    await eventRef.delete();
  }
}
