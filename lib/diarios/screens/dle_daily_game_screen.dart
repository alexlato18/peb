import 'package:flutter/material.dart';
import 'package:peb/diarios/models/daily_game_models.dart';
import 'package:peb/diarios/repositories/daily_games_repository.dart';
import '../models/dle_models.dart';
import '../models/loldle_entry.dart';
import '../models/pokedle_entry.dart';
import '../repositories/dle_data_repository.dart';

class DleDailyGameScreen<T extends DleEntry> extends StatefulWidget {
  const DleDailyGameScreen({
    super.key,
    required this.gameId,
    required this.title,
    required this.currentProfileId,
    required this.repository,
    required this.searchByPrefix,
    required this.submitGuess,
    required this.numericLabel,
    required this.groupALabel,
    required this.groupBLabel,
    required this.groupCLabel,
  });

  final DailyGameId gameId;
  final String title;
  final String currentProfileId;
  final DailyGamesRepository repository;
  final List<T> Function(String query) searchByPrefix;
  final Future<DleSubmitResult> Function({
  required String profileId,
  required String guessId,
}) submitGuess;
  final String numericLabel;
  final String groupALabel;
  final String groupBLabel;
  final String groupCLabel;

  @override
  State<DleDailyGameScreen<T>> createState() => _DleDailyGameScreenState<T>();
}

class _DleDailyGameScreenState<T extends DleEntry> extends State<DleDailyGameScreen<T>> {
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    widget.repository.startOrResumeSession(
      gameId: widget.gameId.id,
      profileId: widget.currentProfileId,
    );
  }

  @override
  void dispose() {
    widget.repository.pauseSession(
      gameId: widget.gameId.id,
      profileId: widget.currentProfileId,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DailyGameSession?>(
      stream: widget.repository.watchTodaySession(
        widget.gameId.id,
        widget.currentProfileId,
      ),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snap.data!;
        final rowsRaw = List<Map<String, dynamic>>.from(
          session.sessionData['rows'] as List? ?? const [],
        );
        final rows = rowsRaw.map(DleGuessRow.fromMap).toList().reversed.toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
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
                    subtitle: Text('Intentos: ${session.attempts}'),
                  ),
                ),
                const SizedBox(height: 16),
                if (!session.isCompleted)
                  Autocomplete<T>(
                    displayStringForOption: (option) => option.displayName,
                    optionsBuilder: (textEditingValue) {
                      return widget.searchByPrefix(textEditingValue.text);
                    },
                    onSelected: (selected) async {
                      if (_sending) return;
                      setState(() => _sending = true);

                      final result = await widget.submitGuess(
                        profileId: widget.currentProfileId,
                        guessId: selected.id,
                      );

                      if (!mounted) return;
                      setState(() => _sending = false);

                      if (!result.ok && result.message != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result.message!)),
                        );
                        return;
                      }

                      if (result.solved) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('¡Has completado ${widget.title} de hoy!')),
                        );
                      }
                    },
                    fieldViewBuilder: (
                      context,
                      textEditingController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Escribe un nombre',
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      final items = options.toList();
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: SizedBox(
                            width: 320,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return ListTile(
                                  title: Text(item.displayName),
                                  onTap: () => onSelected(item),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  )
                else
                  const Text(
                    'Ya has completado el reto de hoy.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 16),
                Expanded(
                  child: rows.isEmpty
                      ? const Center(child: Text('Todavía no hay intentos.'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: [
                                const DataColumn(label: Text('Nombre')),
                                DataColumn(label: Text(widget.numericLabel)),
                                DataColumn(label: Text(widget.groupALabel)),
                                DataColumn(label: Text(widget.groupBLabel)),
                                DataColumn(label: Text(widget.groupCLabel)),
                              ],
                              rows: rows.map((row) {
                                return DataRow(
                                  cells: [
                                    DataCell(_stateChip(
                                      row.displayName,
                                      row.nameState,
                                    )),
                                    DataCell(_numericChip(
                                      row.numericValue,
                                      row.numericFeedback,
                                    )),
                                    DataCell(_stateChip(
                                      row.groupAValues.join(', '),
                                      row.groupAFeedback.state,
                                    )),
                                    DataCell(_stateChip(
                                      row.groupBValues.join(', '),
                                      row.groupBFeedback.state,
                                    )),
                                    DataCell(_stateChip(
                                      row.groupCValues.join(', '),
                                      row.groupCFeedback.state,
                                    )),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _stateChip(String text, DleCellState state) {
    Color bg;
    switch (state) {
      case DleCellState.correct:
        bg = Colors.green;
        break;
      case DleCellState.partial:
        bg = Colors.orange;
        break;
      case DleCellState.wrong:
        bg = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _numericChip(int value, DleNumericFeedback feedback) {
    Color bg;
    switch (feedback.state) {
      case DleCellState.correct:
        bg = Colors.green;
        break;
      case DleCellState.partial:
        bg = Colors.orange;
        break;
      case DleCellState.wrong:
        bg = Colors.red;
        break;
    }

    IconData? icon;
    switch (feedback.direction) {
      case DleNumericDirection.exact:
        icon = null;
        break;
      case DleNumericDirection.up:
        icon = Icons.arrow_upward;
        break;
      case DleNumericDirection.down:
        icon = Icons.arrow_downward;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: 6),
            Icon(icon, size: 16, color: Colors.white),
          ],
        ],
      ),
    );
  }
}