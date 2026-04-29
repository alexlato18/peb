import 'package:cloud_firestore/cloud_firestore.dart';

class PrivateMessage {
  final String id;
  final String senderId;
  final String text;
  final String? mediaUrl;
  final String mediaType; // text | image | video | gif
  final Timestamp createdAt;

  final List<String> readBy;

  PrivateMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    required this.readBy,
  });

  factory PrivateMessage.fromMap(String id, Map<String, dynamic> data) {
    return PrivateMessage(
      id: id,
      senderId: (data['senderId'] ?? '') as String,
      text: (data['text'] ?? '') as String,
      mediaUrl: data['mediaUrl'] as String?,
      mediaType: (data['mediaType'] ?? 'text') as String,
      createdAt: (data['createdAt'] as Timestamp?) ?? Timestamp.now(),
      readBy: List<String>.from(data['readBy'] as List? ?? const []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'createdAt': createdAt,
      'readBy': readBy,
    };
  }
}