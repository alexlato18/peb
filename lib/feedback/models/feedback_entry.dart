import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackEntry {
  final String id;
  final String profileId;
  final String type; // bug | recommendation
  final String text;
  final String status; // pending | valid | rejected
  final Timestamp createdAt;
  final Timestamp? reviewedAt;
  final String? reviewedBy;

  FeedbackEntry({
    required this.id,
    required this.profileId,
    required this.type,
    required this.text,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  factory FeedbackEntry.fromMap(String id, Map<String, dynamic> data) {
    return FeedbackEntry(
      id: id,
      profileId: (data['profileId'] ?? '') as String,
      type: (data['type'] ?? 'bug') as String,
      text: (data['text'] ?? '') as String,
      status: (data['status'] ?? 'pending') as String,
      createdAt: (data['createdAt'] as Timestamp?) ?? Timestamp.now(),
      reviewedAt: data['reviewedAt'] as Timestamp?,
      reviewedBy: data['reviewedBy'] as String?,
    );
  }
}