import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:peb/data/secret_tags.dart';
import 'package:peb/services/ghost_services.dart';
import 'package:peb/social/screens/social_video_player_screen.dart';
import 'package:peb/social/utils/video_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../data/profile_repository.dart';
import '../../data/tag_style_repository.dart';
import '../../models/profile.dart';
import '../../widgets/tag_chip.dart';
import '../data/social_repository.dart';
import '../models/social_post.dart';
import 'private_chat_screen.dart';

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({
    super.key,
    required this.currentProfile,
    required this.profileRepository,
  });

  final Profile currentProfile;
  final ProfileRepository profileRepository;

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _textCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  late final SocialRepository _repo;
  late final TagStyleRepository _tagStyleRepo;

  File? _selectedFile;
  String? _selectedMediaType;
  bool _posting = false;

  final Map<String, Profile?> _profileCache = {};

  @override
  void initState() {
    super.initState();
    _repo = SocialRepository(
      firestore: FirebaseFirestore.instance,
      storage: FirebaseStorage.instance,
    );
    _tagStyleRepo = TagStyleRepository(FirebaseFirestore.instance);
  }

  Future<Profile?> _getProfile(String profileId) async {
    if (_profileCache.containsKey(profileId)) {
      return _profileCache[profileId];
    }

    final profile = await widget.profileRepository.getProfileById(profileId);
    _profileCache[profileId] = profile;
    return profile;
  }
  Future<bool?> _askAppleOffensiveQuestion() async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Pregunta importante'),
        content: const Text('¿Lo dices de manera ofensiva?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí'),
          ),
        ],
      );
    },
  );
}

Future<void> _unlockAppleSecretTag() async {
  final profileRef = FirebaseFirestore.instance
      .collection('groups')
      .doc('peb')
      .collection('profiles')
      .doc(widget.currentProfile.id);

  final updates = <String, dynamic>{
    'tags': FieldValue.arrayUnion([appleOffensiveTag]),
  };

  if (widget.currentProfile.visibleTags != null) {
    updates['visibleTags'] = FieldValue.arrayUnion([appleOffensiveTag]);
  }

  await profileRef.update(updates);

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Tag secreto desbloqueado: antisemita ⭐'),
    ),
  );
}
  Future<void> _pickImage() async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;

    setState(() {
      _selectedFile = File(xfile.path);
      _selectedMediaType = 'image';
    });
  }

  Future<void> _pickVideo() async {
    final xfile = await _picker.pickVideo(source: ImageSource.gallery);
    if (xfile == null) return;

    setState(() {
      _selectedFile = File(xfile.path);
      _selectedMediaType = 'video';
    });
  }

  Future<void> _postGifByUrl() async {
    final gifCtrl = TextEditingController();

    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pegar URL del GIF'),
        content: TextField(
          controller: gifCtrl,
          decoration: const InputDecoration(
            hintText: 'https://...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, gifCtrl.text.trim()),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty) return;

    await _repo.createPost(
      authorId: widget.currentProfile.id,
      text: _textCtrl.text.trim(),
      mediaUrl: url,
      mediaType: 'gif',
    );

    _textCtrl.clear();

    setState(() {
      _selectedFile = null;
      _selectedMediaType = null;
    });
  }

  Future<void> _publishPost() async {
  if (_posting) return;

  final text = _textCtrl.text.trim();
  if (text.isEmpty && _selectedFile == null) return;

  final containsManzana = RegExp(
    r'(^|[^a-zA-ZáéíóúÁÉÍÓÚñÑ])judio([^a-zA-ZáéíóúÁÉÍÓÚñÑ]|$)',
    caseSensitive: false,
  ).hasMatch(text);

  if (containsManzana) {
    final offensive = await _askAppleOffensiveQuestion();

    if (offensive == null) return;

    if (offensive == true) {
      await _unlockAppleSecretTag();
    }
  }

  setState(() => _posting = true);

  try {
    if (_selectedFile != null && _selectedMediaType != null) {
      await _repo.createPostWithUploadedMedia(
        authorId: widget.currentProfile.id,
        text: text,
        file: _selectedFile!,
        mediaType: _selectedMediaType!,
      );
    } else {
      await _repo.createPost(
        authorId: widget.currentProfile.id,
        text: text,
        mediaUrl: null,
        mediaType: 'text',
      );
    }
    await GhostService(FirebaseFirestore.instance).resetBecauseUserPosted(
        widget.currentProfile.id,
      );
    _textCtrl.clear();

    setState(() {
      _selectedFile = null;
      _selectedMediaType = null;
    });
  } finally {
    if (mounted) {
      setState(() => _posting = false);
    }
  }
}

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, TagStyle>>(
      stream: _tagStyleRepo.watchStyles(),
      builder: (context, stylesSnap) {
        final styles = stylesSnap.data ?? const <String, TagStyle>{};

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: const Text('Muro PEB'),
            actions: [
              IconButton(
                icon: const Icon(Icons.chat_outlined),
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            ],
          ),
          endDrawer: Drawer(
            child: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.people),
                        SizedBox(width: 8),
                        Text(
                          'Chats privados',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<List<Profile>>(
                      stream: widget.profileRepository.watchProfiles(),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final users = snap.data!
                            .where((p) => p.id != widget.currentProfile.id)
                            .toList();

                        if (users.isEmpty) {
                          return const Center(
                            child: Text('No hay otros usuarios.'),
                          );
                        }

                        return ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (_, i) {
                            final user = users[i];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: user.avatarURL != null
                                    ? NetworkImage(user.avatarURL!)
                                    : null,
                                child: user.avatarURL == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(user.name),
                              subtitle: user.tags.isNotEmpty
                                  ? Text(user.tags.join(' · '))
                                  : null,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PrivateChatScreen(
                                      currentProfile: widget.currentProfile,
                                      otherProfile: user,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundImage: widget.currentProfile.avatarURL != null
                              ? NetworkImage(widget.currentProfile.avatarURL!)
                              : null,
                          child: widget.currentProfile.avatarURL == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _textCtrl,
                            minLines: 2,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              hintText: 'Escribe algo para el muro...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedFile != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedMediaType == 'video'
                                  ? Icons.videocam
                                  : Icons.image,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedFile!.path.split('/').last,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedFile = null;
                                  _selectedMediaType = null;
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image_outlined),
                        ),
                        IconButton(
                          onPressed: _pickVideo,
                          icon: const Icon(Icons.videocam_outlined),
                        ),
                        IconButton(
                          onPressed: _postGifByUrl,
                          icon: const Icon(Icons.gif_box_outlined),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _posting ? null : _publishPost,
                          icon: _posting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                          label: const Text('Publicar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<SocialPost>>(
                  stream: _repo.watchPosts(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final posts = snap.data!;

                    if (posts.isEmpty) {
                      return const Center(
                        child: Text('Todavía no hay publicaciones.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: posts.length,
                      itemBuilder: (_, i) {
                        final post = posts[i];

                        return FutureBuilder<Profile?>(
                          future: _getProfile(post.authorId),
                          builder: (_, profileSnap) {
                            final author = profileSnap.data;

                            return Container(
                              margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.20),
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundImage: author?.avatarURL != null
                                        ? NetworkImage(author!.avatarURL!)
                                        : null,
                                    child: author?.avatarURL == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          author?.name ?? 'Usuario',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Builder(
                                          builder: (_) {
                                            final tagsToShow = author == null
                                                ? <String>[]
                                                : author.visibleTags == null
                                                    ? author.tags
                                                    : author.visibleTags!
                                                        .where((tag) => author.tags.contains(tag))
                                                        .toList();

                                            if (tagsToShow.isEmpty) {
                                              return const SizedBox.shrink();
                                            }

                                            return Padding(
                                              padding: const EdgeInsets.only(top: 6),
                                              child: Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: tagsToShow.map((tag) {
                                                  final clean = tag.trim();
                                                  final style = resolveTagStyle(clean, styles);

                                                  return TagChip(
                                                    label: clean,
                                                    style: style,
                                                  );
                                                }).toList(),
                                              ),
                                            );
                                          },
                                        ),
                                        if (post.text.trim().isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Text(post.text),
                                        ],
                                        if (post.mediaUrl != null &&
                                            post.mediaUrl!.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          _PostMediaView(
                                            mediaUrl: post.mediaUrl!,
                                            mediaType: post.mediaType,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PostMediaView extends StatelessWidget {
  const _PostMediaView({
    required this.mediaUrl,
    required this.mediaType,
  });

  final String mediaUrl;
  final String mediaType;

  @override
  Widget build(BuildContext context) {
    if (mediaType == 'image' || mediaType == 'gif') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          mediaUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) {
            return Container(
              height: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('No se pudo cargar la imagen'),
            );
          },
        ),
      );
    }

    if (mediaType == 'video') {
      return _VideoPreviewCard(mediaUrl: mediaUrl);
    }

    return const SizedBox.shrink();
  }
}
class _VideoPreviewCard extends StatelessWidget {
  const _VideoPreviewCard({
    required this.mediaUrl,
  });

  final String mediaUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        try {
          await VideoLauncher.openExternal(mediaUrl);
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir el vídeo'),
            ),
          );
        }
      },
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_fill,
              color: Colors.white,
              size: 68,
            ),
            SizedBox(height: 10),
            Text(
              'Tocar para abrir vídeo',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
class _PostVideoPlayer extends StatefulWidget {
  const _PostVideoPlayer({required this.url});

  final String url;

  @override
  State<_PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<_PostVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.url));

      await controller.initialize();
      await controller.pause();
      await controller.setLooping(false);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _ready = true;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _ready = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text('No se pudo cargar el vídeo'),
      );
    }

    if (!_ready || _controller == null) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const CircularProgressIndicator(),
      );
    }

    final aspectRatio = _controller!.value.aspectRatio <= 0
        ? 16 / 9
        : _controller!.value.aspectRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: _togglePlayPause,
              icon: Icon(
                _controller!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
            ),
          ],
        ),
      ],
    );
  }
}