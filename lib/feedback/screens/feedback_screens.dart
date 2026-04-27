import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/profile_repository.dart';
import '../../models/profile.dart';
import '../data/feedback_repository.dart';
import '../models/feedback_entry.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({
    super.key,
    required this.currentProfile,
    required this.profileRepository,
  });

  final Profile currentProfile;
  final ProfileRepository profileRepository;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  late final FeedbackRepository _repo;
  final _textCtrl = TextEditingController();

  String _type = 'bug';
  bool _busy = false;

  bool get _isGod => widget.currentProfile.role == 'DIOS';

  @override
  void initState() {
    super.initState();
    _repo = FeedbackRepository(FirebaseFirestore.instance);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _busy) return;

    setState(() => _busy = true);

    try {
      await _repo.createEntry(
        profileId: widget.currentProfile.id,
        type: _type,
        text: text,
      );

      _textCtrl.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enviado para revisión ✅')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _profileName(String profileId) async {
    final p = await widget.profileRepository.getProfileById(profileId);
    return p?.name ?? profileId;
  }

  Future<void> _review(FeedbackEntry entry, bool valid) async {
    await _repo.reviewEntry(
      entry: entry,
      reviewerProfileId: widget.currentProfile.id,
      valid: valid,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(valid
            ? 'Entrada validada ✅'
            : 'Entrada rechazada'),
      ),
    );
  }

  String _typeLabel(String type) {
    if (type == 'recommendation') return 'Recomendación';
    return 'Bug';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'valid':
        return 'Validado';
      case 'rejected':
        return 'Rechazado';
      default:
        return 'Pendiente';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'valid':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bugs y recomendaciones'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CreateFeedbackCard(
            type: _type,
            textCtrl: _textCtrl,
            busy: _busy,
            onTypeChanged: (v) => setState(() => _type = v),
            onSend: _send,
          ),

          const SizedBox(height: 18),

          Text(
            'Mis envíos',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),

          const SizedBox(height: 8),

          StreamBuilder<List<FeedbackEntry>>(
            stream: _repo.watchMine(widget.currentProfile.id),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final entries = snap.data!;

              if (entries.isEmpty) {
                return const Text('Todavía no has enviado nada.');
              }

              return Column(
                children: entries.map((e) {
                  return Card(
                    child: ListTile(
                      title: Text(_typeLabel(e.type)),
                      subtitle: Text(e.text),
                      trailing: Text(
                        _statusLabel(e.status),
                        style: TextStyle(
                          color: _statusColor(e.status),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          if (_isGod) ...[
            const SizedBox(height: 26),
            Text(
              'Pendientes de validar · GOD',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<FeedbackEntry>>(
              stream: _repo.watchPendingForGod(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final pending = snap.data!;

                if (pending.isEmpty) {
                  return const Text('No hay entradas pendientes.');
                }

                return Column(
                  children: pending.map((entry) {
                    return FutureBuilder<String>(
                      future: _profileName(entry.profileId),
                      builder: (context, nameSnap) {
                        final name = nameSnap.data ?? 'Usuario';

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_typeLabel(entry.type)} · $name',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(entry.text),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _review(entry, false),
                                        icon: const Icon(Icons.close),
                                        label: const Text('Rechazar'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _review(entry, true),
                                        icon: const Icon(Icons.check),
                                        label: const Text('Validar'),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _CreateFeedbackCard extends StatelessWidget {
  const _CreateFeedbackCard({
    required this.type,
    required this.textCtrl,
    required this.busy,
    required this.onTypeChanged,
    required this.onSend,
  });

  final String type;
  final TextEditingController textCtrl;
  final bool busy;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'bug',
                  icon: Icon(Icons.bug_report_outlined),
                  label: Text('Bug'),
                ),
                ButtonSegment(
                  value: 'recommendation',
                  icon: Icon(Icons.lightbulb_outline),
                  label: Text('Recomendación'),
                ),
              ],
              selected: {type},
              onSelectionChanged: busy
                  ? null
                  : (v) {
                      if (v.isNotEmpty) onTypeChanged(v.first);
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Describe el bug o recomendación',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: busy ? null : onSend,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Enviar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}