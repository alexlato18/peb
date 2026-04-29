import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:peb/diarios/repositories/daily_games_repository.dart';
import 'package:peb/diarios/screens/daily_games_list_screen.dart';
import 'package:peb/poker/screens/game_hub_screen.dart';
import '../data/profile_repository.dart';
import '../models/profile.dart';
import 'offline_games_screen.dart';

class HomeGamesScreen extends StatelessWidget {
  const HomeGamesScreen({
    super.key,
    required this.currentProfile,
    required this.profileRepository,
  });

  final Profile currentProfile;
  final ProfileRepository profileRepository;

  void _openDailyGames(BuildContext context) {
    final repo = DailyGamesRepository(
      FirebaseFirestore.instance,
      FirebaseFunctions.instanceFor(region: 'europe-west1'),
      profileRepository,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyGamesListScreen(
          currentProfileId: currentProfile.id,
          profileRepository: profileRepository,
          repository: repo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Juegos'),
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
                  'Zona de juegos',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),

                const SizedBox(height: 24),

                OutlinedButton.icon(
                  icon: const Icon(Icons.sports_esports_outlined),
                  label: const Text('Juegos diarios'),
                  onPressed: () => _openDailyGames(context),
                ),

                const SizedBox(height: 10),

                OutlinedButton.icon(
                  icon: const Icon(Icons.videogame_asset_outlined),
                  label: const Text('Juegos offline'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OfflineGamesScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 10),

                OutlinedButton.icon(
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('Juegos online'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GamesHubScreen(
                          currentProfile: currentProfile,
                          profileRepository: profileRepository,
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