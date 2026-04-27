import 'package:cloud_firestore/cloud_firestore.dart';

class SocialPost {
  final String id;
  final String authorId;
  final String text;
  final String? mediaUrl;
  final String mediaType; // text | image | video | gif
  final Timestamp createdAt;

  SocialPost({
    required this.id,
    required this.authorId,
    required this.text,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
  });

  factory SocialPost.fromMap(String id, Map<String, dynamic> data) {
    return SocialPost(
      id: id,
      authorId: (data['authorId'] ?? '') as String,
      text: (data['text'] ?? '') as String,
      mediaUrl: data['mediaUrl'] as String?,
      mediaType: (data['mediaType'] ?? 'text') as String,
      createdAt: (data['createdAt'] as Timestamp?) ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'text': text,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}