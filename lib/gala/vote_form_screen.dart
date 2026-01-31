import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:peb/albums/models/event_album.dart';

import '../data/profile_repository.dart';
import '../models/profile.dart';
import 'gala_voting_repository.dart';

class VoteFormScreen extends StatefulWidget {
  const VoteFormScreen({
    super.key,
    required this.repo,
    required this.event,
    required this.currentProfile,
    required this.profileRepository,
  });

  final GalaVotingRepository repo;
  final EventAlbum event;
  final Profile currentProfile;
  final ProfileRepository profileRepository;

  @override
  State<VoteFormScreen> createState() => _VoteFormScreenState();
}

class _VoteFormScreenState extends State<VoteFormScreen> {
  final Map<String, dynamic> _answers = {};

  final _momentCtrl = TextEditingController();
  final _quoteCtrl = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _momentCtrl.dispose();
    _quoteCtrl.dispose();
    super.dispose();
  }

  bool _isComplete() => (_answers['mvp'] as String?) != null;

  Future<void> _submit() async {
    if (!_isComplete()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un MVP antes de enviar.')),
      );
      return;
    }

    final moment = _momentCtrl.text.trim();
    final quote = _quoteCtrl.text.trim();

    if (moment.isNotEmpty) _answers['moment_of_year_candidate'] = moment;
    if (quote.isNotEmpty) _answers['quote_of_year'] = quote;

    setState(() => _submitting = true);

    try {
      await widget.repo.submitVoteOnce(
        eventId: widget.event.id,
        myProfileId: widget.currentProfile.id,
        answers: Map<String, dynamic>.from(_answers),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voto enviado ✅')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy').format(widget.event.date);

    return Scaffold(
      appBar: AppBar(title: const Text('Votación Gala')),
      body: StreamBuilder<bool>(
        stream: widget.repo.watchHasVoted(
          eventId: widget.event.id,
          myProfileId: widget.currentProfile.id,
        ),
        builder: (context, votedSnap) {
          if (!votedSnap.hasData) return const LinearProgressIndicator();
          final hasVoted = votedSnap.data!;

          if (hasVoted) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Ya has votado en "${widget.event.name}" ($dateStr).',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return StreamBuilder<List<Profile>>(
            stream: widget.profileRepository.watchProfiles(),
            builder: (context, psnap) {
              if (psnap.hasError) return Center(child: Text('Error: ${psnap.error}'));
              if (!psnap.hasData) return const LinearProgressIndicator();

              final all = psnap.data!;
              final participants = all
                  .where((p) => widget.event.participantIds.contains(p.id))
                  .toList()
                ..sort((a, b) => a.name.compareTo(b.name));

              final selectedMvpId = _answers['mvp'] as String?;

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: ListTile(
                      title: Text(widget.event.name),
                      subtitle: Text('Evento: $dateStr'),
                      trailing: const Icon(Icons.emoji_events),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ===== MVP (RadioList) =====
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MVP (elige 1 persona) *',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),

                          if (participants.isEmpty)
                            const Text('No hay participantes disponibles para votar.')
                          else
                            Column(
                              children: [
                                for (final p in participants)
                                  RadioListTile<String>(
                                    value: p.id,
                                    groupValue: selectedMvpId,
                                    title: Text(p.name),
                                    subtitle: Text(p.role),
                                    onChanged: (v) {
                                      setState(() {
                                        _answers['mvp'] = v;
                                      });
                                    },
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ===== Momento del año (opcional) =====
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _momentCtrl,
                        maxLength: 140,
                        decoration: const InputDecoration(
                          labelText: 'Candidato a “Momento del año” (opcional)',
                          hintText: 'Escribe una frase corta…',
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ===== Frase del año (opcional) =====
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _quoteCtrl,
                        maxLength: 140,
                        decoration: const InputDecoration(
                          labelText: 'Frase del año (opcional)',
                          hintText: 'Escribe la frase tal cual…',
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(_submitting ? 'Enviando...' : 'Enviar voto'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
