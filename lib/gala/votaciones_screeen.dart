import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:peb/albums/models/event_album.dart';
import 'package:peb/data/profile_repository.dart';

import '../models/profile.dart';
import 'gala_voting_repository.dart';
import 'vote_form_screen.dart';

class VotacionesScreen extends StatelessWidget {
  const VotacionesScreen({
    super.key,
    required this.repo,
    required this.currentProfile,
    required this.profileRepository,
  });

  final GalaVotingRepository repo;
  final Profile currentProfile;
  final ProfileRepository profileRepository;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Votaciones')),
      body: StreamBuilder<List<EventAlbum>>(
        stream: repo.watchMyAvailableGalaVotes(myProfileId: currentProfile.id),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const LinearProgressIndicator();

          final list = snap.data!;
          if (list.isEmpty) {
            return const Center(
              child: Text('No tienes votaciones pendientes.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final e = list[i];
              final dateStr = DateFormat('dd/MM/yyyy').format(e.date);

              return Card(
                child: ListTile(
                  title: Text(e.name),
                  subtitle: Text('Evento: $dateStr'),
                  trailing: const Icon(Icons.how_to_vote),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VoteFormScreen(
                          repo: repo,
                          event: e,
                          currentProfile: currentProfile,
                          profileRepository: profileRepository,
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
