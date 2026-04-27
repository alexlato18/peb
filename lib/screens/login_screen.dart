import 'package:flutter/material.dart';
import '../data/profile_repository.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.profileRepository,
    required this.authService,
    required this.onLoggedIn,
  });

  final ProfileRepository profileRepository;
  final AuthService authService;
  final VoidCallback onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _selectedProfileId;
  final _pinCtrl = TextEditingController();
  final _pinFocus = FocusNode();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _selectedProfileId != null && _pinCtrl.text.trim().isNotEmpty && !_loading;

  Future<void> _submit(List<Profile> profiles) async {
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final id = _selectedProfileId!;
      final exists = profiles.any((p) => p.id == id);
      if (!exists) throw Exception('Perfil no válido.');

      await widget.authService.loginWithProfile(
        profileId: id,
        pin: _pinCtrl.text.trim(),
      );

      if (!mounted) return;
      widget.onLoggedIn();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      _pinFocus.requestFocus();
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: StreamBuilder<List<Profile>>(
              stream: widget.profileRepository.watchProfiles(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error cargando perfiles:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final profiles = snapshot.data ?? [];

                if (profiles.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay perfiles (o no se ha podido conectar a Firestore).',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (_selectedProfileId != null &&
                    profiles.isNotEmpty &&
                    !profiles.any((p) => p.id == _selectedProfileId)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() => _selectedProfileId = null);
                  });
                }

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'PEB',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 24),

                    DropdownButtonFormField<String>(
                      value: _selectedProfileId,
                      items: profiles
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p.id,
                              child: Text(p.name),
                            ),
                          )
                          .toList(),
                      onChanged: _loading
                          ? null
                          : (id) {
                              setState(() {
                                _selectedProfileId = id;
                                _pinCtrl.clear();
                                _error = null;
                              });

                              if (id != null) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  _pinFocus.requestFocus();
                                });
                              }
                            },
                      decoration: const InputDecoration(
                        labelText: 'Selecciona perfil',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: _pinCtrl,
                      focusNode: _pinFocus,
                      enabled: _selectedProfileId != null && !_loading,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: false,
                        signed: false,
                      ),
                      textInputAction: TextInputAction.done,
                      obscureText: true,
                      maxLength: 6,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: const InputDecoration(
                        labelText: 'PIN',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      onChanged: (_) {
                        if (_error != null) {
                          setState(() => _error = null);
                        }
                      },
                      onSubmitted: (_) {
                        if (_canSubmit) _submit(profiles);
                      },
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],

                    const SizedBox(height: 16),

                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _pinCtrl,
                      builder: (context, value, _) {
                        final canSubmit =
                            _selectedProfileId != null &&
                            value.text.trim().isNotEmpty &&
                            !_loading;

                        return SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: canSubmit ? () => _submit(profiles) : null,
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Entrar'),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}