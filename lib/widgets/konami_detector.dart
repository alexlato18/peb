import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KonamiDetector extends StatefulWidget {
  const KonamiDetector({
    super.key,
    required this.child,
    required this.onCompleted,
  });

  final Widget child;
  final VoidCallback onCompleted;

  @override
  State<KonamiDetector> createState() => _KonamiDetectorState();
}

class _KonamiDetectorState extends State<KonamiDetector> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'KonamiDetector');

  static const List<String> _sequence = [
    'up',
    'up',
    'down',
    'down',
    'left',
    'right',
    'left',
    'right',
    'b',
    'a',
  ];

  int _index = 0;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _push(String input) {
    if (input == _sequence[_index]) {
      _index++;

      if (_index >= _sequence.length) {
        _index = 0;
        widget.onCompleted();
      }
    } else {
      _index = input == _sequence.first ? 1 : 0;
    }
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      _push('up');
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _push('down');
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _push('left');
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _push('right');
    } else if (key == LogicalKeyboardKey.keyB) {
      _push('b');
    } else if (key == LogicalKeyboardKey.keyA) {
      _push('a');
    }
  }

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity;

    // Este detector está pensado para horizontal o vertical según el gesto.
    // Como GestureDetector no distingue aquí el eje fácilmente, usamos velocity.
    if (velocity == null) return;
  }

  void _handleVerticalSwipe(DragEndDetails details) {
    final dy = details.primaryVelocity ?? 0;

    if (dy < -250) {
      _push('up');
    } else if (dy > 250) {
      _push('down');
    }
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    final dx = details.primaryVelocity ?? 0;

    if (dx < -250) {
      _push('left');
    } else if (dx > 250) {
      _push('right');
    }
  }

  void _handleTap(TapUpDetails details, BoxConstraints constraints) {
    final x = details.localPosition.dx;
    final middle = constraints.maxWidth / 2;

    if (x < middle) {
      _push('b');
    } else {
      _push('a');
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (_) {
              if (!_focusNode.hasFocus) {
                _focusNode.requestFocus();
              }
            },
            onTapUp: (details) => _handleTap(details, constraints),
            onVerticalDragEnd: _handleVerticalSwipe,
            onHorizontalDragEnd: _handleHorizontalSwipe,
            child: widget.child,
          );
        },
      ),
    );
  }
}