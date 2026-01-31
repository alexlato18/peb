import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:peb/albums/data/photo_repository.dart';
import 'package:peb/data/profile_repository.dart';
import 'package:peb/models/profile.dart';
import '../utils/media_downloader.dart';
import 'package:path/path.dart' as p;

import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';

import '../models/photo_item.dart';

class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
    this.title,
    required this.eventId,
    required this.currentProfile,
    required this.profileRepository,
    required this.photoRepository,
  });

  final List<PhotoItem> items;
  final int initialIndex;
  final String? title;

  final String eventId;
  final Profile currentProfile;
  final ProfileRepository profileRepository;
  final PhotoRepository photoRepository;

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController _pageCtrl;
  int _index = 0;

  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;

  bool _downloading = false;
  bool _savingTags = false;
  late final Map<String, Set<String>> _localTagsById;

  PhotoItem get _current => widget.items[_index];
  bool get _isVideo => _current.mediaType == 'VIDEO';

  // ✅ según lo que pediste: puede etiquetar cualquiera
  bool get _canTag => true;
Set<String> _currentLocalTags() {
  return _localTagsById[_current.id] ?? <String>{};
}

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageCtrl = PageController(initialPage: _index);
    _localTagsById = {
      for (final it in widget.items) it.id: {...it.taggedProfileIds}
    };

    // prepara vídeo si el primero es vídeo
    if (_isVideo) _initVideoFor(_current.downloadURL);
  }

  @override
  void dispose() {
    _disposeVideo();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _disposeVideo() {
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    _chewieCtrl = null;
    _videoCtrl = null;
  }

  Future<void> _initVideoFor(String url) async {
    _disposeVideo();

    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    await ctrl.initialize();
    ctrl.setLooping(false);

    final chewie = ChewieController(
      videoPlayerController: ctrl,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      showControls: true,
    );

    if (!mounted) return;
    setState(() {
      _videoCtrl = ctrl;
      _chewieCtrl = chewie;
    });
  }

  Future<void> _openTagger() async {
    if (!_canTag) return;

    final selected = <String>{..._currentLocalTags()};


    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '¿Quién sale en esta foto/vídeo?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: StreamBuilder<List<Profile>>(
                          stream: widget.profileRepository.watchProfiles(),
                          builder: (context, snap) {
                            final profiles = snap.data ?? [];
                            return ListView.builder(
                              itemCount: profiles.length,
                              itemBuilder: (_, i) {
                                final prof = profiles[i];
                                final checked = selected.contains(prof.id);

                                return CheckboxListTile(
                                  value: checked,
                                  title: Text(prof.name),
                                  subtitle: Text(prof.role),
                                  onChanged: (v) {
                                    setStateSheet(() {
                                      if (v == true) {
                                        selected.add(prof.id);
                                      } else {
                                        selected.remove(prof.id);
                                      }
                                    });
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _savingTags
                            ? null
                            : () async {
                                setState(() => _savingTags = true);
                                try {
                                  await widget.photoRepository.setTags(
                                    eventId: widget.eventId,
                                    photoId: _current.id,
                                    taggedProfileIds: selected.toList(),
                                  );
                                  setState(() {
                                      _localTagsById[_current.id] = {...selected};
                                    });

                                  if (!mounted) return;
                                  Navigator.pop(ctx);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Etiquetas guardadas')),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error guardando tags: $e')),
                                  );
                                } finally {
                                  if (mounted) setState(() => _savingTags = false);
                                }
                              },
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _download() async {
    setState(() => _downloading = true);

    try {
      final url = _current.downloadURL;

      var name = _current.fileName ?? 'peb_${_current.id}';
      if (p.extension(name).isEmpty && _current.contentType != null) {
        if (_current.contentType!.startsWith('image/')) name += '.jpg';
        if (_current.contentType!.startsWith('video/')) name += '.mp4';
      }

      final savedPath = await MediaDownloader.downloadToDevice(
        url: url,
        fileName: name,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Guardado en: $savedPath')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al descargar: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? (_current.fileName ?? 'Archivo');

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            onPressed: _openTagger,
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Etiquetar personas',
          ),
          IconButton(
            onPressed: _downloading ? null : _download,
            icon: _downloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            tooltip: 'Descargar',
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.items.length,
        onPageChanged: (newIndex) async {
          setState(() => _index = newIndex);

          // si el nuevo es vídeo, inicializa; si no, limpia vídeo
          if (_current.mediaType == 'VIDEO') {
            await _initVideoFor(_current.downloadURL);
          } else {
            _disposeVideo();
          }
        },
        itemBuilder: (_, i) {
          final item = widget.items[i];
          if (item.mediaType == 'VIDEO') {
            // Solo el vídeo de la página actual debe usar chewie
            if (i != _index) return const SizedBox.expand(child: ColoredBox(color: Colors.black));
            if (_chewieCtrl == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: Chewie(controller: _chewieCtrl!),
            );
          }

          return PhotoView(
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            imageProvider: CachedNetworkImageProvider(item.downloadURL),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3.0,
            heroAttributes: PhotoViewHeroAttributes(tag: 'media_${item.id}'),
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }
}
