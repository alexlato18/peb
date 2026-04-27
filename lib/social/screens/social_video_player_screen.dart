import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SocialVideoPlayerScreen extends StatefulWidget {
  const SocialVideoPlayerScreen({
    super.key,
    required this.videoUrl,
  });

  final String videoUrl;

  @override
  State<SocialVideoPlayerScreen> createState() =>
      _SocialVideoPlayerScreenState();
}

class _SocialVideoPlayerScreenState extends State<SocialVideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await controller.initialize();
      await controller.setLooping(false);
      await controller.pause();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _loading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null) return;

    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Vídeo'),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _hasError || _controller == null
                ? const Text(
                    'No se pudo cargar el vídeo',
                    style: TextStyle(color: Colors.white),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio <= 0
                            ? 16 / 9
                            : _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                      const SizedBox(height: 16),
                      IconButton(
                        onPressed: _togglePlayPause,
                        iconSize: 42,
                        color: Colors.white,
                        icon: Icon(
                          _controller!.value.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}