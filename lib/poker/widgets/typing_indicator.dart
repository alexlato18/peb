import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key, required this.text});
  final String text;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(widget.text),
        const SizedBox(width: 8),
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = _c.value;
            String dots = ".";
            if (t > 0.33 && t <= 0.66) dots = "..";
            if (t > 0.66) dots = "...";
            return Text(dots, style: const TextStyle(fontWeight: FontWeight.bold));
          },
        ),
      ],
    );
  }
}
