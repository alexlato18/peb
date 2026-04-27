import 'package:flutter/material.dart';
import 'music_game_setup_screen.dart';
import 'par_impar_game_screen.dart';
import 'horse_race_setup_screen.dart';

class OfflineGamesScreen extends StatelessWidget {
  const OfflineGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Juegos offline'),
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
                  'Juegos offline',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),

                OutlinedButton.icon(
                  icon: const Icon(Icons.style),
                  label: const Text("Par o impar"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ParImparGameScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 10),

                OutlinedButton.icon(
                  icon: const Icon(Icons.music_note),
                  label: const Text("Jueguito música"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MusicGameSetupScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                OutlinedButton.icon(
                  icon: const Icon(Icons.emoji_flags_outlined),
                  label: const Text("Carrera de caballos"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HorseRaceSetupScreen(),
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