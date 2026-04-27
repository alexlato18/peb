import 'package:flutter/material.dart';
import 'package:peb/diarios/screens/loldle_game_screen.dart';
import 'package:peb/diarios/screens/patched_game_screen.dart';
import 'package:peb/diarios/screens/pokedle_game_screen.dart';
import 'package:peb/diarios/screens/queens_game_screen.dart';
import 'package:peb/diarios/screens/tango_game_screen.dart';
import 'package:peb/diarios/screens/zip_game_screen.dart';

import '../models/daily_game_models.dart';
import '../repositories/daily_games_repository.dart';
import 'sudoku_game_screen.dart';
import 'wordle_game_screen.dart';

class DailyGameDetailScreen extends StatefulWidget {
  const DailyGameDetailScreen({
    super.key,
    required this.gameId,
    required this.currentProfileId,
    required this.repository,
  });

  final DailyGameId gameId;
  final String currentProfileId;
  final DailyGamesRepository repository;

  @override
  State<DailyGameDetailScreen> createState() => _DailyGameDetailScreenState();
}

class _DailyGameDetailScreenState extends State<DailyGameDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.repository.ensureTodayChallenges();
  }

  @override
  Widget build(BuildContext context) {
    final gameId = widget.gameId.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gameId.label),
      ),
      body: StreamBuilder<DailyGameSession?>(
        stream: widget.repository.watchTodaySession(gameId, widget.currentProfileId),
        builder: (context, sessionSnap) {
          return StreamBuilder<DailyGameStats>(
            stream: widget.repository.watchStats(gameId, widget.currentProfileId),
            builder: (context, statsSnap) {
              return StreamBuilder<List<DailyGameResult>>(
                stream: widget.repository.watchTodayRanking(gameId),
                builder: (context, rankSnap) {
                  if (!statsSnap.hasData || !rankSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final session = sessionSnap.data;
                  final stats = statsSnap.data!;
                  final ranking = rankSnap.data!;

                  String stateText = 'No iniciado';
                  if (session != null &&
                      session.status == DailySessionStatus.inProgress) {
                    stateText = 'En curso';
                  } else if (session != null &&
                      session.status == DailySessionStatus.completed) {
                    stateText = 'Completado';
                  }

                  final myIndex = ranking.indexWhere(
                    (e) => e.profileId == widget.currentProfileId,
                  );
                  final myPos = myIndex >= 0 ? myIndex + 1 : null;

                  final isTimeGame = widget.gameId == DailyGameId.sudoku ||
                      widget.gameId == DailyGameId.queens ||
                      widget.gameId == DailyGameId.tango ||
                      widget.gameId == DailyGameId.zip ||
                      widget.gameId == DailyGameId.patches;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.gameId.label,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Estado de hoy: $stateText'),
                              Text('Racha actual: ${stats.currentStreak}'),
                              Text('Mejor racha: ${stats.bestStreak}'),
                              if (myPos != null) Text('Tu posición hoy: #$myPos'),
                              const SizedBox(height: 12),
                              if (session == null ||
                                  session.status != DailySessionStatus.completed)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await widget.repository.startOrResumeSession(
                                        gameId: widget.gameId.id,
                                        profileId: widget.currentProfileId,
                                      );

                                      if (!context.mounted) return;

                                      switch (widget.gameId) {
                                        case DailyGameId.wordle:
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => WordleGameScreen(
                                                currentProfileId: widget.currentProfileId,
                                                repository: widget.repository,
                                              ),
                                            ),
                                          );
                                          break;
                                        case DailyGameId.sudoku:
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => SudokuGameScreen(
                                                currentProfileId: widget.currentProfileId,
                                                repository: widget.repository,
                                              ),
                                            ),
                                          );
                                          break;
                                        case DailyGameId.loldle:
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => LoldleGameScreen(
                                                currentProfileId: widget.currentProfileId,
                                                repository: widget.repository,
                                              ),
                                            ),
                                          );
                                          break;
                                        case DailyGameId.pokedle:
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => PokedleGameScreen(
                                                currentProfileId: widget.currentProfileId,
                                                repository: widget.repository,
                                              ),
                                            ),
                                          );
                                          break;
                                        case DailyGameId.queens:
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => QueensGameScreen(
                                                currentProfileId: widget.currentProfileId,
                                                repository: widget.repository,
                                              ),
                                            ),
                                          );
                                          break;
                                        case DailyGameId.tango:
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => TangoGameScreen(
                                                currentProfileId: widget.currentProfileId,
                                                repository: widget.repository,
                                              ),
                                            ),
                                          );
                                          break;
                                        case DailyGameId.zip:
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => ZipGameScreen(
                                                currentProfileId: widget.currentProfileId,
                                                repository: widget.repository,
                                              ),
                                            ),
                                          );
                                          break;
                                        case DailyGameId.patches:
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => PatchedGameScreen(
                                                currentProfileId: widget.currentProfileId,
                                                repository: widget.repository,
                                              ),
                                            ),
                                          );
                                          break;
                                      }
                                    },
                                    child: Text(
                                      session == null
                                          ? 'Jugar'
                                          : session.status ==
                                                  DailySessionStatus.inProgress
                                              ? 'Continuar'
                                              : 'Jugar',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Ranking diario',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: ranking.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Todavía no hay resultados hoy.'),
                              )
                            : Column(
                                children: List.generate(ranking.length, (index) {
                                  final item = ranking[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      child: Text('${index + 1}'),
                                    ),
                                    title: Text(item.displayName),
                                    subtitle: Text(
                                      isTimeGame
                                          ? 'Tiempo: ${_formatDuration(item.timeMs)}'
                                          : 'Intentos: ${item.attempts}',
                                    ),
                                    trailing: isTimeGame
                                        ? null
                                        : Text(_formatDuration(item.timeMs)),
                                  );
                                }),
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static String _formatDuration(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}