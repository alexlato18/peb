import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/private_message.dart';
import '../models/social_post.dart';

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
        .map(
          (snap) => snap.docs
              .map((d) => SocialPost.fromMap(d.id, d.data()))
              .toList(),
        );
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
        .map(
          (snap) => snap.docs
              .map((d) => PrivateMessage.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Stream<int> watchUnreadCountWithUser({
    required String myProfileId,
    required String otherProfileId,
  }) {
    final chatId = buildChatId(myProfileId, otherProfileId);

    return watchMessages(chatId).map((messages) {
      return messages.where((m) {
        if (m.senderId == myProfileId) return false;
        return !m.readBy.contains(myProfileId);
      }).length;
    });
  }

  Future<void> markChatAsRead({
    required String chatId,
    required String myProfileId,
  }) async {
    final snap = await _privateChatsCol
        .doc(chatId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    var hasUpdates = false;

    for (final doc in snap.docs) {
      final msg = PrivateMessage.fromMap(doc.id, doc.data());

      if (msg.senderId == myProfileId) continue;
      if (msg.readBy.contains(myProfileId)) continue;

      batch.update(doc.reference, {
        'readBy': FieldValue.arrayUnion([myProfileId]),
      });
      hasUpdates = true;
    }

    if (hasUpdates) {
      await batch.commit();
    }

    await _privateChatsCol.doc(chatId).set({
      'unreadBy': FieldValue.arrayRemove([myProfileId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
      'likedBy': <String>[],
      'reactions': <String, String>{},
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
      'likedBy': <String>[],
      'reactions': <String, String>{},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> togglePostLike({
    required String postId,
    required String profileId,
  }) async {
    final ref = _postsCol.doc(postId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final likedBy = List<String>.from(data['likedBy'] as List? ?? const []);

      if (likedBy.contains(profileId)) {
        likedBy.remove(profileId);
      } else {
        likedBy.add(profileId);
      }

      tx.set(ref, {
        'likedBy': likedBy,
      }, SetOptions(merge: true));
    });
  }

  Future<void> setPostReaction({
    required String postId,
    required String profileId,
    required String emoji,
  }) async {
    await _postsCol.doc(postId).set({
      'reactions.$profileId': emoji,
    }, SetOptions(merge: true));
  }

  Future<void> removePostReaction({
    required String postId,
    required String profileId,
  }) async {
    await _postsCol.doc(postId).set({
      'reactions.$profileId': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  Future<void> addPostComment({
    required String postId,
    required String authorId,
    required String text,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    await _postsCol.doc(postId).collection('comments').add({
      'authorId': authorId,
      'text': cleanText,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchPostComments(String postId) {
    return _postsCol
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    });
  }

  Stream<int> watchTotalUnreadCount(String myProfileId) {
  return _privateChatsCol
      .where('participantIds', arrayContains: myProfileId)
      .snapshots()
      .map((snap) {
    var total = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      final unreadBy = List<String>.from(data['unreadBy'] as List? ?? const []);

      if (unreadBy.contains(myProfileId)) {
        total++;
      }
    }

    return total;
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
      'unreadBy': <String>[],
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
      'readBy': [myProfileId],
      'createdAt': FieldValue.serverTimestamp(),
    });

    final preview = _buildMessagePreview(text: text, mediaType: mediaType);

    await _privateChatsCol.doc(chatId).set({
      'participantIds': [myProfileId, otherProfileId],
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadBy': FieldValue.arrayUnion([otherProfileId]),
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
      'readBy': [myProfileId],
      'createdAt': FieldValue.serverTimestamp(),
    });

    final preview = _buildMessagePreview(text: text, mediaType: mediaType);

    await _privateChatsCol.doc(chatId).set({
      'participantIds': [myProfileId, otherProfileId],
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadBy': FieldValue.arrayUnion([otherProfileId]),
    }, SetOptions(merge: true));
  }

  String _buildMessagePreview({
    required String text,
    required String mediaType,
  }) {
    final clean = text.trim();

    if (clean.isNotEmpty) return clean;

    if (mediaType == 'image') return '📷 Imagen';
    if (mediaType == 'video') return '🎥 Vídeo';
    if (mediaType == 'gif') return '🖼️ GIF';

    return '';
  }
}