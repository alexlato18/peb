import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/profile_repository.dart';
import '../../models/profile.dart';
import '../data/event_repository.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({
    super.key,
    required this.eventRepository,
    required this.profileRepository,
    required this.currentProfile,
  });

  final EventRepository eventRepository;
  final ProfileRepository profileRepository;
  final Profile currentProfile;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _nameCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _countsForGala = false;
  String _visibility = 'PUBLIC';

  final Set<String> _selectedParticipants = {};

  @override
  void initState() {
    super.initState();
    _selectedParticipants.add(widget.currentProfile.id);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pon un nombre al evento')),
      );
      return;
    }

    await widget.eventRepository.createEvent(
      name: name,
      date: _date,
      visibility: _visibility,
      countsForGala: _countsForGala,
      participantIds: _selectedParticipants.toList(),
      createdByProfileId: widget.currentProfile.id,
    );

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy').format(_date);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear evento')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del evento',
                hintText: 'Ej: Quedada Enero',
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: ListTile(
                title: const Text('Fecha'),
                subtitle: Text(dateStr),
                trailing: const Icon(Icons.calendar_month),
                onTap: _pickDate,
              ),
            ),

            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'PUBLIC',
                    groupValue: _visibility,
                    title: const Text('Público'),
                    onChanged: (v) => setState(() => _visibility = v!),
                  ),
                  RadioListTile<String>(
                    value: 'PRIVATE',
                    groupValue: _visibility,
                    title: const Text('Privado'),
                    onChanged: (v) => setState(() => _visibility = v!),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            CheckboxListTile(
              value: _countsForGala,
              onChanged: (v) => setState(() => _countsForGala = v ?? false),
              title: const Text('Cuenta para gala'),
            ),

            const SizedBox(height: 12),
            const Text('Participantes', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),

            StreamBuilder<List<Profile>>(
              stream: widget.profileRepository.watchProfiles(),
              builder: (context, snap) {
                if (snap.hasError) return Text('Error: ${snap.error}');
                if (!snap.hasData) return const LinearProgressIndicator();

                final list = snap.data!;
                return Card(
                  child: Column(
                    children: [
                      for (final p in list)
                        CheckboxListTile(
                          value: _selectedParticipants.contains(p.id),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedParticipants.add(p.id);
                              } else {
                                if (p.id == widget.currentProfile.id) return;
                                _selectedParticipants.remove(p.id);
                              }
                            });
                          },
                          title: Text(p.name),
                          subtitle: Text(p.role),
                        ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 14),
            FilledButton(
              onPressed: _create,
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }
}
