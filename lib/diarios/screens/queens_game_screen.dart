import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/daily_game_models.dart';
import '../repositories/daily_games_repository.dart';

class QueensGameScreen extends StatefulWidget {
  const QueensGameScreen({
    super.key,
    required this.currentProfileId,
    required this.repository,
  });

  final String currentProfileId;
  final DailyGamesRepository repository;

  @override
  State<QueensGameScreen> createState() => _QueensGameScreenState();
}

class _QueensGameScreenState extends State<QueensGameScreen>
    with WidgetsBindingObserver {
  DailyChallenge? _challenge;
  DailyGameSession? _session;

  bool _loading = true;
  bool _saving = false;

  int _size = 0;
  List<List<int>> _regions = [];

  final Set<String> _queens = {};
  final Set<String> _marks = {};

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
        gameId: DailyGameId.queens.id,
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
          gameId: DailyGameId.queens.id,
          profileId: widget.currentProfileId,
        ),
      );
    }
  }

  Future<void> _init() async {
    await widget.repository.startOrResumeSession(
      gameId: DailyGameId.queens.id,
      profileId: widget.currentProfileId,
    );

    _challengeSub = widget.repository
        .watchTodayChallenge(DailyGameId.queens.id)
        .listen((challenge) {
      _challenge = challenge;
      _applyChallengeIfPossible();
    });

    _sessionSub = widget.repository
        .watchTodaySession(DailyGameId.queens.id, widget.currentProfileId)
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
    final regionsRows =
        List<String>.from(payload['regionsRows'] as List? ?? const []);

    final parsedRegions = regionsRows.map<List<int>>((row) {
      return row.split(',').map((cell) => int.parse(cell)).toList();
    }).toList();

    if (!mounted) return;
    setState(() {
      _size = size;
      _regions = parsedRegions;
    });

    _applySessionIfPossible();
  }

  void _applySessionIfPossible() {
    if (_challenge == null) return;

    final session = _session;
    final queens = List<String>.from(
      session?.sessionData['queens'] as List? ?? const [],
    );
    final marks = List<String>.from(
      session?.sessionData['marks'] as List? ?? const [],
    );

    if (!mounted) return;
    setState(() {
      _queens
        ..clear()
        ..addAll(queens);
      _marks
        ..clear()
        ..addAll(marks);
      _loading = false;
    });
  }

  String _cellKey(int row, int col) => '${row}_$col';

  bool _hasQueen(int row, int col) => _queens.contains(_cellKey(row, col));

  bool _hasMark(int row, int col) => _marks.contains(_cellKey(row, col));

  Future<void> _save() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      await widget.repository.saveQueensProgress(
        profileId: widget.currentProfileId,
        queens: _queens.toList(),
        marks: _marks.toList(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _onTapCell(int row, int col) async {
    if (_session?.isCompleted == true) return;

    final key = _cellKey(row, col);

    setState(() {
      if (_queens.contains(key)) {
        _queens.remove(key);
      } else if (_marks.contains(key)) {
        _marks.remove(key);
        _queens.add(key);
      } else {
        _marks.add(key);
      }
    });

    await _save();
  }

  Future<void> _onLongPressCell(int row, int col) async {
    if (_session?.isCompleted == true) return;

    final key = _cellKey(row, col);

    setState(() {
      if (_queens.contains(key)) {
        _queens.remove(key);
        _marks.add(key);
      } else {
        _marks.remove(key);
      }
    });

    await _save();
  }

  Future<void> _resetBoard() async {
    if (_session?.isCompleted == true) return;

    setState(() {
      _queens.clear();
      _marks.clear();
    });

    await _save();
  }

  int _countQueensInRow(int row) {
    int total = 0;
    for (int col = 0; col < _size; col++) {
      if (_hasQueen(row, col)) total++;
    }
    return total;
  }

  int _countQueensInCol(int col) {
    int total = 0;
    for (int row = 0; row < _size; row++) {
      if (_hasQueen(row, col)) total++;
    }
    return total;
  }

  int _countQueensInRegion(int regionId) {
    int total = 0;
    for (int row = 0; row < _size; row++) {
      for (int col = 0; col < _size; col++) {
        if (_regions[row][col] == regionId && _hasQueen(row, col)) {
          total++;
        }
      }
    }
    return total;
  }

  bool _rowHasConflict(int row) => _countQueensInRow(row) > 1;

  bool _colHasConflict(int col) => _countQueensInCol(col) > 1;

  bool _regionHasConflict(int regionId) => _countQueensInRegion(regionId) > 1;

  bool _queenHasAdjacentConflict(int row, int col) {
    if (!_hasQueen(row, col)) return false;

    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = row + dr;
        final nc = col + dc;
        if (nr < 0 || nc < 0 || nr >= _size || nc >= _size) continue;
        if (_hasQueen(nr, nc)) return true;
      }
    }
    return false;
  }

  Color _regionColor(int regionId) {
    const palette = <Color>[
      Color(0xFFF57C5C),
      Color(0xFFE7BB83),
      Color(0xFF87A8DE),
      Color(0xFFA8CD95),
      Color(0xFFB3A4D7),
      Color(0xFFCBCBCB),
      Color(0xFFCF95B5),
      Color(0xFFD0DE76),
      Color(0xFFB9B29F),
      Color(0xFF94B4E8),
      Color(0xFFE0A4A4),
      Color(0xFFA7D9D1),
    ];

    return palette[regionId % palette.length];
  }

  bool _hasTopBorder(int row, int col) {
    if (row == 0) return true;
    return _regions[row][col] != _regions[row - 1][col];
  }

  bool _hasBottomBorder(int row, int col) {
    if (row == _size - 1) return true;
    return _regions[row][col] != _regions[row + 1][col];
  }

  bool _hasLeftBorder(int row, int col) {
    if (col == 0) return true;
    return _regions[row][col] != _regions[row][col - 1];
  }

  bool _hasRightBorder(int row, int col) {
    if (col == _size - 1) return true;
    return _regions[row][col] != _regions[row][col + 1];
  }

  @override
  Widget build(BuildContext context) {
    final completed = _session?.isCompleted == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queens'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _size <= 0 || _regions.isEmpty
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
                              child: _TopInfoCard(
                                title: completed ? 'Completado' : 'En curso',
                                subtitle: completed
                                    ? 'Reto diario resuelto'
                                    : '1 reina por fila, columna y región',
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
                                                onTap: () => _onTapCell(row, col),
                                                onLongPress: () =>
                                                    _onLongPressCell(row, col),
                                                child: _QueensCell(
                                                  color: _regionColor(
                                                    _regions[row][col],
                                                  ),
                                                  showQueen: _hasQueen(row, col),
                                                  showMark: _hasMark(row, col),
                                                  hasConflict:
                                                      _rowHasConflict(row) ||
                                                      _colHasConflict(col) ||
                                                      _regionHasConflict(
                                                        _regions[row][col],
                                                      ) ||
                                                      _queenHasAdjacentConflict(
                                                        row,
                                                        col,
                                                      ),
                                                  topBorder:
                                                      _hasTopBorder(row, col),
                                                  rightBorder:
                                                      _hasRightBorder(row, col),
                                                  bottomBorder:
                                                      _hasBottomBorder(row, col),
                                                  leftBorder:
                                                      _hasLeftBorder(row, col),
                                                ),
                                              ),
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
                                Text('• Un toque: vacío → X → reina → vacío'),
                                Text('• Pulsación larga: quitar o dejar en X'),
                                Text('• Debe haber exactamente una reina por fila, columna y región'),
                                Text('• Las reinas no pueden tocarse, ni en diagonal'),
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
}

class _TopInfoCard extends StatelessWidget {
  const _TopInfoCard({
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

class _QueensCell extends StatelessWidget {
  const _QueensCell({
    required this.color,
    required this.showQueen,
    required this.showMark,
    required this.hasConflict,
    required this.topBorder,
    required this.rightBorder,
    required this.bottomBorder,
    required this.leftBorder,
  });

  final Color color;
  final bool showQueen;
  final bool showMark;
  final bool hasConflict;
  final bool topBorder;
  final bool rightBorder;
  final bool bottomBorder;
  final bool leftBorder;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasConflict ? Colors.red.shade700 : Colors.black;
    final thinBorder = BorderSide(color: Colors.black26, width: 0.7);
    final thickBorder = BorderSide(color: borderColor, width: 2.4);

    return Container(
      decoration: BoxDecoration(
        color: color,
        border: Border(
          top: topBorder ? thickBorder : thinBorder,
          right: rightBorder ? thickBorder : thinBorder,
          bottom: bottomBorder ? thickBorder : thinBorder,
          left: leftBorder ? thickBorder : thinBorder,
        ),
      ),
      child: Center(
        child: showQueen
            ? Icon(
                Icons.workspace_premium,
                size: 28,
                color: hasConflict ? Colors.red.shade900 : Colors.black,
              )
            : showMark
                ? Text(
                    'X',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withValues(alpha: 0.70),
                    ),
                  )
                : null,
      ),
    );
  }
}