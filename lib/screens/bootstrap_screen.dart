import 'package:flutter/material.dart';
import '../data/profile_repository.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({
    super.key,
    required this.profileRepository,
    required this.authService,
  });

  final ProfileRepository profileRepository;
  final AuthService authService;

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  bool _loading = true;
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final ok = await widget.authService.tryAutoLogin();
    if (!mounted) return;
    setState(() {
      _logged = ok;
      _loading = false;
    });
  }

  void _goHome() {
    setState(() => _logged = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_logged) {
      return HomeScreen(
        authService: widget.authService,
        profileRepository: widget.profileRepository,
      );
    }

    return LoginScreen(
      profileRepository: widget.profileRepository,
      authService: widget.authService,
      onLoggedIn: _goHome,
    );
  }
}
