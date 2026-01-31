import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../albums/models/event_album.dart';
import '../../models/profile.dart';
import '../gala/gala_voting_repository.dart';

enum ResultsSection { mvp, phrases, moments }

class ResultadosScreen extends StatefulWidget {
  const ResultadosScreen({
    super.key,
    required this.repo,
    required this.currentProfile,
  });

  final GalaVotingRepository repo;
  final Profile currentProfile;

  @override
  State<ResultadosScreen> createState() => _ResultadosScreenState();
}

class _ResultadosScreenState extends State<ResultadosScreen> {
  ResultsSection _section = ResultsSection.mvp;

  final _phraseCtrl = TextEditingController();
  final _momentCtrl = TextEditingController();

  bool get _isAdminPlus =>
      widget.currentProfile.role == 'ADMIN' ||
      widget.currentProfile.role == 'ORGANIZADOR' ||
      widget.currentProfile.role == 'DIOS';

  bool get _isOrganizerOrGod =>
      widget.currentProfile.role == 'ORGANIZADOR' ||
      widget.currentProfile.role == 'DIOS';

  @override
  void initState() {
    super.initState();
    // Si no puede ver MVP pero sí Frases/Momentos, arrancamos en Frases
    if (!_isOrganizerOrGod && _isAdminPlus) {
      _section = ResultsSection.phrases;
    }
  }

  @override
  void dispose() {
    _phraseCtrl.dispose();
    _momentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si no es admin+ ni organizer/god -> fuera
    if (!_isAdminPlus && !_isOrganizerOrGod) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resultados')),
        body: const Center(child: Text('No autorizado')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Resultados (Gala)')),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _buildSectionButtons(),
          const SizedBox(height: 10),
          Expanded(child: _buildSectionBody()),
        ],
      ),
    );
  }

  Widget _buildSectionButtons() {
    final canSeeMvp = _isOrganizerOrGod;
    final canSeeTexts = _isAdminPlus;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          if (canSeeMvp)
            _SectionButton(
              selected: _section == ResultsSection.mvp,
              text: 'MVP',
              icon: Icons.emoji_events_outlined,
              onTap: () => setState(() => _section = ResultsSection.mvp),
            ),
          if (canSeeTexts)
            _SectionButton(
              selected: _section == ResultsSection.phrases,
              text: 'Frases',
              icon: Icons.format_quote_outlined,
              onTap: () => setState(() => _section = ResultsSection.phrases),
            ),
          if (canSeeTexts)
            _SectionButton(
              selected: _section == ResultsSection.moments,
              text: 'Momentos',
              icon: Icons.auto_awesome_outlined,
              onTap: () => setState(() => _section = ResultsSection.moments),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionBody() {
    switch (_section) {
      case ResultsSection.mvp:
        if (!_isOrganizerOrGod) return const Center(child: Text('No autorizado'));
        return _MvpSection(
          repo: widget.repo,
        );

      case ResultsSection.phrases:
        if (!_isAdminPlus) return const Center(child: Text('No autorizado'));
        return _TextSection(
          title: 'Frases del año',
          hint: 'Añadir frase manual…',
          controller: _phraseCtrl,
          manualStream: widget.repo.watchManualPhrases(),
          onAddManual: (txt) => widget.repo.addManualPhrase(
            text: txt,
            createdByProfileId: widget.currentProfile.id,
          ),
          extractFromAnswers: (answers) =>
              (answers['quote_of_year'] ?? '').toString().trim(),
          repo: widget.repo,
        );

      case ResultsSection.moments:
        if (!_isAdminPlus) return const Center(child: Text('No autorizado'));
        return _TextSection(
          title: 'Momentos del año',
          hint: 'Añadir momento manual…',
          controller: _momentCtrl,
          manualStream: widget.repo.watchManualMoments(),
          onAddManual: (txt) => widget.repo.addManualMoment(
            text: txt,
            createdByProfileId: widget.currentProfile.id,
          ),
          extractFromAnswers: (answers) =>
              (answers['moment_of_year_candidate'] ?? '').toString().trim(),
          repo: widget.repo,
        );
    }
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.selected,
    required this.text,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(text),
      style: FilledButton.styleFrom(
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
      ),
    );
  }
}

class _MvpSection extends StatelessWidget {
  const _MvpSection({required this.repo});

  final GalaVotingRepository repo;

  Future<Map<String, int>> _buildGlobalMvpRanking(List<EventAlbum> events) async {
    final counts = <String, int>{};

    for (final e in events) {
      final votes = await repo.watchAllVotesForEvent(eventId: e.id).first;

      for (final v in votes) {
        final answers = (v['answers'] as Map?)?.cast<String, dynamic>() ?? const {};
        final mvp = (answers['mvp'] ?? '').toString().trim();
        if (mvp.isEmpty) continue;

        counts[mvp] = (counts[mvp] ?? 0) + 1;
      }
    }

    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventAlbum>>(
      stream: repo.watchAllGalaEventsForResults(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const LinearProgressIndicator();

        final events = snap.data!;
        if (events.isEmpty) return const Center(child: Text('No hay eventos de gala.'));

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // ===== Ranking global =====
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FutureBuilder<Map<String, int>>(
                  future: _buildGlobalMvpRanking(events),
                  builder: (context, rankSnap) {
                    if (rankSnap.hasError) {
                      return Text('Error ranking: ${rankSnap.error}');
                    }
                    if (!rankSnap.hasData) {
                      return const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ranking global MVP',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          SizedBox(height: 10),
                          LinearProgressIndicator(),
                        ],
                      );
                    }

                    final counts = rankSnap.data!;
                    final sorted = counts.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ranking global MVP (todos los eventos)',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        if (sorted.isEmpty)
                          const Text('Aún no hay votos MVP.')
                        else
                          for (int i = 0; i < sorted.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '${i + 1}. ${sorted[i].key}  →  ${sorted[i].value}',
                              ),
                            ),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ===== Lista de eventos (como antes) =====
            const Text(
              'Eventos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),

            ...events.map((e) {
              final dateStr = DateFormat('dd/MM/yyyy').format(e.date);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    title: Text(e.name),
                    subtitle: Text('Evento: $dateStr'),
                    trailing: const Icon(Icons.bar_chart_outlined),
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => _MvpDialog(repo: repo, event: e),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}


class _MvpDialog extends StatelessWidget {
  const _MvpDialog({required this.repo, required this.event});

  final GalaVotingRepository repo;
  final EventAlbum event;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('MVP · ${event.name}'),
      content: SizedBox(
        width: 420,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: repo.watchAllVotesForEvent(eventId: event.id),
          builder: (context, snap) {
            if (snap.hasError) return Text('Error: ${snap.error}');
            if (!snap.hasData) return const LinearProgressIndicator();

            final votes = snap.data!;
            final counts = <String, int>{};

            for (final v in votes) {
              final answers =
                  (v['answers'] as Map?)?.cast<String, dynamic>() ?? const {};
              final mvp = (answers['mvp'] ?? '').toString().trim();
              if (mvp.isEmpty) continue;
              counts[mvp] = (counts[mvp] ?? 0) + 1;
            }

            final sorted = counts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Votos: ${votes.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (sorted.isEmpty)
                    const Text('Sin votos MVP.')
                  else
                    for (final e in sorted)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('• ${e.key}  →  ${e.value}'),
                      ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection({
    required this.title,
    required this.hint,
    required this.controller,
    required this.manualStream,
    required this.onAddManual,
    required this.extractFromAnswers,
    required this.repo,
  });

  final String title;
  final String hint;
  final TextEditingController controller;

  final Stream<List<Map<String, dynamic>>> manualStream;
  final Future<void> Function(String) onAddManual;

  final String Function(Map<String, dynamic> answers) extractFromAnswers;

  final GalaVotingRepository repo;

  Future<List<String>> _loadFromVotes(List<EventAlbum> events) async {
    final list = <String>[];

    for (final e in events) {
      final votes = await repo.watchAllVotesForEvent(eventId: e.id).first;
      for (final v in votes) {
        final answers =
            (v['answers'] as Map?)?.cast<String, dynamic>() ?? const {};
        final txt = extractFromAnswers(answers);
        if (txt.isNotEmpty) list.add(txt);
      }
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventAlbum>>(
      stream: repo.watchAllGalaEventsForResults(),
      builder: (context, evSnap) {
        if (evSnap.hasError) return Center(child: Text('Error: ${evSnap.error}'));
        if (!evSnap.hasData) return const LinearProgressIndicator();

        final events = evSnap.data!;
        if (events.isEmpty) return const Center(child: Text('No hay eventos de gala.'));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),

                      TextField(
                        controller: controller,
                        maxLength: 140,
                        decoration: InputDecoration(
                          labelText: hint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),

                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Añadir'),
                        onPressed: () async {
                          final t = controller.text.trim();
                          if (t.isEmpty) return;

                          await onAddManual(t);
                          controller.clear();

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Añadido ✅')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: FutureBuilder<List<String>>(
                future: _loadFromVotes(events),
                builder: (context, voteSnap) {
                  if (voteSnap.hasError) {
                    return Center(child: Text('Error: ${voteSnap.error}'));
                  }
                  if (!voteSnap.hasData) return const LinearProgressIndicator();

                  final fromVotes = voteSnap.data!;

                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: manualStream,
                    builder: (context, manSnap) {
                      if (manSnap.hasError) return Center(child: Text('Error: ${manSnap.error}'));
                      if (!manSnap.hasData) return const LinearProgressIndicator();

                      final manual = manSnap.data!
                          .map((m) => (m['text'] ?? '').toString().trim())
                          .where((t) => t.isNotEmpty)
                          .toList();

                      final combined = <String>[
                        ...manual.map((e) => '$e'),
                        ...fromVotes.map((e) => '$e'),
                      ];

                      if (combined.isEmpty) {
                        return const Center(child: Text('Aún no hay entradas.'));
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: combined.length,
                        separatorBuilder: (_, __) => const Divider(height: 12),
                        itemBuilder: (context, i) => Text(combined[i]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
