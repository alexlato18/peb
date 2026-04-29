import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:peb/constitution/constituion_screen.dart';
import 'package:peb/data/secret_tags.dart';
import 'package:peb/feedback/screens/feedback_screens.dart';
import 'package:peb/services/ghost_services.dart';
import 'package:peb/services/secret_tag_service.dart';
import 'package:peb/social/data/social_repository.dart';
import 'package:peb/social/screens/social_feed_screen.dart';
import 'package:peb/widgets/konami_detector.dart';
import '../data/tag_admin_repository.dart' hide TagsAdminScreen;
import '../data/profile_repository.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import 'settings_screen.dart';
import 'tags_admin_screen.dart';
import 'home_games_screen.dart';
import 'home_gala_screen.dart';

import '../albums/data/event_repository.dart';
import '../albums/data/photo_repository.dart';
import '../albums/screens/events_screen.dart';

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

  Future<void> _unlockNerdTag(BuildContext context, Profile profile) async {
    await SecretTagService(FirebaseFirestore.instance).unlockSecretTag(
      profile: profile,
      tag: nerdSecretTag,
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código Konami aceptado. Tag secreto desbloqueado: NERD 💚'),
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
          return const Scaffold(
            body: Center(child: Text('No hay perfil seleccionado.')),
          );
        }

        return FutureBuilder<Profile?>(
          future: profileRepository.getProfileById(profileId),
          builder: (context, snapProfile) {
            if (!snapProfile.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = snapProfile.data;

            if (profile == null) {
              return const Scaffold(
                body: Center(child: Text('Perfil no encontrado.')),
              );
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              GhostService(FirebaseFirestore.instance).registerSilentVisit(profile);
            });

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
                        KonamiDetector(
                          onCompleted: () => _unlockNerdTag(context, profile),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'Menú PEB 2.0',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        OutlinedButton.icon(
                          icon: const Icon(Icons.menu_book_outlined),
                          label: const Text('Constitución'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ConstitutionScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 10),

                        OutlinedButton.icon(
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Álbumes'),
                          onPressed: () {
                            final eventRepo = EventRepository(
                              firestore: FirebaseFirestore.instance,
                            );
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

                        OutlinedButton.icon(
                          icon: const Icon(Icons.emoji_events_outlined),
                          label: const Text('Gala'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HomeGalaScreen(
                                  currentProfile: profile,
                                  profileRepository: profileRepository,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 10),

                        if (profile.role == 'ORGANIZADOR' ||
                            profile.role == 'DIOS' ||
                            profile.role == 'ADMIN') ...[
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TagsAdminScreen(
                                    currentRole: profile.role,
                                    repo: TagAdminRepository(
                                      FirebaseFirestore.instance,
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.sell),
                            label: const Text('Gestionar tags'),
                          ),
                          const SizedBox(height: 10),
                        ],

                        StreamBuilder<int>(
                          stream: SocialRepository(
                            firestore: FirebaseFirestore.instance,
                            storage: FirebaseStorage.instance,
                          ).watchTotalUnreadCount(profile.id),
                          builder: (context, unreadSnap) {
                            final unread = unreadSnap.data ?? 0;

                            return OutlinedButton.icon(
                              icon: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(Icons.public),
                                  if (unread > 0)
                                    Positioned(
                                      right: -7,
                                      top: -7,
                                      child: Container(
                                        width: 17,
                                        height: 17,
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          unread > 9 ? '9+' : '$unread',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              label: const Text("Muro social"),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SocialFeedScreen(
                                      currentProfile: profile,
                                      profileRepository: profileRepository,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 10),

                        OutlinedButton.icon(
                          icon: const Icon(Icons.sports_esports_outlined),
                          label: const Text("Juegos"),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HomeGamesScreen(
                                  currentProfile: profile,
                                  profileRepository: profileRepository,
                                ),
                              ),
                            );
                          },
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