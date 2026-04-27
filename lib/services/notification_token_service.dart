import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

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
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (Platform.isIOS) {
        String? apnsToken;

        for (int i = 0; i < 5; i++) {
          apnsToken = await messaging.getAPNSToken();
          if (apnsToken != null && apnsToken.trim().isNotEmpty) break;
          await Future.delayed(const Duration(seconds: 1));
        }

        if (apnsToken == null || apnsToken.trim().isEmpty) {
          debugPrint('APNS token todavía no disponible. Se continúa sin FCM token.');
          _attachRefreshListener(uid);
          return;
        }
      }

      final token = await messaging.getToken();

      if (token != null && token.trim().isNotEmpty) {
        await _saveToken(uid: uid, token: token);
      }

      _attachRefreshListener(uid);
    } catch (e) {
      debugPrint('No se pudo guardar el token FCM: $e');
      _attachRefreshListener(uid);
    }
  }

  void _attachRefreshListener(String uid) {
    if (_refreshListenerAttached) return;
    _refreshListenerAttached = true;

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        if (newToken.trim().isEmpty) return;
        await _saveToken(uid: uid, token: newToken);
      } catch (e) {
        debugPrint('No se pudo actualizar el token FCM: $e');
      }
    });
  }

  Future<void> _saveToken({
    required String uid,
    required String token,
  }) async {
    await _db.doc('groups/$groupId/sessions/$uid').set({
      'fcmToken': token,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearTokenFromSession({
    required String uid,
  }) async {
    try {
      await _db.doc('groups/$groupId/sessions/$uid').set({
        'fcmToken': FieldValue.delete(),
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('No se pudo limpiar el token FCM: $e');
    }
  }
}