import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/profile_repository.dart';
import '../../models/profile.dart';
import '../services/poker_rooms_repo.dart';
import 'poker_room_screen.dart';

class PokerJoinByCodeScreen extends StatefulWidget {
  const PokerJoinByCodeScreen({
    super.key,
    required this.currentProfile,
    required this.profileRepository,
  });

  final Profile currentProfile;
  final ProfileRepository profileRepository;

  @override
  State<PokerJoinByCodeScreen> createState() => _PokerJoinByCodeScreenState();
}

class _PokerJoinByCodeScreenState extends State<PokerJoinByCodeScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final repo = PokerRoomsRepo(FirebaseFirestore.instance);

    return Scaffold(
      appBar: AppBar(title: const Text("Unirse por código")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: "Código",
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });

                      try {
                        final code = _code.text.trim().toUpperCase();
                        final roomId = await repo.findRoomByInviteCode(code);
                        if (roomId == null) {
                          setState(() => _error = "Código no válido o sala cerrada.");
                          return;
                        }

                        await repo.joinRoom(roomId: roomId, profileId: widget.currentProfile.id);

                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PokerRoomScreen(
                              roomId: roomId,
                              currentProfile: widget.currentProfile,
                              profileRepository: widget.profileRepository,
                            ),
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
              child: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Entrar"),
            ),
          ],
        ),
      ),
    );
  }
}
