import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/profile_repository.dart';
import 'notification_token_service.dart';

class AuthService {
  AuthService({
    required FirebaseAuth auth,
    required FirebaseFirestore db,
    required ProfileRepository profiles,
    required NotificationTokenService notificationTokenService,
  })  : _auth = auth,
        _db = db,
        _profiles = profiles,
        _notificationTokenService = notificationTokenService;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final ProfileRepository _profiles;
  final NotificationTokenService _notificationTokenService;

  static const _kSelectedProfileId = 'selected_profile_id';

  Future<String?> getSavedProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSelectedProfileId);
  }

  Future<String?> getSelectedProfileId() => getSavedProfileId();

  Future<bool> tryAutoLogin() async {
    final savedId = await getSavedProfileId();
    if (savedId == null) return false;

    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
    final uid = _auth.currentUser!.uid;

    final profile = await _profiles.getProfileById(savedId);
    if (profile == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSelectedProfileId);
      return false;
    }

    await _db.doc('groups/peb/sessions/$uid').set({
      'profileId': profile.id,
      'role': profile.role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _notificationTokenService.saveTokenInSession(uid: uid);

    return true;
  }

  Future<void> ensureAnonymousSession() async {
    if (FirebaseAuth.instance.currentUser != null) return;
    await FirebaseAuth.instance.signInAnonymously();
  }

  Future<void> loginWithProfile({
    required String profileId,
    required String pin,
  }) async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
    final uid = _auth.currentUser!.uid;

    final profile = await _profiles.getProfileById(profileId);
    if (profile == null) throw Exception('Perfil no encontrado.');

    final computed = hashPin(pin: pin, salt: profile.pinSalt);
    if (computed != profile.pinHASH) {
      throw Exception('PIN incorrecto.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedProfileId, profileId);

    await _db.doc('groups/peb/sessions/$uid').set({
      'profileId': profileId,
      'role': profile.role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _notificationTokenService.saveTokenInSession(uid: uid);
  }

  Future<bool> isLoggedInLocally() async {
    final savedId = await getSavedProfileId();
    if (savedId == null) return false;

    final profile = await _profiles.getProfileById(savedId);
    if (profile == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSelectedProfileId);
      return false;
    }
    return true;
  }

  Future<void> logoutLocal() async {
    final uid = _auth.currentUser?.uid;

    if (uid != null) {
      await _notificationTokenService.clearTokenFromSession(uid: uid);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSelectedProfileId);
  }

  String hashPin({required String pin, required String salt}) {
    final bytes = utf8.encode('$salt$pin');
    return sha256.convert(bytes).toString();
  }
}