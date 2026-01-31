import 'package:flutter/material.dart';
import '../data/tag_style_repository.dart';
import '../widgets/tag_chip.dart';

class TagStyleEditorSheet extends StatefulWidget {
  const TagStyleEditorSheet({
    super.key,
    required this.tag,
    required this.initial,
    required this.onSave,
    this.onReset,
  });

  final String tag;
  final TagStyle initial;
  final Future<void> Function(TagStyle style) onSave;
  final Future<void> Function()? onReset;

  @override
  State<TagStyleEditorSheet> createState() => _TagStyleEditorSheetState();
}

class _TagStyleEditorSheetState extends State<TagStyleEditorSheet> {
  late Color _bg;
  late Color _text;
  late bool _holo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bg = widget.initial.bg;
    _text = widget.initial.text;
    _holo = widget.initial.holo;
  }

  @override
  Widget build(BuildContext context) {
    final preview = TagStyle(bg: _bg, text: _text, holo: _holo);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: AbsorbPointer(
          absorbing: _busy,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Estilo: ${widget.tag}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (widget.onReset != null)
                    TextButton(
                      onPressed: _busy ? null : _reset,
                      child: const Text('Reset'),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  const Text('Preview:'),
                  const SizedBox(width: 10),
                  TagChip(label: widget.tag, style: preview),
                ],
              ),

              const SizedBox(height: 14),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _holo,
                onChanged: (v) => setState(() => _holo = v),
                title: const Text('Holográfico'),
                subtitle: const Text('Fondo holo animado + texto dorado'),
              ),

              const SizedBox(height: 10),

              _ColorRow(
                label: 'Fondo',
                color: _bg,
                enabled: !_holo,
                onPick: () async {
                  final c = await _pickColor(context, _bg);
                  if (c != null) setState(() => _bg = c);
                },
              ),
              const SizedBox(height: 10),
              _ColorRow(
                label: 'Texto',
                color: _text,
                enabled: !_holo,
                onPick: () async {
                  final c = await _pickColor(context, _text);
                  if (c != null) setState(() => _text = c);
                },
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar estilo'),
                ),
              ),

              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.onSave(TagStyle(bg: _bg, text: _text, holo: _holo));
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    setState(() => _busy = true);
    try {
      await widget.onReset?.call();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Color?> _pickColor(BuildContext context, Color current) async {
    // Picker simple: paleta rápida + input hex opcional
    final ctrl = TextEditingController(
      text: '#${current.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
    );
    Color temp = current;

    return showDialog<Color?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elegir color'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _palette.map((c) {
                final selected = c.value == temp.value;
                return InkWell(
                  onTap: () {
                    temp = c;
                    ctrl.text = '#${c.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
                    (ctx as Element).markNeedsBuild();
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        width: selected ? 3 : 1,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Hex (#AARRGGBB o #RRGGBB)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                final parsed = _tryParseHex(v);
                if (parsed != null) temp = parsed;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(temp),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Color? _tryParseHex(String input) {
    var h = input.trim().toUpperCase();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(v);
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.color,
    required this.onPick,
    required this.enabled,
  });

  final String label;
  final Color color;
  final VoidCallback onPick;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        Opacity(
          opacity: enabled ? 1 : 0.45,
          child: OutlinedButton.icon(
            onPressed: enabled ? onPick : null,
            icon: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black12),
              ),
            ),
            label: Text(
              '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
            ),
          ),
        ),
      ],
    );
  }
}

const _palette = <Color>[
  Color(0xFF111111),
  Color(0xFFFFFFFF),
  Color(0xFFFF3B30),
  Color(0xFFFF9500),
  Color(0xFFFFCC00),
  Color(0xFF34C759),
  Color(0xFF00C7BE),
  Color(0xFF007AFF),
  Color(0xFF5856D6),
  Color(0xFFAF52DE),
  Color(0xFFFF2D55),
  Color(0xFF8E8E93),
];
