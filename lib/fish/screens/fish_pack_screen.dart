import 'package:flutter/material.dart';
import '../widgets/fish_sprite.dart';
import '../../data/profile_repository.dart';
import '../models/fish_definitions.dart';
import '../models/fish_models.dart';
import '../repositories/fish_repository.dart';
import 'fish_editor_screen.dart';

class FishPackScreen extends StatefulWidget {
  const FishPackScreen({
    super.key,
    required this.currentProfileId,
    required this.profileRepository,
    required this.fishRepository,
  });

  final String currentProfileId;
  final ProfileRepository profileRepository;
  final FishRepository fishRepository;

  @override
  State<FishPackScreen> createState() => _FishPackScreenState();
}

class _FishPackScreenState extends State<FishPackScreen> {
  late Future<List<FishInstance>> _futureOptions;
  bool _loadingAction = false;

  @override
  void initState() {
    super.initState();
    _futureOptions = widget.fishRepository.generatePackOptions(widget.currentProfileId);
  }
  
  Future<void> _keepFish(FishInstance fish) async {
  final editedFish = await Navigator.push<FishInstance>(
    context,
    MaterialPageRoute(
      builder: (_) => FishEditorScreen(
        fish: fish,
        profileId: widget.currentProfileId,
      ),
    ),
  );

  if (editedFish == null) return;

  setState(() => _loadingAction = true);

  try {
    await widget.fishRepository.claimFish(
      profileId: widget.currentProfileId,
      fish: editedFish,
      addToOwnFishbowl: true,
    );

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pez añadido a tu pecera.')),
    );
  } catch (e) {
    if (!mounted) return;
    setState(() => _loadingAction = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e')),
    );
  }
}

  Future<void> _sendFish(FishInstance fish) async {
  final editedFish = await Navigator.push<FishInstance>(
    context,
    MaterialPageRoute(
      builder: (_) => FishEditorScreen(
        fish: fish,
        profileId: widget.currentProfileId,
      ),
    ),
  );

  if (editedFish == null) return;

  final profiles = await widget.profileRepository.watchProfiles().first;
  final others = profiles.where((p) => p.id != widget.currentProfileId).toList();

  if (!mounted) return;

  final selectedProfileId = await showDialog<String>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: const Text('Enviar a...'),
        children: [
          for (final profile in others)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, profile.id),
              child: Text(profile.name),
            ),
        ],
      );
    },
  );

  if (selectedProfileId == null) return;

  setState(() => _loadingAction = true);

  try {
    await widget.fishRepository.sendFishToProfile(
      fromProfileId: widget.currentProfileId,
      toProfileId: selectedProfileId,
      fish: editedFish,
    );

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pez enviado.')),
    );
  } catch (e) {
    if (!mounted) return;
    setState(() => _loadingAction = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061826),
      appBar: AppBar(
        title: const Text('Sobre diario'),
        backgroundColor: const Color(0xFF061826),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<FishInstance>>(
        future: _futureOptions,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final options = snap.data!;

          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Elige 1 pez. Puedes quedártelo o enviarlo a otra pecera.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: options.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.68,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final fish = options[index];
                    return FishOptionCard(
                      fish: fish,
                      disabled: _loadingAction,
                      onKeep: () => _keepFish(fish),
                      onSend: () => _sendFish(fish),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class FishOptionCard extends StatelessWidget {
  const FishOptionCard({
    super.key,
    required this.fish,
    required this.disabled,
    required this.onKeep,
    required this.onSend,
  });

  final FishInstance fish;
  final bool disabled;
  final VoidCallback onKeep;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final definition = getFishDefinitionById(fish.fishId);

    return Card(
      color: const Color(0xFF102B40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: _rarityColor(definition.rarity),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Expanded(
              child: FishSprite(fish: fish),
            ),
            const SizedBox(height: 8),
            Text(
              definition.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _rarityText(definition.rarity),
              style: TextStyle(
                color: _rarityColor(definition.rarity),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _modsText(fish),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: disabled ? null : onKeep,
                    child: const Text('Pecera'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    onPressed: disabled ? null : onSend,
                    child: const Text('Enviar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _modsText(FishInstance fish) {
    final parts = <String>[];

    if (fish.shiny) parts.add('SHINY');
    parts.addAll(fish.modifiers.map((e) => e.toUpperCase()));

    return parts.isEmpty ? 'Normal' : parts.join(' · ');
  }

  String _rarityText(FishRarity rarity) {
    switch (rarity) {
      case FishRarity.comun:
        return 'COMÚN';
      case FishRarity.pocoComun:
        return 'POCO COMÚN';
      case FishRarity.epico:
        return 'ÉPICO';
      case FishRarity.legendario:
        return 'LEGENDARIO';
    }
  }

  Color _rarityColor(FishRarity rarity) {
    switch (rarity) {
      case FishRarity.comun:
        return Colors.grey;
      case FishRarity.pocoComun:
        return Colors.blueAccent;
      case FishRarity.epico:
        return Colors.purpleAccent;
      case FishRarity.legendario:
        return Colors.orangeAccent;
    }
  }
}

class FishImage extends StatelessWidget {
  const FishImage({
    super.key,
    required this.instance,
  });

  final FishInstance instance;

  @override
  Widget build(BuildContext context) {
    final definition = getFishDefinitionById(instance.fishId);

    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          definition.assetPath,
          fit: BoxFit.contain,
        ),

        if (instance.shiny)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.50),
                  Colors.amber.withOpacity(0.20),
                  Colors.transparent,
                ],
              ),
            ),
          ),

        if (instance.modifiers.contains('fuego'))
          const Positioned(right: 4, top: 4, child: Text('🔥', style: TextStyle(fontSize: 22))),

        if (instance.modifiers.contains('hielo'))
          const Positioned(left: 4, top: 4, child: Text('❄️', style: TextStyle(fontSize: 22))),

        if (instance.modifiers.contains('arcoiris'))
          const Positioned(right: 4, bottom: 4, child: Text('🌈', style: TextStyle(fontSize: 22))),

        if (instance.modifiers.contains('electrico'))
          const Positioned(left: 4, bottom: 4, child: Text('⚡', style: TextStyle(fontSize: 22))),

        if (instance.modifiers.contains('toxico'))
          const Positioned(bottom: 4, child: Text('☣️', style: TextStyle(fontSize: 22))),

        if (instance.modifiers.contains('fantasma'))
          Container(color: Colors.white.withOpacity(0.14)),
      ],
    );
  }
}