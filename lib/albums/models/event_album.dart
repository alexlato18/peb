import 'package:cloud_firestore/cloud_firestore.dart';

class EventAlbum {
  EventAlbum({
    required this.id,
    required this.name,
    required this.date,
    required this.visibility, // "PUBLIC" | "PRIVATE"
    required this.countsForGala,
    required this.participantIds,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.coverPhotoUrl,
    this.photoCount,
  });

  final String id;
  final String name;
  final DateTime date;
  final String visibility;
  final bool countsForGala;
  final List<String> participantIds;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? coverPhotoUrl;
  final int? photoCount;

  factory EventAlbum.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return EventAlbum(
      id: doc.id,
      name: (d['name'] ?? '') as String,
      date: ((d['date'] as Timestamp?) ?? Timestamp.now()).toDate(),
      visibility: (d['visibility'] ?? 'PUBLIC') as String,
      countsForGala: (d['countsForGala'] ?? false) as bool,
      participantIds: List<String>.from(d['participantIds'] ?? const []),
      createdBy: (d['createdBy'] ?? '') as String,
      createdAt: ((d['createdAt'] as Timestamp?) ?? Timestamp.now()).toDate(),
      updatedAt: ((d['updatedAt'] as Timestamp?) ?? Timestamp.now()).toDate(),
      coverPhotoUrl: d['coverPhotoUrl'] as String?,
      photoCount: (d['photoCount'] as num?)?.toInt(),
    );
  }
}
