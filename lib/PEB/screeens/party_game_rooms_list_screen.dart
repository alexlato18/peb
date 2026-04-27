import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:peb/PEB/screeens/party_game_create_room_screen.dart';
import 'package:peb/PEB/screeens/party_game_join_by_code_screen.dart';
import 'package:peb/PEB/screeens/party_game_room_screen.dart';
import 'package:peb/PEB/services/party_game_repo.dart';
import 'package:peb/data/profile_repository.dart';
import 'package:peb/models/profile.dart';

class PartyGameRoomsListScreen extends StatelessWidget {
  const PartyGameRoomsListScreen({
    super.key,
    required this.currentProfile,
    required this.profileRepository,
  });

  final Profile currentProfile;
  final ProfileRepository profileRepository;

  @override
  Widget build(BuildContext context) {
    final repo = PartyGameRoomsRepo(FirebaseFirestore.instance);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Juego de cartas · Salas públicas"),
        actions: [
          IconButton(
            tooltip: "Unirse por código",
            icon: const Icon(Icons.key),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PartyGameJoinByCodeScreen(
                    currentProfile: currentProfile,
                    profileRepository: profileRepository,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: "Crear sala",
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PartyGameCreateRoomScreen(
                    currentProfile: currentProfile,
                    profileRepository: profileRepository,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: repo.watchPublicRooms(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Error: ${snap.error}",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = snap.data!;
          if (rooms.isEmpty) {
            return const Center(
              child: Text("No hay salas públicas ahora mismo."),
            );
          }

          return ListView.separated(
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = rooms[i];
              return ListTile(
                title: Text(r.title),
                subtitle: Text("Jugadores: ${r.playerCount}/${r.maxPlayers}"),
                trailing: const Icon(Icons.login),
                onTap: () async {
                  try {
                    await repo.joinRoom(
                      roomId: r.id,
                      profileId: currentProfile.id,
                    );

                    if (!context.mounted) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PartyGameRoomScreen(
                          roomId: r.id,
                          currentProfile: currentProfile,
                          profileRepository: profileRepository,
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("No se pudo entrar: $e")),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}