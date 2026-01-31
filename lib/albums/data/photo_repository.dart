import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/photo_item.dart';

class PhotoRepository {
  PhotoRepository({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
    this.groupId = 'peb',
  })  : _db = firestore,
        _storage = storage;

  final FirebaseFirestore _db;
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final FirebaseStorage _storage;
  final String groupId;

  DocumentReference<Map<String, dynamic>> _eventRef(String eventId) =>
      _db.collection('groups').doc(groupId).collection('events').doc(eventId);

  CollectionReference<Map<String, dynamic>> _photosCol(String eventId) =>
      _eventRef(eventId).collection('photos');

  Reference _mediaRef({
    required String eventId,
    required String fileName,
  }) {
    // Mantengo el path ".../photos/..." para no romper nada.
    // Aunque haya vídeos, se queda en "photos" por simplicidad de MVP.
    return _storage.ref('groups/$groupId/events/$eventId/photos/$fileName');
  }

  Stream<List<PhotoItem>> watchPhotos(String eventId, {int limit = 150}) {
    return _photosCol(eventId)
        .orderBy('uploadedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(PhotoItem.fromDoc).toList());
  }
  Future<void> deletePhotoAsGod({
  required String eventId,
  required PhotoItem photo,
}) async {
  final auth = FirebaseAuth.instance;

  // 1) Asegura usuario anónimo
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }

  // 2) Fuerza token (esto es CLAVE para que context.auth no llegue null)
  await auth.currentUser!.getIdToken(true);

  // 3) Llama a la function
  final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
      .httpsCallable('deleteMediaAsGod');

  await callable.call({
    'eventId': eventId,
    'photoId': photo.id,
    'storagePath': photo.storagePath,
  });
}
  Future<PhotoItem> uploadMedia({
    required String eventId,
    required File file,
    required String uploaderProfileId,
    required String originalFileName,
    String? mimeType, // pásalo si lo conoces (ideal)
  }) async {
    final id = const Uuid().v4();

    final safeName = originalFileName.replaceAll(' ', '_');
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$id\_$safeName';

    final resolvedMime = mimeType ?? _inferMimeType(originalFileName);
    final mediaType = resolvedMime.startsWith('video/') ? 'VIDEO' : 'IMAGE';

    final ref = _mediaRef(eventId: eventId, fileName: fileName);

    final snapshot = await ref.putFile(
      file,
      SettableMetadata(
        contentType: resolvedMime,
        customMetadata: {
          'uploaderUid': uid,
          'uploaderProfileId': uploaderProfileId, // opcional (para auditoría)
        },
      ),
    );

    final url = await ref.getDownloadURL();

    final docRef = _photosCol(eventId).doc(id);
    await docRef.set({
      'downloadURL': url,
      'storagePath': ref.fullPath,
      'uploadedBy': uploaderProfileId,
      'uploadedAt': FieldValue.serverTimestamp(),
      'fileName': originalFileName,
      'sizeBytes': snapshot.totalBytes,
      'contentType': resolvedMime,
      'mediaType': mediaType,
      'taggedProfileIds': <String>[],
      'thumbnailURL': null, // MVP: sin miniatura de vídeo (luego lo añadimos)
    });

    await _eventRef(eventId).update({
      'photoCount': FieldValue.increment(1),
      'coverPhotoUrl': url, // en MVP sirve también como cover aunque sea video
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return PhotoItem(
      id: id,
      downloadURL: url,
      storagePath: ref.fullPath,
      uploadedBy: uploaderProfileId,
      uploadedAt: DateTime.now(),
      mediaType: mediaType,
      fileName: originalFileName,
      sizeBytes: snapshot.totalBytes,
      contentType: resolvedMime,
      thumbnailURL: null,
      taggedProfileIds: const <String>[],
      
    );
  }
  Stream<List<PhotoItem>> watchTaggedPhotos(
  String eventId,
  String profileId, {
  int limit = 150,
}) {
  return _db
      .collection('groups')
      .doc('peb')
      .collection('events')
      .doc(eventId)
      .collection('photos')
      .where('taggedProfileIds', arrayContains: profileId)
      .orderBy('uploadedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map((d) => PhotoItem.fromDoc(d)).toList());
}

  Future<void> setTags({
  required String eventId,
  required String photoId,
  required List<String> taggedProfileIds,
}) async {
  await _db
      .collection('groups')
      .doc('peb')
      .collection('events')
      .doc(eventId)
      .collection('photos')
      .doc(photoId)
      .update({
        'taggedProfileIds': taggedProfileIds,
        'taggedAt': FieldValue.serverTimestamp(),
      });
}

  Future<void> deletePhoto({
    required String eventId,
    required PhotoItem photo,
  }) async {
    await _storage.ref(photo.storagePath).delete();
    await _photosCol(eventId).doc(photo.id).delete();

    await _eventRef(eventId).update({
      'photoCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _inferMimeType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();

    // Imágenes
    if (ext == '.jpg' || ext == '.jpeg') return 'image/jpeg';
    if (ext == '.png') return 'image/png';
    if (ext == '.webp') return 'image/webp';
    if (ext == '.heic') return 'image/heic';
    if (ext == '.heif') return 'image/heif';
    if (ext == '.gif') return 'image/gif';

    // Vídeos
    if (ext == '.mp4') return 'video/mp4';
    if (ext == '.mov') return 'video/quicktime';
    if (ext == '.m4v') return 'video/x-m4v';
    if (ext == '.webm') return 'video/webm';

    // fallback seguro
    return 'application/octet-stream';
  }
}
