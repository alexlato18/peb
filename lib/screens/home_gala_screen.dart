import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:peb/gala/votaciones_screeen.dart';
import '../data/profile_repository.dart';
import '../gala/gala_voting_repository.dart';
import '../gala/resultados_screen.dart';
import '../models/profile.dart';

class HomeGalaScreen extends StatelessWidget {
  const HomeGalaScreen({
    super.key,
    required this.currentProfile,
    required this.profileRepository,
  });

  final Profile currentProfile;
  final ProfileRepository profileRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gala'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Gala PEB',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),

                const SizedBox(height: 24),

                OutlinedButton.icon(
                  icon: const Icon(Icons.how_to_vote_outlined),
                  label: const Text('Votaciones'),
                  onPressed: () {
                    final galaRepo = GalaVotingRepository(
                      firestore: FirebaseFirestore.instance,
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VotacionesScreen(
                          repo: galaRepo,
                          currentProfile: currentProfile,
                          profileRepository: profileRepository,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 10),

                OutlinedButton.icon(
                  icon: const Icon(Icons.bar_chart_outlined),
                  label: const Text('Resultados'),
                  onPressed: () {
                    final galaRepo = GalaVotingRepository(
                      firestore: FirebaseFirestore.instance,
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResultadosScreen(
                          repo: galaRepo,
                          currentProfile: currentProfile,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}