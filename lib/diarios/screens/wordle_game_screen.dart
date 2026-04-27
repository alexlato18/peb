import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/daily_game_models.dart';
import '../repositories/daily_games_repository.dart';

class WordleGameScreen extends StatefulWidget {
  const WordleGameScreen({
    super.key,
    required this.currentProfileId,
    required this.repository,
  });

  final String currentProfileId;
  final DailyGamesRepository repository;

  @override
  State<WordleGameScreen> createState() => _WordleGameScreenState();
}

class _WordleGameScreenState extends State<WordleGameScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    widget.repository.startOrResumeSession(
      gameId: DailyGameId.wordle.id,
      profileId: widget.currentProfileId,
    );
  }

  @override
  void dispose() {
    widget.repository.pauseSession(
      gameId: DailyGameId.wordle.id,
      profileId: widget.currentProfileId,
    );
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DailyChallenge?>(
      stream: widget.repository.watchTodayChallenge(DailyGameId.wordle.id),
      builder: (context, challengeSnap) {
        return StreamBuilder<DailyGameSession?>(
          stream: widget.repository.watchTodaySession(
            DailyGameId.wordle.id,
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
            final target = (challenge.payload['solution'] as String? ?? '').toUpperCase();
            final wordLength =
                (challenge.payload['wordLength'] as num?)?.toInt() ?? 5;

            final guesses =
                List<String>.from(session.sessionData['guesses'] as List? ?? const []);
            final savedInput = (session.sessionData['currentInput'] as String? ?? '').toUpperCase();

            if (_controller.text != savedInput) {
              _controller.value = TextEditingValue(
                text: savedInput,
                selection: TextSelection.collapsed(offset: savedInput.length),
              );
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text('Wordle'),
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
                        subtitle: Text('Intentos actuales: ${session.attempts}'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: guesses.length + (session.isCompleted ? 0 : 1),
                        itemBuilder: (context, index) {
                          if (index < guesses.length) {
                            final guess = guesses[index];
                            final eval = _evaluateGuess(guess, target);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _WordleRow(
                                letters: guess.split(''),
                                states: eval,
                              ),
                            );
                          }

                          final current = _controller.text.padRight(wordLength, ' ');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _WordleRow(
                              letters: current.split(''),
                              states: List.generate(wordLength, (_) => _CellState.empty),
                            ),
                          );
                        },
                      ),
                    ),
                    if (!session.isCompleted) ...[
                      TextField(
                        controller: _controller,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(wordLength),
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚüÜñÑ]')),
                        ],
                        onChanged: (value) {
                          final upper = value.toUpperCase();
                          if (value != upper) {
                            _controller.value = TextEditingValue(
                              text: upper,
                              selection: TextSelection.collapsed(offset: upper.length),
                            );
                          }
                          widget.repository.saveWordleCurrentInput(
                            profileId: widget.currentProfileId,
                            input: upper,
                          );
                        },
                        decoration: const InputDecoration(
                          labelText: 'Escribe tu intento',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting
                              ? null
                              : () async {
                                  setState(() => _submitting = true);

                                  final result = await widget.repository.submitWordleGuess(
                                    profileId: widget.currentProfileId,
                                    guess: _controller.text,
                                  );

                                  setState(() => _submitting = false);

                                  if (!mounted) return;

                                  if (!result.ok && result.message != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(result.message!)),
                                    );
                                    return;
                                  }

                                  if (result.solved) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('¡Has completado el Wordle de hoy!')),
                                    );
                                  }
                                },
                          child: const Text('Enviar intento'),
                        ),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Ya has completado el Wordle de hoy.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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

  static List<_CellState> _evaluateGuess(String guess, String target) {
    final result = List<_CellState>.filled(guess.length, _CellState.absent);
    final targetChars = target.split('');
    final guessChars = guess.split('');
    final used = List<bool>.filled(targetChars.length, false);

    for (int i = 0; i < guessChars.length; i++) {
      if (guessChars[i] == targetChars[i]) {
        result[i] = _CellState.correct;
        used[i] = true;
      }
    }

    for (int i = 0; i < guessChars.length; i++) {
      if (result[i] == _CellState.correct) continue;

      for (int j = 0; j < targetChars.length; j++) {
        if (!used[j] && guessChars[i] == targetChars[j]) {
          result[i] = _CellState.present;
          used[j] = true;
          break;
        }
      }
    }

    return result;
  }
}

enum _CellState {
  correct,
  present,
  absent,
  empty,
}

class _WordleRow extends StatelessWidget {
  const _WordleRow({
    required this.letters,
    required this.states,
  });

  final List<String> letters;
  final List<_CellState> states;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(letters.length, (index) {
        final state = states[index];

        Color bg;
        switch (state) {
          case _CellState.correct:
            bg = Colors.green;
            break;
          case _CellState.present:
            bg = Colors.orange;
            break;
          case _CellState.absent:
            bg = Colors.grey.shade600;
            break;
          case _CellState.empty:
            bg = Colors.transparent;
            break;
        }

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 56,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: Colors.grey.shade500),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              letters[index],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
        );
      }),
    );
  }
}