import 'package:flutter/material.dart';
import 'package:peb/PEB/screeens/party_game_rooms_list_screen.dart';
import 'package:peb/data/profile_repository.dart';
import 'package:peb/models/profile.dart';
import 'package:peb/poker/screens/poker_rooms_list_screen.dart';

class GamesHubScreen extends StatelessWidget {
  const GamesHubScreen({
    super.key,
    required this.currentProfile,
    required this.profileRepository,
  });

  final Profile currentProfile;
  final ProfileRepository profileRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Juegos Online")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text("Poker Texas Hold'em"),
              subtitle: const Text("Crea o únete a una sala"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PokerRoomsListScreen(
                      currentProfile: currentProfile,
                      profileRepository: profileRepository,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text("PEB"),
              subtitle: const Text("Crea o únete a una sala"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PartyGameRoomsListScreen(
                      currentProfile: currentProfile,
                      profileRepository: profileRepository,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}