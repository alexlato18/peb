import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:peb/PEB/screeens/party_game_room_screen.dart';
import 'package:peb/PEB/services/party_game_repo.dart';
import 'package:peb/data/profile_repository.dart';
import 'package:peb/models/profile.dart';

class PartyGameJoinByCodeScreen extends StatefulWidget {
  const PartyGameJoinByCodeScreen({
    super.key,
    required this.currentProfile,
    required this.profileRepository,
  });

  final Profile currentProfile;
  final ProfileRepository profileRepository;

  @override
  State<PartyGameJoinByCodeScreen> createState() =>
      _PartyGameJoinByCodeScreenState();
}

class _PartyGameJoinByCodeScreenState extends State<PartyGameJoinByCodeScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = PartyGameRoomsRepo(FirebaseFirestore.instance);

    return Scaffold(
      appBar: AppBar(title: const Text("Unirse por código")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: "Código de sala",
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading
                  ? null
                  : () async {
                      final code = _codeCtrl.text.trim().toUpperCase();
                      if (code.isEmpty) return;

                      setState(() => _loading = true);

                      try {
                        final roomId = await repo.findRoomIdByCode(code);
                        if (roomId == null) {
                          throw Exception("No existe ninguna sala con ese código.");
                        }

                        await repo.joinRoom(
                          roomId: roomId,
                          profileId: widget.currentProfile.id,
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
                          SnackBar(content: Text("No se pudo entrar: $e")),
                        );
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
              child: Text(_loading ? "Entrando..." : "Entrar"),
            ),
          ],
        ),
      ),
    );
  }
}