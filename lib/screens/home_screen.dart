import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:peb/constitution/constituion_screen.dart';
import 'package:peb/gala/votaciones_screeen.dart';
import 'package:peb/screens/music_game_setup_screen.dart';
import 'package:peb/screens/par_impar_game_screen.dart';
import '../data/tag_admin_repository.dart';
import 'tags_admin_screen.dart';

import '../data/profile_repository.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import 'settings_screen.dart';

// Álbum module
import '../albums/data/event_repository.dart';
import '../albums/data/photo_repository.dart';
import '../albums/screens/events_screen.dart';

// ✅ Gala / Votaciones module
import '../gala/gala_voting_repository.dart';
import '../gala/resultados_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.authService,
    required this.profileRepository,
  });

  final AuthService authService;
  final ProfileRepository profileRepository;

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          authService: authService,
          profileRepository: profileRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: authService.getSelectedProfileId(),
      builder: (context, snapId) {
        final profileId = snapId.data;
        if (profileId == null) {
          return const Scaffold(body: Center(child: Text('No hay perfil seleccionado.')));
        }

        return FutureBuilder<Profile?>(
          future: profileRepository.getProfileById(profileId),
          builder: (context, snapProfile) {
            if (!snapProfile.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final profile = snapProfile.data;
            if (profile == null) {
              return const Scaffold(body: Center(child: Text('Perfil no encontrado.')));
            }

            return Scaffold(
              appBar: AppBar(
                title: Text('PEB · ${profile.name}'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => _openSettings(context),
                  ),
                ],
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
                          'Menú PEB 1.0',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        
                        const SizedBox(height: 10),

                        OutlinedButton.icon(
                          icon: const Icon(Icons.menu_book_outlined),
                          label: const Text('Constitución'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ConstitutionScreen()),
                            );
                          },
                        ),


                        const SizedBox(height: 10),

                        // ===== Álbumes =====
                        OutlinedButton.icon(
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Álbumes'),
                          onPressed: () {
                            final eventRepo = EventRepository(firestore: FirebaseFirestore.instance);
                            final photoRepo = PhotoRepository(
                              firestore: FirebaseFirestore.instance,
                              storage: FirebaseStorage.instance,
                            );

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventsScreen(
                                  eventRepository: eventRepo,
                                  photoRepository: photoRepo,
                                  profileRepository: profileRepository,
                                  currentProfile: profile,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 10),

                        // ===== Votaciones =====
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
                                  currentProfile: profile,
                                  profileRepository: profileRepository,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 10),

                        // ===== Resultados (solo ORGANIZADOR) =====
                        if (profile.role == 'ORGANIZADOR' || profile.role == 'DIOS' || profile.role == 'ADMIN') ...[
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
                                    currentProfile: profile,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (profile.role == 'ORGANIZADOR' || profile.role == 'DIOS' || profile.role == 'ADMIN') ...[
                          SizedBox(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TagsAdminScreen(
                                      currentRole: profile.role,
                                      repo: TagAdminRepository(FirebaseFirestore.instance),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.sell),
                              label: const Text('Gestionar tags'),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        OutlinedButton.icon(
                          icon: const Icon(Icons.style),
                          label: const Text("Par o impar"),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ParImparGameScreen()),
                            );
                          },
                          
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MusicGameSetupScreen()),
                            );
                          },
                          icon: const Icon(Icons.music_note),
                          label: const Text("Jueguito música"),
                        ),
                        const SizedBox(height: 10),
                        // ===== Settings =====
                        OutlinedButton.icon(
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text('Settings'),
                          onPressed: () => _openSettings(context),
                        ),

                        const SizedBox(height: 25),
                        Text(
                          'Rol: ${profile.role}',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
