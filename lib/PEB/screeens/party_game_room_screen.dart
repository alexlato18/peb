import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:peb/PEB/screeens/party_game_table_screen.dart';
import 'package:peb/PEB/services/party_game_repo.dart';
import 'package:peb/data/profile_repository.dart';
import 'package:peb/models/profile.dart';

class PartyGameRoomScreen extends StatelessWidget {
  const PartyGameRoomScreen({
    super.key,
    required this.roomId,
    required this.currentProfile,
    required this.profileRepository,
  });

  final String roomId;
  final Profile currentProfile;
  final ProfileRepository profileRepository;

  Future<void> _closeRoom(BuildContext context) async {
    final repo = PartyGameRoomsRepo(FirebaseFirestore.instance);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cerrar sala"),
        content: const Text("¿Seguro que quieres cerrar la sala?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await repo.deleteRoom(roomId);

      if (!context.mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo cerrar la sala: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = PartyGameRoomsRepo(FirebaseFirestore.instance);

    return StreamBuilder(
      stream: repo.watchRoom(roomId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text("Lobby")),
            body: Center(child: Text("Error: ${snap.error}")),
          );
        }

        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text("Lobby")),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final room = snap.data!;
        final isHost = room.hostProfileId == currentProfile.id;

        if (room.status == 'playing') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => PartyGameTableScreen(
                  roomId: roomId,
                  currentProfile: currentProfile,
                  profileRepository: profileRepository,
                ),
              ),
            );
          });

          return Scaffold(
            appBar: AppBar(
              title: const Text("Lobby"),
              actions: [
                if (isHost)
                  IconButton(
                    tooltip: "Cerrar sala",
                    icon: const Icon(Icons.close),
                    onPressed: () => _closeRoom(context),
                  ),
              ],
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Lobby"),
            actions: [
              if (isHost)
                IconButton(
                  tooltip: "Cerrar sala",
                  icon: const Icon(Icons.close),
                  onPressed: () => _closeRoom(context),
                ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Jugadores: ${room.playerCount}/${room.maxPlayers}",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: room.joinCode),
                        );

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Código copiado al portapapeles"),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text("Copiar código"),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.separated(
                    itemCount: room.playerIds.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final playerId = room.playerIds[index];

                      return FutureBuilder<Profile?>(
                        future: profileRepository.getProfileById(playerId),
                        builder: (context, profileSnap) {
                          if (profileSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const _LobbyPlayerTileLoading();
                          }

                          final player = profileSnap.data;
                          if (player == null) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  CircleAvatar(radius: 22),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text("Jugador desconocido"),
                                  ),
                                ],
                              ),
                            );
                          }

                          final isPlayerHost = player.id == room.hostProfileId;

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: player.avatarURL != null &&
                                          player.avatarURL!.isNotEmpty
                                      ? NetworkImage(player.avatarURL!)
                                      : null,
                                  child: player.avatarURL == null ||
                                          player.avatarURL!.isEmpty
                                      ? Text(
                                          player.name.isNotEmpty
                                              ? player.name[0].toUpperCase()
                                              : "?",
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    player.name,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                if (isPlayerHost)
                                  const Icon(
                                    Icons.workspace_premium,
                                    size: 22,
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (isHost)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        try {
                          await repo.startGame(roomId: roomId);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "No se pudo iniciar la partida: $e",
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("Empezar partida"),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LobbyPlayerTileLoading extends StatelessWidget {
  const _LobbyPlayerTileLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          CircleAvatar(radius: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text("Cargando jugador..."),
          ),
        ],
      ),
    );
  }
}