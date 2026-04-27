import 'package:flutter/material.dart';
import 'horse_race_game_screen.dart';

class HorseRaceSetupScreen extends StatefulWidget {
  const HorseRaceSetupScreen({super.key});

  @override
  State<HorseRaceSetupScreen> createState() => _HorseRaceSetupScreenState();
}

class _HorseRaceSetupScreenState extends State<HorseRaceSetupScreen> {
  final _countCtrl = TextEditingController(text: '2');
  final List<TextEditingController> _nameControllers = [];

  int _playerCount = 2;

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncControllers() {
    while (_nameControllers.length < _playerCount) {
      _nameControllers.add(TextEditingController(
        text: 'Jugador ${_nameControllers.length + 1}',
      ));
    }
    while (_nameControllers.length > _playerCount) {
      _nameControllers.removeLast().dispose();
    }
    setState(() {});
  }

  void _updatePlayerCount(String value) {
    final parsed = int.tryParse(value) ?? 2;
    final safe = parsed.clamp(1, 12);
    if (safe != _playerCount) {
      _playerCount = safe;
      _syncControllers();
    }
  }

  void _startGame() {
    final players = _nameControllers
        .map((c) => c.text.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    if (players.length != _playerCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todos los jugadores deben tener nombre')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HorseRaceGameScreen(playerNames: players),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrera de caballos'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(
                  'Configurar partida',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _countCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número de jugadores',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _updatePlayerCount,
                ),
                const SizedBox(height: 16),
                ...List.generate(_playerCount, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _nameControllers[i],
                      decoration: InputDecoration(
                        labelText: 'Nombre jugador ${i + 1}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _startGame,
                    child: const Text('Empezar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}