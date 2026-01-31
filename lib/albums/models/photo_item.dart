import 'package:cloud_firestore/cloud_firestore.dart';

class PhotoItem {
  PhotoItem({
    required this.id,
    required this.downloadURL,
    required this.storagePath,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.mediaType,
    required this.taggedProfileIds, // "IMAGE" | "VIDEO"
    this.fileName,
    this.sizeBytes,
    this.contentType,
    this.thumbnailURL,
  });

  final String id;
  final String downloadURL;
  final String storagePath;
  final String uploadedBy; // profileId
  final DateTime uploadedAt;
  final List<String> taggedProfileIds;

  final String mediaType; // IMAGE | VIDEO
  final String? fileName;
  final int? sizeBytes;
  final String? contentType;
  final String? thumbnailURL;

  factory PhotoItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final tagged = (d['taggedProfileIds'] as List?)?.cast<String>() ?? <String>[];

    return PhotoItem(
      id: doc.id,
      downloadURL: (d['downloadURL'] ?? '') as String,
      storagePath: (d['storagePath'] ?? '') as String,
      uploadedBy: (d['uploadedBy'] ?? '') as String,
      uploadedAt: ((d['uploadedAt'] as Timestamp?) ?? Timestamp.now()).toDate(),
      mediaType: (d['mediaType'] ?? 'IMAGE') as String,
      fileName: d['fileName'] as String?,
      sizeBytes: (d['sizeBytes'] as num?)?.toInt(),
      contentType: d['contentType'] as String?,
      thumbnailURL: d['thumbnailURL'] as String?,
      taggedProfileIds: tagged,

    );
  }
}
