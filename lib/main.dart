import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'data/profile_repository.dart';
import 'services/auth_service.dart';
import 'screens/bootstrap_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
