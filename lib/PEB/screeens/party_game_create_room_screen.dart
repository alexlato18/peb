import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:peb/PEB/screeens/party_game_room_screen.dart';
import 'package:peb/PEB/services/party_game_repo.dart';
import 'package:peb/data/profile_repository.dart';
import 'package:peb/models/profile.dart';

class PartyGameCreateRoomScreen extends StatefulWidget {
  const PartyGameCreateRoomScreen({
    super.key,
    required this.currentProfile,
    required this.profileRepository,
  });

  final Profile currentProfile;
  final ProfileRepository profileRepository;

  @override
  State<PartyGameCreateRoomScreen> createState() =>
      _PartyGameCreateRoomScreenState();
}

class _PartyGameCreateRoomScreenState extends State<PartyGameCreateRoomScreen> {
  final _titleCtrl = TextEditingController();
  bool _isPublic = true;
  int _maxPlayers = 4;
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = PartyGameRoomsRepo(FirebaseFirestore.instance);

    return Scaffold(
      appBar: AppBar(title: const Text("Crear sala")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: "Nombre de la sala",
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _maxPlayers,
              decoration: const InputDecoration(
                labelText: "Máximo de jugadores",
              ),
              items: const [2, 3, 4, 5, 6]
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text("$e jugadores"),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _maxPlayers = v);
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _isPublic,
              title: const Text("Sala pública"),
              onChanged: (v) => setState(() => _isPublic = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading
                  ? null
                  : () async {
                      final title = _titleCtrl.text.trim().isEmpty
                          ? "Sala de ${widget.currentProfile.name}"
                          : _titleCtrl.text.trim();

                      setState(() => _loading = true);

                      try {
                        final roomId = await repo.createRoom(
                          title: title,
                          hostProfileId: widget.currentProfile.id,
                          maxPlayers: _maxPlayers,
                          isPublic: _isPublic,
                        );

                        if (!context.mounted) return;

                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PartyGameRoomScreen(
                              roomId: roomId,
                              currentProfile: widget.currentProfile,
                              profileRepository: widget.profileRepository,
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error al crear la sala: $e")),
                        );
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
              child: Text(_loading ? "Creando..." : "Crear sala"),
            ),
          ],
        ),
      ),
    );
  }
}