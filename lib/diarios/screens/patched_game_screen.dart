import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/daily_game_models.dart';
import '../repositories/daily_games_repository.dart';

class PatchedGameScreen extends StatefulWidget {
  const PatchedGameScreen({
    super.key,
    required this.currentProfileId,
    required this.repository,
  });

  final String currentProfileId;
  final DailyGamesRepository repository;

  @override
  State<PatchedGameScreen> createState() => _PatchedGameScreenState();
}

class _PatchedGameScreenState extends State<PatchedGameScreen>
    with WidgetsBindingObserver {
  DailyChallenge? _challenge;
  DailyGameSession? _session;

  bool _loading = true;
  bool _saving = false;

  int _size = 0;
  List<_PatchPiece> _pieces = [];
  Map<String, _PatchRect> _placements = {};

  String? _draggingPieceId;
  _PatchRect? _previewRect;

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
      gameId: DailyGameId.patches.id,
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
        gameId: DailyGameId.patches.id,
        profileId: widget.currentProfileId,
      );
    }
  }

  Future<void> _init() async {
    await widget.repository.startOrResumeSession(
      gameId: DailyGameId.patches.id,
      profileId: widget.currentProfileId,
    );

    _challengeSub = widget.repository
        .watchTodayChallenge(DailyGameId.patches.id)
        .listen((challenge) {
      _challenge = challenge;
      _applyChallengeIfPossible();
    });

    _sessionSub = widget.repository
        .watchTodaySession(DailyGameId.patches.id, widget.currentProfileId)
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

    final piecesRaw = List<Map<String, dynamic>>.from(
      payload['pieces'] as List? ?? const [],
    );

    final pieces = piecesRaw
        .map(
          (e) => _PatchPiece(
            id: e['id'] as String? ?? '',
            row: (e['row'] as num).toInt(),
            col: (e['col'] as num).toInt(),
            area: (e['size'] as num).toInt(),
            type: e['type'] as String? ?? 'any',
          ),
        )
        .toList();

    if (!mounted) return;
    setState(() {
      _size = size;
      _pieces = pieces;
    });

    _applySessionIfPossible();
  }

  void _applySessionIfPossible() {
    if (_challenge == null) return;

    final placementsRaw = Map<String, dynamic>.from(
      _session?.sessionData['placements'] as Map? ?? const {},
    );

    final parsed = <String, _PatchRect>{};
    for (final entry in placementsRaw.entries) {
      final map = Map<String, dynamic>.from(entry.value as Map);
      parsed[entry.key] = _PatchRect(
        row: (map['row'] as num).toInt(),
        col: (map['col'] as num).toInt(),
        width: (map['width'] as num).toInt(),
        height: (map['height'] as num).toInt(),
      );
    }

    if (!mounted) return;
    setState(() {
      _placements = parsed;
      _loading = false;
    });
  }

  Color _pieceColor(int index) {
    const colors = [
      Color(0xFFEF5350),
      Color(0xFFFFCA28),
      Color(0xFF66BB6A),
      Color(0xFF7E57C2),
      Color(0xFF26A69A),
      Color(0xFF42A5F5),
      Color(0xFFFF7043),
      Color(0xFFAB47BC),
    ];
    return colors[index % colors.length];
  }

  _PatchPiece? _pieceById(String id) {
    for (final piece in _pieces) {
      if (piece.id == id) return piece;
    }
    return null;
  }

  _PatchPiece? _pieceAtAnchor(int row, int col) {
    for (final piece in _pieces) {
      if (piece.row == row && piece.col == col) return piece;
    }
    return null;
  }

  bool _rectContainsAnchor(_PatchRect rect, _PatchPiece piece) {
    return piece.row >= rect.row &&
        piece.row < rect.row + rect.height &&
        piece.col >= rect.col &&
        piece.col < rect.col + rect.width;
  }

  bool _rectInsideBoard(_PatchRect rect) {
    return rect.row >= 0 &&
        rect.col >= 0 &&
        rect.row + rect.height <= _size &&
        rect.col + rect.width <= _size;
  }

  bool _rectMatchesPieceRules(_PatchRect rect, _PatchPiece piece) {
    final area = rect.width * rect.height;
    if (area != piece.area) return false;
    if (!_rectContainsAnchor(rect, piece)) return false;
    if (!_rectInsideBoard(rect)) return false;

    switch (piece.type) {
      case 'square':
        return rect.width == rect.height;
      case 'horizontal':
        return rect.width > rect.height;
      case 'vertical':
        return rect.height > rect.width;
      case 'any':
      default:
        return true;
    }
  }

  List<_PatchRect> _rectanglesFromAnchorToCell(_PatchPiece piece, int row, int col) {
    final out = <_PatchRect>[];

    for (int h = 1; h <= piece.area; h++) {
      if (piece.area % h != 0) continue;
      final w = piece.area ~/ h;

      switch (piece.type) {
        case 'square':
          if (w != h) continue;
          break;
        case 'horizontal':
          if (w <= h) continue;
          break;
        case 'vertical':
          if (h <= w) continue;
          break;
        case 'any':
          break;
      }

      final minTop = math.min(piece.row, row) - h + 1;
      final maxTop = math.min(piece.row, row);
      final minLeft = math.min(piece.col, col) - w + 1;
      final maxLeft = math.min(piece.col, col);

      for (int top = minTop; top <= maxTop; top++) {
        for (int left = minLeft; left <= maxLeft; left++) {
          final rect = _PatchRect(
            row: top,
            col: left,
            width: w,
            height: h,
          );

          if (!_rectMatchesPieceRules(rect, piece)) continue;

          final containsDraggedCell = row >= rect.row &&
              row < rect.row + rect.height &&
              col >= rect.col &&
              col < rect.col + rect.width;

          if (!containsDraggedCell) continue;

          out.add(rect);
        }
      }
    }

    out.sort((a, b) {
      final da = _distanceRectToCellCenter(a, row, col);
      final db = _distanceRectToCellCenter(b, row, col);
      return da.compareTo(db);
    });

    return out;
  }

  double _distanceRectToCellCenter(_PatchRect rect, int row, int col) {
    final centerRow = rect.row + (rect.height - 1) / 2;
    final centerCol = rect.col + (rect.width - 1) / 2;
    return (centerRow - row).abs() + (centerCol - col).abs();
  }

  _PatchRect? _buildPreviewRect({
    required _PatchPiece piece,
    required int row,
    required int col,
  }) {
    final candidates = _rectanglesFromAnchorToCell(piece, row, col);
    if (candidates.isEmpty) return null;
    return candidates.first;
  }

  bool _rectsOverlap(_PatchRect a, _PatchRect b) {
    return !(a.col + a.width <= b.col ||
        b.col + b.width <= a.col ||
        a.row + a.height <= b.row ||
        b.row + b.height <= a.row);
  }

  bool _hasOverlapAtCell(int row, int col) {
    int count = 0;

    for (final entry in _placements.entries) {
      final rect = entry.value;
      if (_cellInsideRect(row, col, rect)) count++;
    }

    if (_previewRect != null && _cellInsideRect(row, col, _previewRect!)) {
      count++;
    }

    return count > 1;
  }

  bool _cellInsideRect(int row, int col, _PatchRect rect) {
    return row >= rect.row &&
        row < rect.row + rect.height &&
        col >= rect.col &&
        col < rect.col + rect.width;
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final map = <String, Map<String, int>>{};
      for (final entry in _placements.entries) {
        map[entry.key] = {
          'row': entry.value.row,
          'col': entry.value.col,
          'width': entry.value.width,
          'height': entry.value.height,
        };
      }

      await widget.repository.savePatchesProgress(
        profileId: widget.currentProfileId,
        placements: map,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _reset() async {
    if (_session?.isCompleted == true) return;

    setState(() {
      _placements = {};
      _draggingPieceId = null;
      _previewRect = null;
    });

    await _save();
  }

  void _startDrag(_PatchPiece piece) {
    if (_session?.isCompleted == true) return;

    setState(() {
      _draggingPieceId = piece.id;
      _previewRect = _placements[piece.id];
    });
  }

  void _updateDrag(_PatchPiece piece, int row, int col) {
    if (_draggingPieceId != piece.id) return;

    final preview = _buildPreviewRect(
      piece: piece,
      row: row,
      col: col,
    );

    setState(() {
      _previewRect = preview;
    });
  }

  Future<void> _endDrag(_PatchPiece piece) async {
    if (_draggingPieceId != piece.id) return;

    final preview = _previewRect;

    setState(() {
      _draggingPieceId = null;
      _previewRect = null;
      if (preview != null) {
        _placements[piece.id] = preview;
      }
    });

    await _save();
  }

  _BoardCell? _cellFromOffset(Offset offset, double boardSize, double cellSize) {
    if (offset.dx < 0 ||
        offset.dy < 0 ||
        offset.dx >= boardSize ||
        offset.dy >= boardSize) {
      return null;
    }

    final col = (offset.dx / cellSize).floor();
    final row = (offset.dy / cellSize).floor();

    if (row < 0 || col < 0 || row >= _size || col >= _size) return null;
    return _BoardCell(row: row, col: col);
  }

  Color _buildCellColor(int row, int col) {
    if (_hasOverlapAtCell(row, col)) return Colors.red.shade100;

    for (int i = 0; i < _pieces.length; i++) {
      final piece = _pieces[i];
      final placedRect = _placements[piece.id];
      if (placedRect != null && _cellInsideRect(row, col, placedRect)) {
        return _pieceColor(i).withOpacity(0.28);
      }
    }

    if (_draggingPieceId != null && _previewRect != null) {
      final index = _pieces.indexWhere((e) => e.id == _draggingPieceId);
      if (index >= 0 && _cellInsideRect(row, col, _previewRect!)) {
        return _pieceColor(index).withOpacity(0.20);
      }
    }

    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final completed = _session?.isCompleted == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patches'),
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
                                        : 'Pulsa una pieza y arrastra para construir su figura',
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
                                    behavior: HitTestBehavior.opaque,
                                    onPanStart: (details) {
                                      final cell = _cellFromOffset(
                                        details.localPosition,
                                        boardSize,
                                        cellSize,
                                      );
                                      if (cell == null) return;

                                      final piece = _pieceAtAnchor(cell.row, cell.col);
                                      if (piece == null) return;

                                      _startDrag(piece);
                                      _updateDrag(piece, cell.row, cell.col);
                                    },
                                    onPanUpdate: (details) {
                                      if (_draggingPieceId == null) return;
                                      final piece = _pieceById(_draggingPieceId!);
                                      if (piece == null) return;

                                      final cell = _cellFromOffset(
                                        details.localPosition,
                                        boardSize,
                                        cellSize,
                                      );
                                      if (cell == null) return;

                                      _updateDrag(piece, cell.row, cell.col);
                                    },
                                    onPanEnd: (_) async {
                                      if (_draggingPieceId == null) return;
                                      final piece = _pieceById(_draggingPieceId!);
                                      if (piece == null) return;
                                      await _endDrag(piece);
                                    },
                                    child: SizedBox(
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
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Colors.grey.shade400,
                                                      width: 0.8,
                                                    ),
                                                    color: _buildCellColor(row, col),
                                                  ),
                                                ),
                                              ),
                                          for (int i = 0; i < _pieces.length; i++)
                                            Positioned(
                                              left: _pieces[i].col * cellSize,
                                              top: _pieces[i].row * cellSize,
                                              width: cellSize,
                                              height: cellSize,
                                              child: Center(
                                                child: Container(
                                                  width: cellSize * 0.65,
                                                  height: cellSize * 0.65,
                                                  decoration: BoxDecoration(
                                                    color: _pieceColor(i),
                                                    borderRadius:
                                                        BorderRadius.circular(10),
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    '${_pieces[i].area}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 20,
                                                    ),
                                                  ),
                                                ),
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
                                Text('• Pulsa sobre un número y arrastra'),
                                Text('• El rectángulo debe contener ese número'),
                                Text('• El área debe coincidir con el número'),
                                Text('• Respeta el tipo: cuadrado, alto, ancho o cualquiera'),
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

class _PatchPiece {
  const _PatchPiece({
    required this.id,
    required this.row,
    required this.col,
    required this.area,
    required this.type,
  });

  final String id;
  final int row;
  final int col;
  final int area;
  final String type;
}

class _PatchRect {
  const _PatchRect({
    required this.row,
    required this.col,
    required this.width,
    required this.height,
  });

  final int row;
  final int col;
  final int width;
  final int height;
}

class _BoardCell {
  const _BoardCell({
    required this.row,
    required this.col,
  });

  final int row;
  final int col;
}