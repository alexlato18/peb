import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:peb/PEB/models/party_game_match_state.dart';
import 'package:peb/PEB/models/party_game_room.dart';
import 'package:peb/PEB/services/party_game_repo.dart';
import 'package:peb/data/profile_repository.dart';
import 'package:peb/models/profile.dart';

class PartyGameTableScreen extends StatefulWidget {
  const PartyGameTableScreen({
    super.key,
    required this.roomId,
    required this.currentProfile,
    required this.profileRepository,
  });

  final String roomId;
  final Profile currentProfile;
  final ProfileRepository profileRepository;

  @override
  State<PartyGameTableScreen> createState() => _PartyGameTableScreenState();
}

class _PartyGameTableScreenState extends State<PartyGameTableScreen> {
  int _viewedPlayerIndex = 0;

  Future<void> _onCloseRoom(BuildContext context, PartyGameRoom room) async {
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

    final repo = PartyGameRoomsRepo(FirebaseFirestore.instance);

    try {
      await repo.deleteRoom(widget.roomId);

      if (!context.mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cerrar la sala: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = PartyGameRoomsRepo(FirebaseFirestore.instance);

    return StreamBuilder<PartyGameRoom>(
      stream: repo.watchRoom(widget.roomId),
      builder: (context, roomSnap) {
        if (roomSnap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text("Partida")),
            body: Center(child: Text("Error: ${roomSnap.error}")),
          );
        }

        if (!roomSnap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text("Partida")),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final room = roomSnap.data!;
        final isHost = room.hostProfileId == widget.currentProfile.id;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Partida"),
            actions: [
              if (isHost)
                IconButton(
                  tooltip: "Cerrar sala",
                  icon: const Icon(Icons.close),
                  onPressed: () => _onCloseRoom(context, room),
                ),
            ],
          ),
          body: StreamBuilder<PartyGameMatchState>(
            stream: repo.watchMatch(widget.roomId),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text("Error: ${snap.error}"));
              }

              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final match = snap.data!;
              final playerOrder = match.playerOrder;

              if (playerOrder.isEmpty) {
                return const Center(
                  child: Text("No hay jugadores en la partida."),
                );
              }

              final myIndex = playerOrder.indexOf(widget.currentProfile.id);
              if (myIndex != -1 && _viewedPlayerIndex >= playerOrder.length) {
                _viewedPlayerIndex = myIndex;
              }

              if (myIndex != -1 &&
                  _viewedPlayerIndex == 0 &&
                  playerOrder.first != widget.currentProfile.id) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    _viewedPlayerIndex = myIndex;
                  });
                });
              }

              final viewedPlayerId = playerOrder[_viewedPlayerIndex];
              final viewedPlayerState = match.players[viewedPlayerId];
              final myState = match.players[widget.currentProfile.id];

              return Column(
                children: [
                  _TopRoundInfo(
                    round: match.round,
                    isMyTurn: match.turnPlayerId == widget.currentProfile.id,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: _ViewedPlayerHeader(
                      playerIds: playerOrder,
                      currentIndex: _viewedPlayerIndex,
                      profileRepository: widget.profileRepository,
                      onPrevious: playerOrder.length <= 1
                          ? null
                          : () {
                              setState(() {
                                _viewedPlayerIndex =
                                    (_viewedPlayerIndex - 1 + playerOrder.length) %
                                        playerOrder.length;
                              });
                            },
                      onNext: playerOrder.length <= 1
                          ? null
                          : () {
                              setState(() {
                                _viewedPlayerIndex =
                                    (_viewedPlayerIndex + 1) %
                                        playerOrder.length;
                              });
                            },
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _ViewedTableCard(
                        viewedPlayerId: viewedPlayerId,
                        viewedPlayerState: viewedPlayerState,
                        profileRepository: widget.profileRepository,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  SizedBox(
                    height: 210,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _MyHandPanel(
                        myState: myState,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _TopRoundInfo extends StatelessWidget {
  const _TopRoundInfo({
    required this.round,
    required this.isMyTurn,
  });

  final int round;
  final bool isMyTurn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Text(
            "Ronda $round",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          Chip(
            label: Text(isMyTurn ? "Tu turno" : "Esperando turno"),
          ),
        ],
      ),
    );
  }
}

class _ViewedPlayerHeader extends StatelessWidget {
  const _ViewedPlayerHeader({
    required this.playerIds,
    required this.currentIndex,
    required this.profileRepository,
    required this.onPrevious,
    required this.onNext,
  });

  final List<String> playerIds;
  final int currentIndex;
  final ProfileRepository profileRepository;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final viewedPlayerId = playerIds[currentIndex];

    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: FutureBuilder<Profile?>(
            future: profileRepository.getProfileById(viewedPlayerId),
            builder: (context, snap) {
              final name = snap.data?.name ?? "Jugador";
              return Center(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _ViewedTableCard extends StatelessWidget {
  const _ViewedTableCard({
    required this.viewedPlayerId,
    required this.viewedPlayerState,
    required this.profileRepository,
  });

  final String viewedPlayerId;
  final PartyGamePlayerState? viewedPlayerState;
  final ProfileRepository profileRepository;

  @override
  Widget build(BuildContext context) {
    if (viewedPlayerState == null) {
      return const Center(child: Text("No se pudo cargar la mesa."));
    }

    final state = viewedPlayerState!;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<Profile?>(
            future: profileRepository.getProfileById(viewedPlayerId),
            builder: (context, snap) {
              final name = snap.data?.name ?? "Jugador";
              return Text(
                "Mesa de $name",
                style: Theme.of(context).textTheme.titleMedium,
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InfoBox(label: "Dinero", value: "${state.money} \$"),
              _InfoBox(label: "Puntos", value: "${state.score}"),
              _InfoBox(
                label: "Personajes",
                value: "${state.tableCharacterCardIds.length}",
              ),
              _InfoBox(
                label: "Eventos",
                value: "${state.tableEventCardIds.length}",
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _ZoneBox(
                    title: "Personajes en mesa",
                    items: state.tableCharacterCardIds,
                    emptyText: "Sin personajes jugados",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ZoneBox(
                    title: "Eventos en mesa",
                    items: state.tableEventCardIds,
                    emptyText: "Sin eventos activos",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyHandPanel extends StatelessWidget {
  const _MyHandPanel({
    required this.myState,
  });

  final PartyGamePlayerState? myState;

  @override
  Widget build(BuildContext context) {
    if (myState == null) {
      return const Center(child: Text("No se pudo cargar tu mano."));
    }

    final state = myState!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Tu mano",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _ZoneBox(
                  title: "Personajes en mano",
                  items: state.handCharacterCardIds,
                  emptyText: "Sin cartas de personaje",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ZoneBox(
                  title: "Eventos en mano",
                  items: state.handEventCardIds,
                  emptyText: "Sin cartas de evento",
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ZoneBox extends StatelessWidget {
  const _ZoneBox({
    required this.title,
    required this.items,
    required this.emptyText,
  });

  final String title;
  final List<String> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 10),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      emptyText,
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(items[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}