import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'data/profile_repository.dart';
import 'services/auth_service.dart';
import 'screens/bootstrap_screen.dart';

Future<void> _ensureSessionDoc() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final ref = FirebaseFirestore.instance.doc('groups/peb/sessions/${user.uid}');
  final snap = await ref.get();
  if (!snap.exists) {
    await ref.set({
      'profileId': null,
      'role': 'COMUN',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  } else {
    await ref.set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }
  await _ensureSessionDoc();

  runApp(const PEBApp());
}


class PEBApp extends StatelessWidget {
  const PEBApp({super.key});

  @override
  Widget build(BuildContext context) {
    final profileRepo = ProfileRepository(FirebaseFirestore.instance);
    final authService = AuthService(
      auth: FirebaseAuth.instance,
      db: FirebaseFirestore.instance,
      profiles: profileRepo,
    );


    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PEB',
      theme: ThemeData(useMaterial3: true),
      home: BootstrapScreen(
        profileRepository: profileRepo,
        authService: authService,
      ),
    );
  }
}
