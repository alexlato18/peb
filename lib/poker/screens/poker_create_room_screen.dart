import 'package:flutter/material.dart';
import '../../data/profile_repository.dart';
import '../../models/profile.dart';
import '../services/poker_rooms_repo.dart';
import 'poker_room_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PokerCreateRoomScreen extends StatefulWidget {
  const PokerCreateRoomScreen({
    super.key,
    required this.currentProfile,
    required this.profileRepository,
  });

  final Profile currentProfile;
  final ProfileRepository profileRepository;

  @override
  State<PokerCreateRoomScreen> createState() => _PokerCreateRoomScreenState();
}

class _PokerCreateRoomScreenState extends State<PokerCreateRoomScreen> {
  final _title = TextEditingController(text: "Texas Hold'em");
  String _visibility = "PUBLIC"; // or INVITE_ONLY
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final repo = PokerRoomsRepo(FirebaseFirestore.instance);

    return Scaffold(
      appBar: AppBar(title: const Text("Crear sala")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: "Nombre"),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _visibility,
              items: const [
                DropdownMenuItem(value: "PUBLIC", child: Text("PUBLIC")),
                DropdownMenuItem(value: "INVITE_ONLY", child: Text("INVITE_ONLY")),
              ],
              onChanged: (v) => setState(() => _visibility = v ?? "PUBLIC"),
              decoration: const InputDecoration(labelText: "Privacidad"),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      try {
                        final roomId = await repo.createRoom(
                          title: _title.text.trim(),
                          hostProfileId: widget.currentProfile.id,
                          visibility: _visibility,
                        );

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
              icon: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: const Text("Crear"),
            ),
          ],
        ),
      ),
    );
  }
}
