import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';

import '../data/profile_repository.dart';
import '../services/auth_service.dart';
import 'bootstrap_screen.dart';

// ✅ NUEVO
import '../data/tag_style_repository.dart';
import '../widgets/tag_chip.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.authService,
    required this.profileRepository,
  });

  final AuthService authService;
  final ProfileRepository profileRepository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _profileId;
  bool _busy = false;

  // ✅ NUEVO
  late final TagStyleRepository _tagStyleRepo;

  @override
  void initState() {
    super.initState();
    _tagStyleRepo = TagStyleRepository(FirebaseFirestore.instance);
    _loadProfileId();
  }

  Future<void> _loadProfileId() async {
    final id = await widget.authService.getSavedProfileId();
    if (!mounted) return;
    setState(() => _profileId = id);
  }

  DocumentReference<Map<String, dynamic>> _profileRef(String profileId) {
    return FirebaseFirestore.instance
        .collection('groups')
        .doc('peb')
        .collection('profiles')
        .doc(profileId);
  }

  String _generateSalt32() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _changeName({
    required String profileId,
    required String current,
  }) async {
    final ctrl = TextEditingController(text: current);

    final newName = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar nombre'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Nombre de perfil',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(ctrl.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    setState(() => _busy = true);
    try {
      await _profileRef(profileId).update({'name': newName});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePin({required String profileId}) async {
    final pinCtrl = TextEditingController();

    final pin = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar PIN'),
        content: TextField(
          controller: pinCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Nuevo PIN (6 dígitos)',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(pinCtrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (pin == null) return;

    final isValid = RegExp(r'^\d{6}$').hasMatch(pin);
    if (!isValid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El PIN debe tener exactamente 6 dígitos.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final newSalt = _generateSalt32();
      final newHash = widget.authService.hashPin(pin: pin, salt: newSalt);

      await _profileRef(profileId).update({
        'pinSalt': newSalt,
        'pinHASH': newHash,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN actualizado ✅')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeAvatar({required String profileId}) async {
    await widget.authService.ensureAnonymousSession();

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;

    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();

      final storagePath = 'groups/peb/profiles/$profileId/avatar.jpg';
      final ref = FirebaseStorage.instance.ref(storagePath);

      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final url = await ref.getDownloadURL();

      await _profileRef(profileId).update({'avatarURL': url});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar actualizado ✅')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await widget.authService.logoutLocal();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => BootstrapScreen(
          profileRepository: widget.profileRepository,
          authService: widget.authService,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileId = _profileId;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: profileId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _profileRef(profileId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!.data() ?? {};
                final name = (data['name'] ?? '') as String;
                final avatarURL = data['avatarURL'] as String?;
                final tags =
                    (data['tags'] as List?)?.cast<String>() ?? const <String>[];

                return AbsorbPointer(
                  absorbing: _busy,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(60),
                          onTap: () => _changeAvatar(profileId: profileId),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 54,
                                backgroundImage:
                                    (avatarURL != null && avatarURL.isNotEmpty)
                                        ? NetworkImage(avatarURL)
                                        : null,
                                child: (avatarURL == null || avatarURL.isEmpty)
                                    ? const Icon(Icons.person, size: 48)
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit, size: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: InkWell(
                          onTap: () =>
                              _changeName(profileId: profileId, current: name),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(
                              name.isEmpty ? 'Sin nombre' : name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ✅ TAGS con estilos
                      Center(
                        child: tags.isEmpty
                            ? Opacity(
                                opacity: 0.7,
                                child: Text(
                                  'Sin tags',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              )
                            : StreamBuilder<Map<String, TagStyle>>(
                                stream: _tagStyleRepo.watchStyles(),
                                builder: (context, snapStyles) {
                                  final styles =
                                      snapStyles.data ?? const <String, TagStyle>{};

                                  return Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: tags.map((t) {
                                      final clean = t.trim();
                                      final style =
                                          styles[clean] ?? TagStyle.fallback;

                                      return TagChip(
                                        label: clean,
                                        style: style,
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                      ),

                      const SizedBox(height: 26),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _changePin(profileId: profileId),
                          icon: const Icon(Icons.lock_reset),
                          label: const Text('Cambiar PIN'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Cerrar sesión'),
                        ),
                      ),
                      if (_busy) ...[
                        const SizedBox(height: 18),
                        const Center(child: CircularProgressIndicator()),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
