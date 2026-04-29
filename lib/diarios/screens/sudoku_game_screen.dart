import 'dart:async';

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
  Timer? _timer;

  int _displayMs = 0;
  int _baseAccumulatedMs = 0;
  DateTime? _timerStartedAt;
  bool _lastCompletedState = false;

  @override
  void initState() {
    super.initState();

    widget.repository.startOrResumeSession(
      gameId: DailyGameId.sudoku.id,
      profileId: widget.currentProfileId,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      if (_timerStartedAt == null || _lastCompletedState) return;

      final extraMs = DateTime.now().difference(_timerStartedAt!).inMilliseconds;

      setState(() {
        _displayMs = _baseAccumulatedMs + extraMs;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();

    widget.repository.pauseSession(
      gameId: DailyGameId.sudoku.id,
      profileId: widget.currentProfileId,
    );

    super.dispose();
  }

  void _syncTimer(DailyGameSession session) {
    final completed = session.isCompleted;

    if (_baseAccumulatedMs != session.accumulatedTimeMs ||
        _lastCompletedState != completed) {
      _baseAccumulatedMs = session.accumulatedTimeMs;
      _displayMs = session.accumulatedTimeMs;
      _lastCompletedState = completed;
      _timerStartedAt = completed ? null : DateTime.now();
    }
  }

  Future<void> _emergencyCheck({
    required String puzzle,
    required String currentBoard,
    required Set<int> conflictIndexes,
  }) async {
    if (currentBoard.length != 81) {
      _showSnack('El tablero no tiene un formato válido.');
      return;
    }

    if (currentBoard.contains('0')) {
      _showSnack('Todavía quedan casillas vacías.');
      return;
    }

    if (conflictIndexes.isNotEmpty) {
      _showSnack('Hay números repetidos en alguna fila, columna o recuadro.');
      return;
    }

    await widget.repository.completeSudokuManually(
      profileId: widget.currentProfileId,
      currentBoard: currentBoard,
    );

    if (!mounted) return;

    _showSnack('Sudoku completado correctamente.');
  }

  void _showSnack(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
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

            _syncTimer(session);

            final puzzle = challenge.payload['puzzle'] as String? ?? '';
            final currentBoard =
                session.sessionData['currentBoard'] as String? ?? puzzle;
            final selectedIndex =
                (session.sessionData['selectedIndex'] as num?)?.toInt() ?? -1;

            final conflictIndexes = _findConflictIndexes(currentBoard);

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
                          'Tiempo: ${_formatDuration(_displayMs)}',
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
                        conflictIndexes: conflictIndexes,
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
                        alignment: WrapAlignment.center,
                        children: [
                          for (int n = 1; n <= 9; n++)
                            SizedBox(
                              width: 52,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: selectedIndex < 0
                                    ? null
                                    : () async {
                                        if (_isFixedCell(
                                          puzzle,
                                          selectedIndex,
                                        )) {
                                          return;
                                        }

                                        final nextBoard = _replaceAt(
                                          currentBoard,
                                          selectedIndex,
                                          '$n',
                                        );

                                        await widget.repository
                                            .saveSudokuProgress(
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
                                      if (_isFixedCell(
                                        puzzle,
                                        selectedIndex,
                                      )) {
                                        return;
                                      }

                                      final nextBoard = _replaceAt(
                                        currentBoard,
                                        selectedIndex,
                                        '0',
                                      );

                                      await widget.repository
                                          .saveSudokuProgress(
                                        profileId: widget.currentProfileId,
                                        currentBoard: nextBoard,
                                        selectedIndex: selectedIndex,
                                      );
                                    },
                              child: const Text('Borrar'),
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: () => _emergencyCheck(
                                puzzle: puzzle,
                                currentBoard: currentBoard,
                                conflictIndexes: conflictIndexes,
                              ),
                              icon: const Icon(Icons.emergency_outlined),
                              label: const Text('Botón emergencia'),
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

  static Set<int> _findConflictIndexes(String board) {
    final conflicts = <int>{};

    if (board.length != 81) return conflicts;

    void checkGroup(List<int> indexes) {
      final positionsByNumber = <String, List<int>>{};

      for (final index in indexes) {
        final value = board[index];

        if (value == '0') continue;

        positionsByNumber.putIfAbsent(value, () => <int>[]).add(index);
      }

      for (final entry in positionsByNumber.entries) {
        if (entry.value.length > 1) {
          conflicts.addAll(entry.value);
        }
      }
    }

    for (int row = 0; row < 9; row++) {
      checkGroup([
        for (int col = 0; col < 9; col++) row * 9 + col,
      ]);
    }

    for (int col = 0; col < 9; col++) {
      checkGroup([
        for (int row = 0; row < 9; row++) row * 9 + col,
      ]);
    }

    for (int boxRow = 0; boxRow < 3; boxRow++) {
      for (int boxCol = 0; boxCol < 3; boxCol++) {
        final indexes = <int>[];

        for (int r = 0; r < 3; r++) {
          for (int c = 0; c < 3; c++) {
            final row = boxRow * 3 + r;
            final col = boxCol * 3 + c;
            indexes.add(row * 9 + col);
          }
        }

        checkGroup(indexes);
      }
    }

    return conflicts;
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
    required this.conflictIndexes,
    required this.onCellTap,
  });

  final String puzzle;
  final String currentBoard;
  final int selectedIndex;
  final Set<int> conflictIndexes;
  final ValueChanged<int>? onCellTap;

  @override
  Widget build(BuildContext context) {
    if (puzzle.length != 81 || currentBoard.length != 81) {
      return const Center(
        child: Text('Tablero inválido.'),
      );
    }

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
        final hasConflict = conflictIndexes.contains(index);

        return InkWell(
          onTap: onCellTap == null ? null : () => onCellTap!(index),
          child: Container(
            decoration: BoxDecoration(
              color: hasConflict
                  ? Colors.red.withOpacity(0.22)
                  : isSelected
                      ? Colors.blue.withOpacity(0.18)
                      : isFixed
                          ? Colors.grey.withOpacity(0.14)
                          : null,
              border: Border(
                top: BorderSide(
                  width: row % 3 == 0 ? 2 : 0.5,
                  color: hasConflict ? Colors.red.shade900 : Colors.black,
                ),
                left: BorderSide(
                  width: col % 3 == 0 ? 2 : 0.5,
                  color: hasConflict ? Colors.red.shade900 : Colors.black,
                ),
                right: BorderSide(
                  width: col == 8 ? 2 : 0.5,
                  color: hasConflict ? Colors.red.shade900 : Colors.black,
                ),
                bottom: BorderSide(
                  width: row == 8 ? 2 : 0.5,
                  color: hasConflict ? Colors.red.shade900 : Colors.black,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              value == '0' ? '' : value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: isFixed ? FontWeight.bold : FontWeight.w500,
                color: hasConflict ? Colors.red.shade900 : null,
              ),
            ),
          ),
        );
      },
    );
  }
}