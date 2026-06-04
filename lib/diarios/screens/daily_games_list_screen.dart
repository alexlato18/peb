import 'package:flutter/material.dart';

import '../../data/profile_repository.dart';
import '../models/daily_game_models.dart';
import '../repositories/daily_games_repository.dart';
import 'daily_game_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../fish/repositories/fish_repository.dart';
import '../../fish/screens/fish_pack_screen.dart';

class DailyGamesListScreen extends StatefulWidget {
  const DailyGamesListScreen({
    super.key,
    required this.currentProfileId,
    required this.profileRepository,
    required this.repository,
  });

  final String currentProfileId;
  final ProfileRepository profileRepository;
  final DailyGamesRepository repository;

  @override
  State<DailyGamesListScreen> createState() => _DailyGamesListScreenState();
}

class _DailyGamesListScreenState extends State<DailyGamesListScreen> {
  @override
  void initState() {
    super.initState();
    widget.repository.ensureTodayChallenges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Juegos diarios'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.set_meal),
        label: const Text('Pecera'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FishPackScreen(
                currentProfileId: widget.currentProfileId,
                profileRepository: widget.profileRepository,
                fishRepository: FishRepository(FirebaseFirestore.instance),
              ),
            ),
          );
        },
      ),
      body: StreamBuilder<List<DailyGameCatalogItem>>(
        stream: widget.repository.watchCatalog(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final games = snap.data!;
          if (games.isEmpty) {
            return const Center(child: Text('No hay juegos disponibles.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final game = games[index];
              return _GameCard(
                game: game,
                currentProfileId: widget.currentProfileId,
                repository: widget.repository,
              );
            },
          );
        },
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.game,
    required this.currentProfileId,
    required this.repository,
  });

  final DailyGameCatalogItem game;
  final String currentProfileId;
  final DailyGamesRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DailyGameSession?>(
      stream: repository.watchTodaySession(game.id, currentProfileId),
      builder: (context, sessionSnap) {
        return StreamBuilder<DailyGameStats>(
          stream: repository.watchStats(game.id, currentProfileId),
          builder: (context, statsSnap) {
            final session = sessionSnap.data;
            final stats = statsSnap.data;

            String stateText = 'No iniciado';
            if (session != null && session.status == DailySessionStatus.inProgress) {
              stateText = 'En curso';
            } else if (session != null && session.status == DailySessionStatus.completed) {
              stateText = 'Completado';
            }

            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DailyGameDetailScreen(
                        gameId: DailyGameIdX.fromId(game.id),
                        currentProfileId: currentProfileId,
                        repository: repository,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        child: Text(game.name.characters.first),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              game.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Estado de hoy: $stateText'),
                            Text('Racha actual: ${stats?.currentStreak ?? 0}'),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}