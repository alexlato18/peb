import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/social_post.dart';
import '../models/private_message.dart';

class SocialRepository {
  SocialRepository({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  })  : _firestore = firestore,
        _storage = storage;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _postsCol =>
      _firestore.collection('groups').doc('peb').collection('social_posts');

  CollectionReference<Map<String, dynamic>> get _privateChatsCol =>
      _firestore.collection('groups').doc('peb').collection('private_chats');

  Stream<List<SocialPost>> watchPosts() {
    return _postsCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SocialPost.fromMap(d.id, d.data()))
            .toList());
  }

  String buildChatId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Stream<List<PrivateMessage>> watchMessages(String chatId) {
    return _privateChatsCol
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PrivateMessage.fromMap(d.id, d.data()))
            .toList());
  }

  Future<String> uploadPostMedia({
    required File file,
    required String postId,
    required String mediaType,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    final ref = _storage.ref(
      'groups/peb/social_posts/$postId/media.$ext',
    );

    final metadata = SettableMetadata(
      contentType: mediaType == 'video' ? 'video/$ext' : 'image/$ext',
    );

    await ref.putFile(file, metadata);
    return ref.getDownloadURL();
  }

  Future<String> uploadChatMedia({
    required File file,
    required String chatId,
    required String messageId,
    required String mediaType,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    final ref = _storage.ref(
      'groups/peb/private_chats/$chatId/$messageId.$ext',
    );

    final metadata = SettableMetadata(
      contentType: mediaType == 'video' ? 'video/$ext' : 'image/$ext',
    );

    await ref.putFile(file, metadata);
    return ref.getDownloadURL();
  }

  Future<void> createPost({
    required String authorId,
    required String text,
    String? mediaUrl,
    required String mediaType,
  }) async {
    final doc = _postsCol.doc();

    await doc.set({
      'authorId': authorId,
      'text': text,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createPostWithUploadedMedia({
    required String authorId,
    required String text,
    required File file,
    required String mediaType,
  }) async {
    final doc = _postsCol.doc();
    final mediaUrl = await uploadPostMedia(
      file: file,
      postId: doc.id,
      mediaType: mediaType,
    );

    await doc.set({
      'authorId': authorId,
      'text': text,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> ensurePrivateChat({
    required String chatId,
    required String myProfileId,
    required String otherProfileId,
  }) async {
    final doc = _privateChatsCol.doc(chatId);

    await doc.set({
      'participantIds': [myProfileId, otherProfileId],
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendPrivateMessage({
    required String myProfileId,
    required String otherProfileId,
    required String text,
    String? mediaUrl,
    required String mediaType,
  }) async {
    final chatId = buildChatId(myProfileId, otherProfileId);
    await ensurePrivateChat(
      chatId: chatId,
      myProfileId: myProfileId,
      otherProfileId: otherProfileId,
    );

    final msgDoc = _privateChatsCol.doc(chatId).collection('messages').doc();

    await msgDoc.set({
      'senderId': myProfileId,
      'text': text,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final preview = text.trim().isNotEmpty
        ? text.trim()
        : (mediaType == 'image'
            ? '📷 Imagen'
            : mediaType == 'video'
                ? '🎥 Vídeo'
                : mediaType == 'gif'
                    ? '🖼️ GIF'
                    : '');

    await _privateChatsCol.doc(chatId).set({
      'participantIds': [myProfileId, otherProfileId],
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendPrivateMessageWithUploadedMedia({
    required String myProfileId,
    required String otherProfileId,
    required String text,
    required File file,
    required String mediaType,
  }) async {
    final chatId = buildChatId(myProfileId, otherProfileId);
    await ensurePrivateChat(
      chatId: chatId,
      myProfileId: myProfileId,
      otherProfileId: otherProfileId,
    );

    final msgDoc = _privateChatsCol.doc(chatId).collection('messages').doc();

    final mediaUrl = await uploadChatMedia(
      file: file,
      chatId: chatId,
      messageId: msgDoc.id,
      mediaType: mediaType,
    );

    await msgDoc.set({
      'senderId': myProfileId,
      'text': text,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final preview = text.trim().isNotEmpty
        ? text.trim()
        : (mediaType == 'image'
            ? '📷 Imagen'
            : mediaType == 'video'
                ? '🎥 Vídeo'
                : mediaType == 'gif'
                    ? '🖼️ GIF'
                    : '');

    await _privateChatsCol.doc(chatId).set({
      'participantIds': [myProfileId, otherProfileId],
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}