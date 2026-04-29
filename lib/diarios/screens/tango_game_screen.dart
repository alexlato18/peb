import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/daily_game_models.dart';
import '../repositories/daily_games_repository.dart';

class TangoGameScreen extends StatefulWidget {
  const TangoGameScreen({
    super.key,
    required this.currentProfileId,
    required this.repository,
  });

  final String currentProfileId;
  final DailyGamesRepository repository;

  @override
  State<TangoGameScreen> createState() => _TangoGameScreenState();
}

class _TangoGameScreenState extends State<TangoGameScreen>
    with WidgetsBindingObserver {
  DailyChallenge? _challenge;
  DailyGameSession? _session;

  bool _loading = true;
  bool _saving = false;

  int _size = 0;
  List<List<int?>> _initialBoard = [];
  List<List<int?>> _currentBoard = [];
  List<_TangoConstraint> _constraints = [];

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
    unawaited(
      widget.repository.pauseSession(
        gameId: DailyGameId.tango.id,
        profileId: widget.currentProfileId,
      ),
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(
        widget.repository.pauseSession(
          gameId: DailyGameId.tango.id,
          profileId: widget.currentProfileId,
        ),
      );
    }
  }

  Future<void> _init() async {
    await widget.repository.startOrResumeSession(
      gameId: DailyGameId.tango.id,
      profileId: widget.currentProfileId,
    );

    _challengeSub = widget.repository
        .watchTodayChallenge(DailyGameId.tango.id)
        .listen((challenge) {
      _challenge = challenge;
      _applyChallengeIfPossible();
    });

    _sessionSub = widget.repository
        .watchTodaySession(DailyGameId.tango.id, widget.currentProfileId)
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

    final initialRows =
        List<String>.from(payload['initialBoardRows'] as List? ?? const []);
    final initialBoard = _parseBoardRows(initialRows);

    final constraints = _parseConstraints(payload);

    if (!mounted) return;
    setState(() {
      _size = size;
      _initialBoard = initialBoard;
      _constraints = constraints;
    });

    _applySessionIfPossible();
  }

  void _applySessionIfPossible() {
    if (_challenge == null) return;

    final sessionRows = List<String>.from(
      _session?.sessionData['currentBoardRows'] as List? ?? const [],
    );

    final board = sessionRows.isEmpty
        ? _cloneBoard(_initialBoard)
        : _parseBoardRows(sessionRows);

    if (!mounted) return;
    setState(() {
      _currentBoard = board;
      _loading = false;
    });
  }

  static List<List<int?>> _parseBoardRows(List<String> rows) {
    return rows.map((row) {
      return row.split(',').map<int?>((cell) {
        final value = cell.trim();
        if (value == '_') return null;
        return int.parse(value);
      }).toList();
    }).toList();
  }

  List<_TangoConstraint> _parseConstraints(Map<String, dynamic> payload) {
    final constraintsRaw = payload['constraints'];

    if (constraintsRaw is List) {
      return constraintsRaw
          .map(
            (e) => _TangoConstraint.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }

    final constraintsJson = payload['constraintsJson'];

    if (constraintsJson is String && constraintsJson.trim().isNotEmpty) {
      final decoded = jsonDecode(constraintsJson);

      if (decoded is List) {
        return decoded
            .map(
              (e) => _TangoConstraint.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      }
    }

    return [];
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      await widget.repository.saveTangoProgress(
        profileId: widget.currentProfileId,
        currentBoard: _currentBoard,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  bool _isFixedCell(int row, int col) => _initialBoard[row][col] != null;

  Future<void> _onTapCell(int row, int col) async {
    if (_session?.isCompleted == true) return;
    if (_isFixedCell(row, col)) return;

    final current = _currentBoard[row][col];

    setState(() {
      if (current == null) {
        _currentBoard[row][col] = 1;
      } else if (current == 1) {
        _currentBoard[row][col] = 0;
      } else {
        _currentBoard[row][col] = null;
      }
    });

    await _save();
  }

  Future<void> _resetBoard() async {
    if (_session?.isCompleted == true) return;

    setState(() {
      _currentBoard = _cloneBoard(_initialBoard);
    });

    await _save();
  }

  int _rowCount(int row, int value) {
    int total = 0;
    for (int col = 0; col < _size; col++) {
      if (_currentBoard[row][col] == value) total++;
    }
    return total;
  }

  int _colCount(int col, int value) {
    int total = 0;
    for (int row = 0; row < _size; row++) {
      if (_currentBoard[row][col] == value) total++;
    }
    return total;
  }

  bool _rowHasTooMany(int row) {
    final limit = _size ~/ 2;
    return _rowCount(row, 0) > limit || _rowCount(row, 1) > limit;
  }

  bool _colHasTooMany(int col) {
    final limit = _size ~/ 2;
    return _colCount(col, 0) > limit || _colCount(col, 1) > limit;
  }

  bool _hasTripleInRowAt(int row, int col) {
    final value = _currentBoard[row][col];
    if (value == null) return false;

    for (int start = math.max(0, col - 2);
        start <= math.min(col, _size - 3);
        start++) {
      final a = _currentBoard[row][start];
      final b = _currentBoard[row][start + 1];
      final c = _currentBoard[row][start + 2];
      if (a != null && a == b && b == c) return true;
    }

    return false;
  }

  bool _hasTripleInColAt(int row, int col) {
    final value = _currentBoard[row][col];
    if (value == null) return false;

    for (int start = math.max(0, row - 2);
        start <= math.min(row, _size - 3);
        start++) {
      final a = _currentBoard[start][col];
      final b = _currentBoard[start + 1][col];
      final c = _currentBoard[start + 2][col];
      if (a != null && a == b && b == c) return true;
    }

    return false;
  }

  bool _constraintFailsAt(int row, int col) {
    for (final constraint in _constraints) {
      final touchesFirst = constraint.r1 == row && constraint.c1 == col;
      final touchesSecond = constraint.r2 == row && constraint.c2 == col;
      if (!touchesFirst && !touchesSecond) continue;

      final v1 = _currentBoard[constraint.r1][constraint.c1];
      final v2 = _currentBoard[constraint.r2][constraint.c2];
      if (v1 == null || v2 == null) continue;

      if (constraint.type == 'same' && v1 != v2) return true;
      if (constraint.type == 'different' && v1 == v2) return true;
    }
    return false;
  }

  bool _cellHasConflict(int row, int col) {
    return _rowHasTooMany(row) ||
        _colHasTooMany(col) ||
        _hasTripleInRowAt(row, col) ||
        _hasTripleInColAt(row, col) ||
        _constraintFailsAt(row, col);
  }

  String _ruleSummary() {
    return 'No puede haber 3 iguales seguidos y cada fila/columna debe tener la misma cantidad de soles y lunas.';
  }

  @override
  Widget build(BuildContext context) {
    final completed = _session?.isCompleted == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tango'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _size <= 0 || _currentBoard.isEmpty
              ? const Center(child: Text('No se ha podido cargar el tablero.'))
              : SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _TangoInfoCard(
                                title: completed ? 'Completado' : 'En curso',
                                subtitle: _ruleSummary(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: completed ? null : _resetBoard,
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

                                  return SizedBox(
                                    width: boardSize,
                                    height: boardSize,
                                    child: Stack(
                                      children: [
                                        for (int row = 0; row < _size; row++)
                                          for (int col = 0; col < _size; col++)
                                            Positioned(
                                              left: col * cellSize,
                                              top: row * cellSize,
                                              width: cellSize,
                                              height: cellSize,
                                              child: GestureDetector(
                                                onTap: () =>
                                                    _onTapCell(row, col),
                                                child: _TangoCell(
                                                  value:
                                                      _currentBoard[row][col],
                                                  fixed:
                                                      _isFixedCell(row, col),
                                                  hasConflict:
                                                      _cellHasConflict(
                                                    row,
                                                    col,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        for (final relation in _constraints)
                                          _buildRelationOverlay(
                                            relation: relation,
                                            cellSize: cellSize,
                                          ),
                                      ],
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
                                  'Controles',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '• Toca una casilla vacía para alternar: sol → luna → vacío',
                                ),
                                Text(
                                  '• = significa que ambas casillas deben ser iguales',
                                ),
                                Text(
                                  '• × significa que ambas casillas deben ser distintas',
                                ),
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

  Widget _buildRelationOverlay({
    required _TangoConstraint relation,
    required double cellSize,
  }) {
    final horizontal =
        relation.r1 == relation.r2 && (relation.c1 - relation.c2).abs() == 1;
    final vertical =
        relation.c1 == relation.c2 && (relation.r1 - relation.r2).abs() == 1;

    if (!horizontal && !vertical) {
      return const SizedBox.shrink();
    }

    final symbol = relation.type == 'same' ? '=' : '×';
    final color = Colors.brown.shade400;

    if (horizontal) {
      final row = relation.r1;
      final minCol = math.min(relation.c1, relation.c2);
      return Positioned(
        left: (minCol + 1) * cellSize - 12,
        top: row * cellSize + (cellSize / 2) - 12,
        width: 24,
        height: 24,
        child: Center(
          child: Text(
            symbol,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      );
    }

    final col = relation.c1;
    final minRow = math.min(relation.r1, relation.r2);
    return Positioned(
      left: col * cellSize + (cellSize / 2) - 12,
      top: (minRow + 1) * cellSize - 12,
      width: 24,
      height: 24,
      child: Center(
        child: Text(
          symbol,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  static List<List<int?>> _cloneBoard(List rawBoard) {
    return rawBoard.map<List<int?>>((row) {
      final rowList = row as List;
      return rowList.map<int?>((cell) {
        if (cell == null) return null;
        return (cell as num).toInt();
      }).toList();
    }).toList();
  }
}

class _TangoInfoCard extends StatelessWidget {
  const _TangoInfoCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

class _TangoCell extends StatelessWidget {
  const _TangoCell({
    required this.value,
    required this.fixed,
    required this.hasConflict,
  });

  final int? value;
  final bool fixed;
  final bool hasConflict;

  @override
  Widget build(BuildContext context) {
    final bgColor = fixed
        ? Colors.brown.shade50
        : hasConflict
            ? Colors.red.shade50
            : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
          color: hasConflict ? Colors.red.shade700 : Colors.black12,
          width: hasConflict ? 1.8 : 1,
        ),
      ),
      child: Center(
        child: value == null
            ? null
            : value == 1
                ? const _SunIcon()
                : const _MoonIcon(),
      ),
    );
  }
}

class _SunIcon extends StatelessWidget {
  const _SunIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFF5A623),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFCB7A17),
          width: 2,
        ),
      ),
    );
  }
}

class _MoonIcon extends StatelessWidget {
  const _MoonIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: CustomPaint(
        painter: _MoonPainter(),
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blue = Paint()..color = const Color(0xFF3578D4);
    final light = Paint()..color = const Color(0xFF6EA7F0);

    final center = Offset(size.width * 0.45, size.height * 0.50);
    final radius = size.width * 0.34;

    canvas.drawCircle(center, radius, blue);
    canvas.drawCircle(
      Offset(size.width * 0.60, size.height * 0.40),
      radius * 0.95,
      light,
    );

    final cutPaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.42),
      radius,
      cutPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TangoConstraint {
  _TangoConstraint({
    required this.r1,
    required this.c1,
    required this.r2,
    required this.c2,
    required this.type,
  });

  final int r1;
  final int c1;
  final int r2;
  final int c2;
  final String type;

  factory _TangoConstraint.fromMap(Map<String, dynamic> map) {
    return _TangoConstraint(
      r1: (map['r1'] as num).toInt(),
      c1: (map['c1'] as num).toInt(),
      r2: (map['r2'] as num).toInt(),
      c2: (map['c2'] as num).toInt(),
      type: map['type'] as String? ?? 'same',
    );
  }
}