import 'dart:math';

import 'package:flutter/material.dart';
import '../../data/profile_repository.dart';
import '../models/fish_definitions.dart';
import '../models/fish_models.dart';
import '../repositories/fish_repository.dart';
import 'fish_sprite.dart';

class FishbowlBackground extends StatelessWidget {
  const FishbowlBackground({
  super.key,
  required this.profileId,
  required this.repository,
  required this.profileRepository,
  required this.effectsEnabled,
});
final bool effectsEnabled;
final String profileId;
final FishRepository repository;
final ProfileRepository profileRepository;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FishInstance>>(
      stream: repository.watchFishbowl(profileId),
      builder: (context, snap) {
        final fishes = snap.data ?? const <FishInstance>[];

        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                const _WaterBackground(),
                const _BubbleLayer(),
                for (final fish in fishes.take(1200))
                  SwimmingFish(
                    key: ValueKey(fish.id),
                    fish: fish,
                    areaWidth: constraints.maxWidth,
                    areaHeight: constraints.maxHeight,
                    profileRepository: profileRepository,
                    effectsEnabled: effectsEnabled,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _WaterBackground extends StatelessWidget {
  const _WaterBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF06344F),
            Color(0xFF031420),
          ],
        ),
      ),
    );
  }
}

class _BubbleLayer extends StatefulWidget {
  const _BubbleLayer();

  @override
  State<_BubbleLayer> createState() => _BubbleLayerState();
}

class _BubbleLayerState extends State<_BubbleLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final Random _random = Random();
  late final List<_Bubble> _bubbles;

  @override
  void initState() {
    super.initState();

    _bubbles = List.generate(26, (_) {
      return _Bubble(
        x: _random.nextDouble(),
        size: 4 + _random.nextDouble() * 12,
        speed: 0.25 + _random.nextDouble() * 0.75,
        offset: _random.nextDouble(),
      );
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _BubblePainter(
              progress: _controller.value,
              bubbles: _bubbles,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Bubble {
  final double x;
  final double size;
  final double speed;
  final double offset;

  const _Bubble({
    required this.x,
    required this.size,
    required this.speed,
    required this.offset,
  });
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter({
    required this.progress,
    required this.bubbles,
  });

  final double progress;
  final List<_Bubble> bubbles;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (final bubble in bubbles) {
      final yProgress = ((progress * bubble.speed) + bubble.offset) % 1;
      final wave = sin((progress * 2 * pi) + bubble.offset * 10) * 12;

      final x = bubble.x * size.width + wave;
      final y = size.height - (yProgress * size.height);

      canvas.drawCircle(
        Offset(x, y),
        bubble.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class SwimmingFish extends StatefulWidget {
  const SwimmingFish({
    super.key,
    required this.fish,
    required this.areaWidth,
    required this.areaHeight,
    required this.profileRepository,
    required this.effectsEnabled,
  });
final ProfileRepository profileRepository;
  final FishInstance fish;
  final double areaWidth;
  final double areaHeight;
  final bool effectsEnabled;
  @override
  State<SwimmingFish> createState() => _SwimmingFishState();
}

class _SwimmingFishState extends State<SwimmingFish> {
  final Random _random = Random();

  late double _left;
  late double _top;
  late double _size;
  bool _flip = false;
  Duration _duration = const Duration(seconds: 5);

  @override
  void initState() {
    super.initState();

    _size = 54 + _random.nextDouble() * 80;
    _left = _random.nextDouble() * max(1, widget.areaWidth - _size);
    _top = 90 + _random.nextDouble() * max(1, widget.areaHeight - 190);

    WidgetsBinding.instance.addPostFrameCallback((_) => _move());
  }

  @override
  void didUpdateWidget(covariant SwimmingFish oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.areaWidth != widget.areaWidth ||
        oldWidget.areaHeight != widget.areaHeight) {
      _left = _left.clamp(0, max(1, widget.areaWidth - _size));
      _top = _top.clamp(80, max(90, widget.areaHeight - _size));
    }
  }

  void _move() {
    if (!mounted) return;

    final nextLeft = _random.nextDouble() * max(1, widget.areaWidth - _size);
    final nextTop = 90 + _random.nextDouble() * max(1, widget.areaHeight - 190);

    setState(() {
      _flip = nextLeft < _left;
      _left = nextLeft;
      _top = nextTop;
      _duration = Duration(
        milliseconds: 3500 + _random.nextInt(4500),
      );
    });

    Future.delayed(_duration, _move);
  }

  void _showFishPopup(BuildContext context) {
  final definition = getFishDefinitionById(widget.fish.fishId);
  final senderId = widget.fish.senderProfileId;

  showDialog(
    context: context,
    builder: (_) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF071B2C).withOpacity(0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 230,
                child: FishSprite(
                  fish: widget.fish,
                  showEffects: widget.effectsEnabled,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                definition.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _fishInfoText(widget.fish),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),

              if (senderId != null && senderId.isNotEmpty) ...[
                const SizedBox(height: 10),
                FutureBuilder(
                  future: widget.profileRepository.getProfileById(senderId),
                  builder: (context, snap) {
                    final senderName = snap.data?.name ?? senderId;

                    return Text(
                      'Enviado por: $senderName',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ] else ...[
                const SizedBox(height: 10),
                const Text(
                  'Añadido por ti',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],

              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.35),
                  ),
                ),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  String _fishInfoText(FishInstance fish) {
    final parts = <String>[];

    if (fish.shiny) {
      parts.add('Shiny');
    }

    parts.addAll(
      fish.modifiers.map((e) {
        switch (e) {
          case 'fuego':
            return 'Fuego';
          case 'hielo':
            return 'Hielo';
          case 'arcoiris':
            return 'Arcoiris';
          case 'electrico':
            return 'Eléctrico';
          case 'toxico':
            return 'Tóxico';
          case 'fantasma':
            return 'Fantasma';
          default:
            return e;
        }
      }),
    );

    return parts.isEmpty ? 'Normal' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: _duration,
      curve: Curves.easeInOutSine,
      left: _left,
      top: _top,
      width: _size,
      height: _size,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _showFishPopup(context),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          opacity: 0.90,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(_flip ? -1.0 : 1.0, 1.0),
            child: FishSprite(
              fish: widget.fish,
              showEffects: widget.effectsEnabled,
            ),
          ),
        ),
      ),
    );
  }
}