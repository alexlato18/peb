import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/daily_game_models.dart';
import '../repositories/daily_games_repository.dart';

class ZipGameScreen extends StatefulWidget {
  const ZipGameScreen({
    super.key,
    required this.currentProfileId,
    required this.repository,
  });

  final String currentProfileId;
  final DailyGamesRepository repository;

  @override
  State<ZipGameScreen> createState() => _ZipGameScreenState();
}

class _ZipGameScreenState extends State<ZipGameScreen>
    with WidgetsBindingObserver {
  DailyChallenge? _challenge;
  DailyGameSession? _session;

  bool _loading = true;
  bool _saving = false;

  int _size = 0;
  List<_ZipPoint> _points = [];
  List<_ZipCell> _solutionPath = [];
  List<_ZipCell> _currentPath = [];

  StreamSubscription<DailyChallenge?>? _challengeSub;
  StreamSubscription<DailyGameSession?>? _sessionSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _challengeSub?.cancel();
    _sessionSub?.cancel();
    widget.repository.pauseSession(
      gameId: DailyGameId.zip.id,
      profileId: widget.currentProfileId,
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      widget.repository.pauseSession(
        gameId: DailyGameId.zip.id,
        profileId: widget.currentProfileId,
      );
    }
  }

  Future<void> _init() async {
    await widget.repository.startOrResumeSession(
      gameId: DailyGameId.zip.id,
      profileId: widget.currentProfileId,
    );

    _challengeSub = widget.repository
        .watchTodayChallenge(DailyGameId.zip.id)
        .listen((challenge) {
      _challenge = challenge;
      _applyChallengeIfPossible();
    });

    _sessionSub = widget.repository
        .watchTodaySession(DailyGameId.zip.id, widget.currentProfileId)
        .listen((session) {
      _session = session;
      _applySessionIfPossible();
    });
  }

  void _applyChallengeIfPossible() {
    final challenge = _challenge;
    if (challenge == null) return;

    final payload = challenge.payload;
    final size = (payload['size'] as num?)?.toInt() ?? 0;

    final pointsRaw = List<Map<String, dynamic>>.from(
      payload['points'] as List? ?? const [],
    );
    final solutionRaw = List<Map<String, dynamic>>.from(
      payload['solutionPath'] as List? ?? const [],
    );

    final points = pointsRaw
        .map(
          (e) => _ZipPoint(
            number: (e['n'] as num).toInt(),
            row: (e['row'] as num).toInt(),
            col: (e['col'] as num).toInt(),
          ),
        )
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));

    final solution = solutionRaw
        .map(
          (e) => _ZipCell(
            row: (e['row'] as num).toInt(),
            col: (e['col'] as num).toInt(),
          ),
        )
        .toList();

    if (!mounted) return;
    setState(() {
      _size = size;
      _points = points;
      _solutionPath = solution;
    });

    _applySessionIfPossible();
  }

  void _applySessionIfPossible() {
    if (_challenge == null) return;

    final pathRaw = List<Map<String, dynamic>>.from(
      _session?.sessionData['path'] as List? ?? const [],
    );
    final path = pathRaw
        .map(
          (e) => _ZipCell(
            row: (e['row'] as num).toInt(),
            col: (e['col'] as num).toInt(),
          ),
        )
        .toList();

    if (!mounted) return;
    setState(() {
      _currentPath = path;
      _loading = false;
    });
  }

  int? _pointNumberAt(int row, int col) {
    for (final point in _points) {
      if (point.row == row && point.col == col) {
        return point.number;
      }
    }
    return null;
  }

  int get _nextExpectedPoint {
    final visitedNumbers = <int>{};
    for (final cell in _currentPath) {
      final n = _pointNumberAt(cell.row, cell.col);
      if (n != null) visitedNumbers.add(n);
    }
    return visitedNumbers.length + 1;
  }

  bool _isAdjacent(_ZipCell a, _ZipCell b) {
    final dr = (a.row - b.row).abs();
    final dc = (a.col - b.col).abs();
    return dr + dc == 1;
  }

  bool _containsCell(_ZipCell cell) {
    return _currentPath.any((e) => e.row == cell.row && e.col == cell.col);
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      await widget.repository.saveZipProgress(
        profileId: widget.currentProfileId,
        path: _currentPath
            .map((e) => {'row': e.row, 'col': e.col})
            .toList(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _tryAppendCell(_ZipCell cell) {
    if (_session?.isCompleted == true) return;

    if (_currentPath.isEmpty) {
      final firstPoint = _pointNumberAt(cell.row, cell.col);
      if (firstPoint == 1) {
        setState(() {
          _currentPath = [cell];
        });
      }
      return;
    }

    final last = _currentPath.last;
    if (last.row == cell.row && last.col == cell.col) return;
    if (_containsCell(cell)) return;
    if (!_isAdjacent(last, cell)) return;

    final pointNumber = _pointNumberAt(cell.row, cell.col);
    if (pointNumber != null && pointNumber != _nextExpectedPoint) {
      return;
    }

    setState(() {
      _currentPath = [..._currentPath, cell];
    });
  }

  Future<void> _reset() async {
    if (_session?.isCompleted == true) return;

    setState(() {
      _currentPath = [];
    });

    await _save();
  }

  bool _cellInPath(int row, int col) {
    return _currentPath.any((e) => e.row == row && e.col == col);
  }

  _ZipCell? _cellAtIndex(int index) {
    if (index < 0 || index >= _currentPath.length) return null;
    return _currentPath[index];
  }

  @override
  Widget build(BuildContext context) {
    final completed = _session?.isCompleted == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zip'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _size <= 0
              ? const Center(child: Text('No se ha podido cargar el reto.'))
              : SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Text(
                                    completed
                                        ? 'Reto completado'
                                        : 'Une los puntos en orden y pasa por todas las celdas',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: completed ? null : _reset,
                              child: const Text('Restablecer'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final boardSize = math.min(
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  );
                                  final cellSize = boardSize / _size;

                                  return GestureDetector(
                                    onPanStart: (details) {
                                      final cell = _cellFromOffset(
                                        details.localPosition,
                                        boardSize,
                                        cellSize,
                                      );
                                      if (cell != null) {
                                        _tryAppendCell(cell);
                                      }
                                    },
                                    onPanUpdate: (details) {
                                      final cell = _cellFromOffset(
                                        details.localPosition,
                                        boardSize,
                                        cellSize,
                                      );
                                      if (cell != null) {
                                        _tryAppendCell(cell);
                                      }
                                    },
                                    onPanEnd: (_) => _save(),
                                    child: SizedBox(
                                      width: boardSize,
                                      height: boardSize,
                                      child: Stack(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.grey.shade500,
                                                width: 2,
                                              ),
                                              borderRadius: BorderRadius.circular(28),
                                            ),
                                          ),
                                          for (int row = 0; row < _size; row++)
                                            for (int col = 0; col < _size; col++)
                                              Positioned(
                                                left: col * cellSize,
                                                top: row * cellSize,
                                                width: cellSize,
                                                height: cellSize,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Colors.grey.shade400,
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      color: _cellInPath(row, col)
                                                          ? const Color(0x33D14FC7)
                                                          : Colors.transparent,
                                                    ),
                                                    child: Center(
                                                      child: _buildPointChip(
                                                        row,
                                                        col,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          CustomPaint(
                                            size: Size(boardSize, boardSize),
                                            painter: _ZipPathPainter(
                                              path: _currentPath,
                                              cellSize: cellSize,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Cómo se juega',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text('• Empieza en el punto 1'),
                                Text('• Une los puntos en orden'),
                                Text('• El trazo debe pasar por todas las casillas'),
                                Text('• No puedes reutilizar casillas'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget? _buildPointChip(int row, int col) {
    final point = _pointNumberAt(row, col);
    if (point == null) return null;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
        border: Border.all(
          color: point == 1 ? const Color(0xFFC94FC7) : Colors.black,
          width: point == 1 ? 3 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$point',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  _ZipCell? _cellFromOffset(Offset offset, double boardSize, double cellSize) {
    if (offset.dx < 0 ||
        offset.dy < 0 ||
        offset.dx >= boardSize ||
        offset.dy >= boardSize) {
      return null;
    }

    final col = (offset.dx / cellSize).floor();
    final row = (offset.dy / cellSize).floor();

    if (row < 0 || col < 0 || row >= _size || col >= _size) return null;
    return _ZipCell(row: row, col: col);
  }
}

class _ZipCell {
  const _ZipCell({
    required this.row,
    required this.col,
  });

  final int row;
  final int col;
}

class _ZipPoint {
  const _ZipPoint({
    required this.number,
    required this.row,
    required this.col,
  });

  final int number;
  final int row;
  final int col;
}

class _ZipPathPainter extends CustomPainter {
  const _ZipPathPainter({
    required this.path,
    required this.cellSize,
  });

  final List<_ZipCell> path;
  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;

    final paint = Paint()
      ..color = const Color(0xFF111111)
      ..strokeWidth = cellSize * 0.18
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final route = Path();

    final first = path.first;
    route.moveTo(
      first.col * cellSize + cellSize / 2,
      first.row * cellSize + cellSize / 2,
    );

    for (int i = 1; i < path.length; i++) {
      final cell = path[i];
      route.lineTo(
        cell.col * cellSize + cellSize / 2,
        cell.row * cellSize + cellSize / 2,
      );
    }

    canvas.drawPath(route, paint);
  }

  @override
  bool shouldRepaint(covariant _ZipPathPainter oldDelegate) {
    return oldDelegate.path != path || oldDelegate.cellSize != cellSize;
  }
}