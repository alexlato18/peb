import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationTokenService {
  NotificationTokenService({
    required FirebaseFirestore db,
    this.groupId = 'peb',
  }) : _db = db;

  final FirebaseFirestore _db;
  final String groupId;

  bool _refreshListenerAttached = false;

  Future<void> saveTokenInSession({
    required String uid,
  }) async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission();

    final token = await messaging.getToken();
    if (token != null && token.trim().isNotEmpty) {
      await _db.doc('groups/$groupId/sessions/$uid').set({
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (_refreshListenerAttached) return;
    _refreshListenerAttached = true;

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (newToken.trim().isEmpty) return;

      await _db.doc('groups/$groupId/sessions/$uid').set({
        'fcmToken': newToken,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> clearTokenFromSession({
    required String uid,
  }) async {
    await _db.doc('groups/$groupId/sessions/$uid').set({
      'fcmToken': FieldValue.delete(),
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}