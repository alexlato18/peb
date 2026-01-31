import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/profile_repository.dart';

class AuthService {
  AuthService({
    required FirebaseAuth auth,
    required FirebaseFirestore db,
    required ProfileRepository profiles,
  })  : _auth = auth,
        _db = db,
        _profiles = profiles;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final ProfileRepository _profiles;

  static const _kSelectedProfileId = 'selected_profile_id';

  /// Mantengo este nombre porque tú lo pediste explícitamente.
  Future<String?> getSavedProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSelectedProfileId);
  }

  /// Alias útil (por si en algún archivo lo llamas así)
  Future<String?> getSelectedProfileId() => getSavedProfileId();

  /// Intenta autologin si hay profileId guardado y sigue existiendo en Firestore.
  /// NO valida PIN (porque el PIN ya se validó cuando se guardó el perfil).
  /// Además, asegura que exista sesión anónima y escribe sessions/{uid} para reglas.
  Future<bool> tryAutoLogin() async {
    final savedId = await getSavedProfileId();
    if (savedId == null) return false;

    // Asegura auth anónimo
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
    final uid = _auth.currentUser!.uid;

    // Comprueba que el perfil exista
    final profile = await _profiles.getProfileById(savedId);
    if (profile == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSelectedProfileId);
      return false;
    }

    // Re-escribe session para que reglas de Firestore/Storage funcionen
    await _db.doc('groups/peb/sessions/$uid').set({
      'profileId': profile.id,
      'role': profile.role, // requiere Profile.role
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }
Future<void> ensureAnonymousSession() async {
  if (FirebaseAuth.instance.currentUser != null) return;
  await FirebaseAuth.instance.signInAnonymously();
}

  /// Login completo: auth anónimo + validar PIN del perfil + guardar en prefs + session doc
  Future<void> loginWithProfile({
    required String profileId,
    required String pin,
  }) async {
    // 1) Asegura auth anónimo
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
    final uid = _auth.currentUser!.uid;

    // 2) Lee perfil
    final profile = await _profiles.getProfileById(profileId);
    if (profile == null) throw Exception('Perfil no encontrado.');

    // 3) Valida PIN
    final computed = hashPin(pin: pin, salt: profile.pinSalt);
    if (computed != profile.pinHASH) {
      throw Exception('PIN incorrecto.');
    }

    // 4) Guarda perfil seleccionado
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedProfileId, profileId);

    // 5) Escribe session para reglas
    await _db.doc('groups/peb/sessions/$uid').set({
      'profileId': profileId,
      'role': profile.role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
  
  /// Por compatibilidad con tu Bootstrap/Login actual:
  /// Si en algún lado llamabas "isLoggedInLocally", lo dejamos también.
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSelectedProfileId);

    // No hago signOut() porque en tu app no es necesario,
    // pero si quieres "cerrar" anónimo también:
    // await _auth.signOut();
  }

  String hashPin({required String pin, required String salt}) {
    final bytes = utf8.encode('$salt$pin');
    return sha256.convert(bytes).toString();
  }
}
