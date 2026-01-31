import 'package:flutter/material.dart';
import 'music_game_screen.dart';

class MusicGameSetupScreen extends StatefulWidget {
  const MusicGameSetupScreen({super.key});

  @override
  State<MusicGameSetupScreen> createState() => _MusicGameSetupScreenState();
}

class _MusicGameSetupScreenState extends State<MusicGameSetupScreen> {
  static const String defaultPlaylistUrl =
      "https://open.spotify.com/playlist/3SH0S8HjheLJY5Xn3g00Gl?si=50de69e6eb7e4018";

  final _playlistCtrl = TextEditingController();
  final _participantsCountCtrl = TextEditingController(text: "2");
  final _targetPointsCtrl = TextEditingController(text: "5");

  List<TextEditingController> _nameCtrls = [
    TextEditingController(text: "Jugador 1"),
    TextEditingController(text: "Jugador 2"),
  ];

  int _participantsCount = 2;

  @override
  void dispose() {
    _playlistCtrl.dispose();
    _participantsCountCtrl.dispose();
    _targetPointsCtrl.dispose();
    for (final c in _nameCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncNameControllers(int newCount) {
    if (newCount < 1) newCount = 1;
    if (newCount == _participantsCount) return;

    setState(() {
      // Expandir
      if (newCount > _participantsCount) {
        for (int i = _participantsCount; i < newCount; i++) {
          _nameCtrls.add(TextEditingController(text: "Jugador ${i + 1}"));
        }
      } else {
        // Reducir
        for (int i = _participantsCount - 1; i >= newCount; i--) {
          _nameCtrls[i].dispose();
          _nameCtrls.removeAt(i);
        }
      }
      _participantsCount = newCount;
    });
  }

  void _startGame() {
    final playlistUrl = _playlistCtrl.text.trim().isEmpty
        ? defaultPlaylistUrl
        : _playlistCtrl.text.trim();

    final targetPoints = int.tryParse(_targetPointsCtrl.text.trim()) ?? 5;

    final names = _nameCtrls
        .map((c) => c.text.trim())
        .map((n) => n.isEmpty ? "Sin nombre" : n)
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MusicGameScreen(
          playlistUrl: playlistUrl,
          playerNames: names,
          targetPoints: targetPoints,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Crear partida")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Link de playlist (si vacío, se usa una por defecto)"),
          const SizedBox(height: 8),
          TextField(
            controller: _playlistCtrl,
            decoration: const InputDecoration(
              hintText: "https://open.spotify.com/playlist/...",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          const Text("Número de participantes"),
          const SizedBox(height: 8),
          TextField(
            controller: _participantsCountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: "2",
            ),
            onChanged: (v) {
              final n = int.tryParse(v.trim()) ?? 1;
              _syncNameControllers(n);
            },
          ),

          const SizedBox(height: 12),
          const Text("Nombres"),
          const SizedBox(height: 8),
          ...List.generate(_nameCtrls.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _nameCtrls[i],
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: "Participante ${i + 1}",
                ),
              ),
            );
          }),

          const SizedBox(height: 16),
          const Text("Puntos a batir (el primero que llegue gana)"),
          const SizedBox(height: 8),
          TextField(
            controller: _targetPointsCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: "5",
            ),
          ),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _startGame,
            child: const Text("Comenzar partida"),
          ),
        ],
      ),
    );
  }
}
