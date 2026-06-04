import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../models/fish_models.dart';
import '../widgets/fish_sprite.dart';

class FishEditorScreen extends StatefulWidget {
  const FishEditorScreen({
    super.key,
    required this.fish,
    required this.profileId,
  });

  final FishInstance fish;
  final String profileId;

  @override
  State<FishEditorScreen> createState() => _FishEditorScreenState();
}

class _FishEditorScreenState extends State<FishEditorScreen> {
  final GlobalKey _captureKey = GlobalKey();
  final List<Offset?> _points = [];
  final List<_TextSticker> _texts = [];
  final List<_ImageSticker> _images = [];

  bool _saving = false;
  Color _paintColor = Colors.white;
  double _strokeWidth = 5;

  Future<void> _addText() async {
    final controller = TextEditingController();

    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Añadir texto'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Texto'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );

    if (text == null || text.isEmpty) return;

    setState(() {
      _texts.add(
        _TextSticker(
          text: text,
          position: const Offset(110, 110),
          color: _paintColor,
        ),
      );
    });
  }

  Future<void> _addImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    setState(() {
      _images.add(
        _ImageSticker(
          file: File(picked.path),
          position: const Offset(90, 90),
          size: 120,
        ),
      );
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final boundary =
          _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final path =
          'fish_custom/${widget.profileId}/${widget.fish.id}_${DateTime.now().millisecondsSinceEpoch}.png';

      final ref = FirebaseStorage.instance.ref(path);

      await ref.putData(
        pngBytes,
        SettableMetadata(contentType: 'image/png'),
      );

      final url = await ref.getDownloadURL();

      if (!mounted) return;

      Navigator.pop(
        context,
        widget.fish.copyWith(customImageUrl: url),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando edición: $e')),
      );
    }
  }

  void _clearPaint() {
    setState(() {
      _points.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    const canvasSize = 320.0;

    return Scaffold(
      backgroundColor: const Color(0xFF061826),
      appBar: AppBar(
        title: const Text('Editar pez'),
        backgroundColor: const Color(0xFF061826),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),

          Center(
            child: RepaintBoundary(
              key: _captureKey,
              child: Container(
                width: canvasSize,
                height: canvasSize,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: SizedBox(
                        width: 230,
                        height: 230,
                        child: FishSprite(
                          fish: widget.fish,
                          showEffects: false,
                        ),
                      ),
                    ),

                    

                    CustomPaint(
                      size: const Size(canvasSize, canvasSize),
                      painter: _DrawingPainter(
                        points: _points,
                        color: _paintColor,
                        strokeWidth: _strokeWidth,
                      ),
                    ),

                    GestureDetector(
                      onPanUpdate: (details) {
                        final box = context.findRenderObject() as RenderBox?;
                        if (box == null) return;

                        final local = details.localPosition;

                        setState(() {
                          _points.add(details.localPosition);
                        });
                      },
                      onPanEnd: (_) {
                        setState(() {
                          _points.add(null);
                        });
                      },
                    ),
                    for (final image in _images)
                      Positioned(
                        left: image.position.dx,
                        top: image.position.dy,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              image.position += details.delta;
                            });
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.file(
                                  image.file,
                                  width: image.size,
                                  height: image.size,
                                  fit: BoxFit.cover,
                                ),
                              ),

                              Positioned(
                                right: -10,
                                bottom: -10,
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    setState(() {
                                      image.size += details.delta.dx;
                                      image.size = image.size.clamp(55, 260);
                                    });
                                  },
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.open_in_full,
                                      size: 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    for (final text in _texts)
                      Positioned(
                        left: text.position.dx,
                        top: text.position.dy,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              text.position += details.delta;
                            });
                          },
                          child: Text(
                            text.text,
                            style: TextStyle(
                              color: text.color,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              shadows: const [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 4,
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

          const SizedBox(height: 20),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _addText,
                icon: const Icon(Icons.text_fields),
                label: const Text('Texto'),
              ),
              ElevatedButton.icon(
                onPressed: _addImage,
                icon: const Icon(Icons.image),
                label: const Text('Foto'),
              ),
              ElevatedButton.icon(
                onPressed: _clearPaint,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Borrar pintura'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            children: [
              _ColorDot(
                color: Colors.white,
                selected: _paintColor == Colors.white,
                onTap: () => setState(() => _paintColor = Colors.white),
              ),
              _ColorDot(
                color: Colors.redAccent,
                selected: _paintColor == Colors.redAccent,
                onTap: () => setState(() => _paintColor = Colors.redAccent),
              ),
              _ColorDot(
                color: Colors.yellowAccent,
                selected: _paintColor == Colors.yellowAccent,
                onTap: () => setState(() => _paintColor = Colors.yellowAccent),
              ),
              _ColorDot(
                color: Colors.greenAccent,
                selected: _paintColor == Colors.greenAccent,
                onTap: () => setState(() => _paintColor = Colors.greenAccent),
              ),
              _ColorDot(
                color: Colors.cyanAccent,
                selected: _paintColor == Colors.cyanAccent,
                onTap: () => setState(() => _paintColor = Colors.cyanAccent),
              ),
              _ColorDot(
                color: Colors.purpleAccent,
                selected: _paintColor == Colors.purpleAccent,
                onTap: () => setState(() => _paintColor = Colors.purpleAccent),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                const Text(
                  'Pincel',
                  style: TextStyle(color: Colors.white),
                ),
                Expanded(
                  child: Slider(
                    value: _strokeWidth,
                    min: 2,
                    max: 16,
                    onChanged: (v) {
                      setState(() => _strokeWidth = v);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  const _DrawingPainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  final List<Offset?> points;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];

      if (a != null && b != null) {
        canvas.drawLine(a, b, paint);
      }
    }
  }

  @override
bool shouldRepaint(covariant _DrawingPainter oldDelegate) {
  return true;
}
}

class _TextSticker {
  _TextSticker({
    required this.text,
    required this.position,
    required this.color,
  });

  final String text;
  Offset position;
  final Color color;
}

class _ImageSticker {
  _ImageSticker({
    required this.file,
    required this.position,
    required this.size,
  });

  final File file;
  Offset position;
  double size;
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.black,
            width: selected ? 4 : 2,
          ),
        ),
      ),
    );
  }
}