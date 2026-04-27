import 'package:flutter/material.dart';

import '../models/daily_game_models.dart';
import '../repositories/daily_games_repository.dart';

class SudokuGameScreen extends StatefulWidget {
  const SudokuGameScreen({
    super.key,
    required this.currentProfileId,
    required this.repository,
  });

  final String currentProfileId;
  final DailyGamesRepository repository;

  @override
  State<SudokuGameScreen> createState() => _SudokuGameScreenState();
}

class _SudokuGameScreenState extends State<SudokuGameScreen> {
  @override
  void initState() {
    super.initState();
    widget.repository.startOrResumeSession(
      gameId: DailyGameId.sudoku.id,
      profileId: widget.currentProfileId,
    );
  }

  @override
  void dispose() {
    widget.repository.pauseSession(
      gameId: DailyGameId.sudoku.id,
      profileId: widget.currentProfileId,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DailyChallenge?>(
      stream: widget.repository.watchTodayChallenge(DailyGameId.sudoku.id),
      builder: (context, challengeSnap) {
        return StreamBuilder<DailyGameSession?>(
          stream: widget.repository.watchTodaySession(
            DailyGameId.sudoku.id,
            widget.currentProfileId,
          ),
          builder: (context, sessionSnap) {
            if (!challengeSnap.hasData || !sessionSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final challenge = challengeSnap.data!;
            final session = sessionSnap.data!;

            final puzzle = challenge.payload['puzzle'] as String? ?? '';
            final currentBoard =
                session.sessionData['currentBoard'] as String? ?? puzzle;
            final selectedIndex =
                (session.sessionData['selectedIndex'] as num?)?.toInt() ?? -1;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Sudoku'),
              ),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Card(
                      child: ListTile(
                        title: Text(
                          session.isCompleted
                              ? 'Completado'
                              : session.isInProgress
                                  ? 'En curso'
                                  : 'No iniciado',
                        ),
                        subtitle: Text(
                          'Tiempo: ${_formatDuration(session.accumulatedTimeMs)}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AspectRatio(
                      aspectRatio: 1,
                      child: _SudokuBoard(
                        puzzle: puzzle,
                        currentBoard: currentBoard,
                        selectedIndex: selectedIndex,
                        onCellTap: session.isCompleted
                            ? null
                            : (index) {
                                widget.repository.saveSudokuProgress(
                                  profileId: widget.currentProfileId,
                                  currentBoard: currentBoard,
                                  selectedIndex: index,
                                );
                              },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!session.isCompleted)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (int n = 1; n <= 9; n++)
                            SizedBox(
                              width: 52,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: selectedIndex < 0
                                    ? null
                                    : () async {
                                        if (_isFixedCell(puzzle, selectedIndex)) return;
                                        final nextBoard =
                                            _replaceAt(currentBoard, selectedIndex, '$n');
                                        await widget.repository.saveSudokuProgress(
                                          profileId: widget.currentProfileId,
                                          currentBoard: nextBoard,
                                          selectedIndex: selectedIndex,
                                        );
                                      },
                                child: Text('$n'),
                              ),
                            ),
                          SizedBox(
                            width: 110,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: selectedIndex < 0
                                  ? null
                                  : () async {
                                      if (_isFixedCell(puzzle, selectedIndex)) return;
                                      final nextBoard =
                                          _replaceAt(currentBoard, selectedIndex, '0');
                                      await widget.repository.saveSudokuProgress(
                                        profileId: widget.currentProfileId,
                                        currentBoard: nextBoard,
                                        selectedIndex: selectedIndex,
                                      );
                                    },
                              child: const Text('Borrar'),
                            ),
                          ),
                        ],
                      )
                    else
                      const Text(
                        'Ya has completado el Sudoku de hoy.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static bool _isFixedCell(String puzzle, int index) {
    if (index < 0 || index >= puzzle.length) return true;
    return puzzle[index] != '0';
  }

  static String _replaceAt(String source, int index, String value) {
    if (index < 0 || index >= source.length) return source;
    final chars = source.split('');
    chars[index] = value;
    return chars.join();
  }

  static String _formatDuration(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _SudokuBoard extends StatelessWidget {
  const _SudokuBoard({
    required this.puzzle,
    required this.currentBoard,
    required this.selectedIndex,
    required this.onCellTap,
  });

  final String puzzle;
  final String currentBoard;
  final int selectedIndex;
  final ValueChanged<int>? onCellTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 81,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 9,
      ),
      itemBuilder: (context, index) {
        final row = index ~/ 9;
        final col = index % 9;
        final value = currentBoard[index];
        final isFixed = puzzle[index] != '0';
        final isSelected = selectedIndex == index;

        return InkWell(
          onTap: onCellTap == null ? null : () => onCellTap!(index),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withOpacity(0.18)
                  : isFixed
                      ? Colors.grey.withOpacity(0.14)
                      : null,
              border: Border(
                top: BorderSide(
                  width: row % 3 == 0 ? 2 : 0.5,
                  color: Colors.black,
                ),
                left: BorderSide(
                  width: col % 3 == 0 ? 2 : 0.5,
                  color: Colors.black,
                ),
                right: BorderSide(
                  width: col == 8 ? 2 : 0.5,
                  color: Colors.black,
                ),
                bottom: BorderSide(
                  width: row == 8 ? 2 : 0.5,
                  color: Colors.black,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              value == '0' ? '' : value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: isFixed ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }
}