import 'dart:math';
import 'package:flutter/material.dart';
import 'package:peb/models/music_game_models.dart';
import 'package:peb/services/spotify_playlist_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';


enum QuestionCategory { title, artist, year, followSong, name }

class MusicGameScreen extends StatefulWidget {
  const MusicGameScreen({
    super.key,
    required this.playlistUrl,
    required this.playerNames,
    required this.targetPoints,
  });

  final String playlistUrl;
  final List<String> playerNames;
  final int targetPoints;

  @override
  State<MusicGameScreen> createState() => _MusicGameScreenState();
}

class _MusicGameScreenState extends State<MusicGameScreen> {
  final _rng = Random();

  late final SpotifyPlaylistService _spotifyService;

  bool _loading = true;
  String? _error;

  late List<PlayerScore> _players;
  int _turnIndex = 0;

  List<MusicTrack> _tracks = [];
  MusicTrack? _currentTrack;
  QuestionCategory? _currentCategory;

  @override
  void initState() {
    super.initState();
    _spotifyService = SpotifyPlaylistService(FirebaseFunctions.instance);

    _players = widget.playerNames.map((n) => PlayerScore(name: n)).toList();

    _loadTracks();
  }
  Future<void> _openScorePicker() async {
  final selectedIndex = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "¿Quién ha acertado?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...List.generate(_players.length, (i) {
                final p = _players[i];
                return ListTile(
                  title: Text(p.name),
                  trailing: Text("${p.points}"),
                  onTap: () => Navigator.pop(ctx, i),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );

  if (selectedIndex == null) return;

  _addPointToPlayer(selectedIndex);
}

void _addPointToPlayer(int index) {
  final p = _players[index];

  setState(() {
    p.points += 1;
  });

  if (p.points >= widget.targetPoints) {
    _showWinnerDialog(p.name);
  }
}

  Future<void> _loadTracks() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tracks =
          await _spotifyService.fetchTracksFromPlaylist(widget.playlistUrl);

      if (tracks.isEmpty) {
        throw Exception("La playlist no tiene canciones o no se pudo leer.");
      }

      setState(() {
        _tracks = tracks;
        _pickNextTurn();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _pickNextTurn() {
    _currentTrack = _tracks[_rng.nextInt(_tracks.length)];
    _currentCategory =
        QuestionCategory.values[_rng.nextInt(QuestionCategory.values.length)];
  }

  String _categoryLabel(QuestionCategory c) {
    switch (c) {
      case QuestionCategory.title:
        return "Categoría: Título";
      case QuestionCategory.artist:
        return "Categoría: Artista";
      case QuestionCategory.year:
        return "Categoría: Año";
      case QuestionCategory.followSong:
        return "Categoría: Seguir la canción";
      case QuestionCategory.name:
        return "Categoría: Nombre";
    }
  }

  Future<void> _openSpotify(MusicTrack track) async {
    // Preferimos abrir en Spotify si está instalado
    // Para trackId -> spotify:track:ID (pero aquí ya tenemos url web)
    final web = Uri.parse(track.spotifyUrl);
    await launchUrl(web, mode: LaunchMode.externalApplication);
  }

  void _nextTurn() {
    setState(() {
      _turnIndex = (_turnIndex + 1) % _players.length;
      _pickNextTurn();
    });
  }

  void _addPointToCurrentPlayer() {
    final p = _players[_turnIndex];
    setState(() {
      p.points += 1;
    });

    if (p.points >= widget.targetPoints) {
      _showWinnerDialog(p.name);
    }
  }

  Future<void> _showWinnerDialog(String winnerName) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("¡Tenemos ganador!"),
        content: Text("$winnerName ha llegado a ${widget.targetPoints} puntos."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // dialog
              Navigator.pop(context); // salir del juego
            },
            child: const Text("Salir"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Seguir (sin reset)"),
          ),
        ],
      ),
    );
  }

  Future<void> _openMenuPanel() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Resultados",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Tabla simple
              ..._players
                  .map((p) => ListTile(
                        title: Text(p.name),
                        trailing: Text("${p.points}"),
                      ))
                  .toList(),

              const SizedBox(height: 12),
              

              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // salir del juego
                },
                icon: const Icon(Icons.exit_to_app),
                label: const Text("Salir del juego"),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addParticipantFlow() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Nuevo participante"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: "Nombre",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text("Añadir"),
          ),
        ],
      ),
    );

    ctrl.dispose();

    if (name == null || name.trim().isEmpty) return;

    setState(() {
      _players.add(PlayerScore(name: name.trim()));
      // si estabas en el último jugador, no pasa nada; el turno rota normal
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPlayer = _players[_turnIndex].name;

    return Scaffold(
      // “AppBar simulada” con icono centrado
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadTracks,
                            child: const Text("Reintentar"),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildGameUI(currentPlayer),
      ),
    );
  }

  Widget _buildGameUI(String currentPlayer) {
    final track = _currentTrack!;
    final category = _currentCategory!;

    return Column(
      children: [
        // Top bar “centrada” con botón tres barras
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Spacer(),
              IconButton(
                onPressed: _openMenuPanel,
                icon: const Icon(Icons.menu),
                tooltip: "Menú",
              ),
              const Spacer(),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                "Turno de: $currentPlayer",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              Text(
                _categoryLabel(category),
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              // Datos de la canción (orden: portada, nombre, artista, año)
              if (track.coverUrl.isNotEmpty)
                AspectRatio(
                  aspectRatio: 1, // cuadrado; si prefieres más “banner” usa 16/9
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: Colors.black12,
                      child: track.coverUrl.isNotEmpty
                          ? Image.network(
                              track.coverUrl,
                              fit: BoxFit.contain, // <-- clave para que NO se recorte
                              alignment: Alignment.center,
                            )
                          : const Center(child: Icon(Icons.image_not_supported)),
                    ),
                  ),
                )
              else
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black12,
                  ),
                  child: const Center(child: Icon(Icons.image_not_supported)),
                ),

              const SizedBox(height: 12),

              Text(
                track.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              Text(
                track.artists.join(", "),
                style: const TextStyle(fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              Text(
                "Año: ${track.releaseYear?.toString() ?? "N/D"}",
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Botones (izq abrir spotify, der siguiente turno)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openSpotify(track),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text("Abrir en Spotify"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _nextTurn,
                      icon: const Icon(Icons.skip_next),
                      label: const Text("Siguiente turno"),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Botoncito opcional para sumar punto (para test / árbitro)
              OutlinedButton(
                onPressed: _openScorePicker,
                child: const Text("✅ Acierto (sumar punto)"),
              ),

            ],
          ),
        ),
      ],
    );
  }
}
