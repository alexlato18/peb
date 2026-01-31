import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/profile_repository.dart';
import '../../models/profile.dart';
import '../data/event_repository.dart';
import '../data/photo_repository.dart';
import '../models/event_album.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({
    super.key,
    required this.eventRepository,
    required this.photoRepository,
    required this.profileRepository,
    required this.currentProfile,
  });

  final EventRepository eventRepository;
  final PhotoRepository photoRepository;
  final ProfileRepository profileRepository;
  final Profile currentProfile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Álbumes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => CreateEventScreen(
                eventRepository: eventRepository,
                profileRepository: profileRepository,
                currentProfile: currentProfile,
              ),
            ),
          );

          if (created == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Evento creado')),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<EventAlbum>>(
        stream: eventRepository.watchVisibleEvents(
          myProfileId: currentProfile.id,
          myRole: currentProfile.role,
          limitPublic: 60,
          limitMine: 60,
        ),

        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final events = snap.data!;
          if (events.isEmpty) return const Center(child: Text('Aún no hay eventos.'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final e = events[i];
              final dateStr = DateFormat('dd/MM/yyyy').format(e.date);
              final isPrivate = e.visibility == 'PRIVATE';

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    child: Icon(isPrivate ? Icons.lock : Icons.public),
                  ),
                  title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('$dateStr · ${isPrivate ? "Privado" : "Público"}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventDetailScreen(
                          event: e,
                          eventRepository: eventRepository,
                          photoRepository: photoRepository,
                          profileRepository: profileRepository,
                          currentProfile: currentProfile,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
