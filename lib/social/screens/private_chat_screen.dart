import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:peb/social/screens/social_video_player_screen.dart';
import 'package:peb/social/utils/video_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../models/profile.dart';
import '../data/social_repository.dart';
import '../models/private_message.dart';

class PrivateChatScreen extends StatefulWidget {
  const PrivateChatScreen({
    super.key,
    required this.currentProfile,
    required this.otherProfile,
  });

  final Profile currentProfile;
  final Profile otherProfile;

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  late final SocialRepository _repo;
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedFile;
  String? _selectedMediaType;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _repo = SocialRepository(
      firestore: FirebaseFirestore.instance,
      storage: FirebaseStorage.instance,
    );
  }

  String get _chatId =>
      _repo.buildChatId(widget.currentProfile.id, widget.otherProfile.id);

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

  Future<void> _askGifUrl() async {
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

    setState(() {
      _selectedFile = null;
      _selectedMediaType = null;
    });

    await _repo.sendPrivateMessage(
      myProfileId: widget.currentProfile.id,
      otherProfileId: widget.otherProfile.id,
      text: _textCtrl.text.trim(),
      mediaUrl: url,
      mediaType: 'gif',
    );

    _textCtrl.clear();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();

    if (_sending) return;
    if (text.isEmpty && _selectedFile == null) return;

    setState(() => _sending = true);

    try {
      if (_selectedFile != null && _selectedMediaType != null) {
        await _repo.sendPrivateMessageWithUploadedMedia(
          myProfileId: widget.currentProfile.id,
          otherProfileId: widget.otherProfile.id,
          text: text,
          file: _selectedFile!,
          mediaType: _selectedMediaType!,
        );
      } else {
        await _repo.sendPrivateMessage(
          myProfileId: widget.currentProfile.id,
          otherProfileId: widget.otherProfile.id,
          text: text,
          mediaUrl: null,
          mediaType: 'text',
        );
      }

      _textCtrl.clear();

      setState(() {
        _selectedFile = null;
        _selectedMediaType = null;
      });

      await Future.delayed(const Duration(milliseconds: 120));
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherProfile.name),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<PrivateMessage>>(
              stream: _repo.watchMessages(_chatId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snap.data!;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No hay mensajes todavía.'),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMine =
                        msg.senderId == widget.currentProfile.id;

                    return Align(
                      alignment:
                          isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Colors.blue.withOpacity(0.15)
                              : Colors.grey.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (msg.mediaUrl != null &&
                                msg.mediaUrl!.isNotEmpty)
                              _MessageMediaView(
                                mediaUrl: msg.mediaUrl!,
                                mediaType: msg.mediaType,
                              ),
                            if (msg.mediaUrl != null &&
                                msg.mediaUrl!.isNotEmpty &&
                                msg.text.trim().isNotEmpty)
                              const SizedBox(height: 8),
                            if (msg.text.trim().isNotEmpty)
                              Text(msg.text),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          if (_selectedFile != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.15),
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
                  )
                ],
              ),
            ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.add_circle_outline),
                    onSelected: (value) {
                      if (value == 'image') _pickImage();
                      if (value == 'video') _pickVideo();
                      if (value == 'gif') _askGifUrl();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'image',
                        child: Text('Imagen'),
                      ),
                      PopupMenuItem(
                        value: 'video',
                        child: Text('Vídeo'),
                      ),
                      PopupMenuItem(
                        value: 'gif',
                        child: Text('GIF por URL'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageMediaView extends StatelessWidget {
  const _MessageMediaView({
    required this.mediaUrl,
    required this.mediaType,
  });

  final String mediaUrl;
  final String mediaType;

  @override
  Widget build(BuildContext context) {
    if (mediaType == 'image' || mediaType == 'gif') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          mediaUrl,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

   if (mediaType == 'video') {
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
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.play_circle_fill,
            color: Colors.white,
            size: 58,
          ),
          SizedBox(height: 8),
          Text(
            'Tocar para abrir vídeo',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    ),
  );
}

    return const SizedBox.shrink();
  }
}
class _InlineVideoPlayer extends StatefulWidget {
  const _InlineVideoPlayer({required this.url});

  final String url;

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
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
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize();
      await c.pause();
      await c.setLooping(false);

      if (!mounted) {
        await c.dispose();
        return;
      }

      setState(() {
        _controller = c;
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

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No se pudo cargar el vídeo'),
      );
    }

    if (!_ready || _controller == null) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const CircularProgressIndicator(),
      );
    }

    final aspectRatio = _controller!.value.aspectRatio <= 0
        ? 16 / 9
        : _controller!.value.aspectRatio;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed: () {
                if (_controller!.value.isPlaying) {
                  _controller!.pause();
                } else {
                  _controller!.play();
                }
                setState(() {});
              },
              icon: Icon(
                _controller!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
            ),
          ],
        )
      ],
    );
  }
}

