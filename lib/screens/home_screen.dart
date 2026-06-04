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
import 'package:peb/fish/repositories/fish_repository.dart';
import 'package:peb/fish/widgets/fishbowl_background.dart';
import '../albums/data/event_repository.dart';
import '../albums/data/photo_repository.dart';
import '../albums/screens/events_screen.dart';

class HomeScreen extends StatefulWidget  {
  const HomeScreen({
    super.key,
    required this.authService,
    required this.profileRepository,
  });

  final AuthService authService;
  final ProfileRepository profileRepository;
    @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _menuVisible = true;
  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          authService: widget.authService,
          profileRepository: widget.profileRepository,
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
  Widget _homeButton({
  required IconData icon,
  required String text,
  required VoidCallback onPressed,
}) {
  const gold = Color(0xFFD4AF37);

  return Center(
    child: SizedBox(
      width: 260,
      height: 42,
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 18),
        label: Text(text),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.black.withOpacity(0.82),
          foregroundColor: gold,
          side: const BorderSide(color: gold, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: widget.authService.getSelectedProfileId(),
      builder: (context, snapId) {
        final profileId = snapId.data;

        if (profileId == null) {
          return const Scaffold(
            body: Center(child: Text('No hay perfil seleccionado.')),
          );
        }

        return FutureBuilder<Profile?>(
          future: widget.profileRepository.getProfileById(profileId),
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
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                title: Text('PEB · ${profile.name}'),
                backgroundColor: Colors.black.withOpacity(0.18),
                foregroundColor: Colors.white,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: Icon(
                      _menuVisible ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _menuVisible = !_menuVisible;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => _openSettings(context),
                  ),
                ],
              ),
              body: Stack(
                children: [
                 FishbowlBackground(
                  profileId: profile.id,
                  repository: FishRepository(FirebaseFirestore.instance),
                  profileRepository: widget.profileRepository,
                ),
IgnorePointer(
  ignoring: !_menuVisible,
  child: AnimatedOpacity(
    duration: const Duration(milliseconds: 250),
    opacity: _menuVisible ? 1 : 0,
    child: Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                  Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            KonamiDetector(
                              onCompleted: () => _unlockNerdTag(context, profile),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                child: Text(
                                  'Menú PEB 2.0',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        shadows: const [
                                          Shadow(
                                            blurRadius: 8,
                                            color: Colors.black,
                                          ),
                                        ],
                                      ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            _homeButton(
                              icon: Icons.menu_book_outlined,
                              text:'Constitución',
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

                            _homeButton(
                              icon: Icons.photo_library_outlined,
                             text:'Álbumes',
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
                                      profileRepository: widget.profileRepository,
                                      currentProfile: profile,
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 10),

                            _homeButton(
                              icon: Icons.emoji_events_outlined,
                              text: 'Gala',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => HomeGalaScreen(
                                      currentProfile: profile,
                                      profileRepository: widget.profileRepository,
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 10),

                            if (profile.role == 'ORGANIZADOR' ||
                                profile.role == 'DIOS' ||
                                profile.role == 'ADMIN') ...[
                              _homeButton(
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
                                icon: Icons.sell,
                                text:'Gestionar tags',
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

                                return Center(
                                  child: SizedBox(
                                    width: 260,
                                    height: 42,
                                    child: OutlinedButton.icon(
                                      icon: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          const Icon(Icons.public, size: 18),
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
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.black.withOpacity(0.82),
                                        foregroundColor: const Color(0xFFD4AF37),
                                        side: const BorderSide(
                                          color: Color(0xFFD4AF37),
                                          width: 1.4,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SocialFeedScreen(
                                              currentProfile: profile,
                                              profileRepository: widget.profileRepository,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 10),

                            _homeButton(
                              icon: Icons.sports_esports_outlined,
                             text:"Juegos",
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => HomeGamesScreen(
                                      currentProfile: profile,
                                      profileRepository: widget.profileRepository,
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 25),

                            Text(
                              'Rol: ${profile.role}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    blurRadius: 6,
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                              ],
          ),
        ),
      ),
    ),
  ),
),
                ],
              ),
            );
            
          },
        );
      },
    );
  }
}