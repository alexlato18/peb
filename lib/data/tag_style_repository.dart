import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TagStyle {
  final Color bg;
  final Color text;
  final bool holo;

  const TagStyle({
    required this.bg,
    required this.text,
    required this.holo,
  });

  static const TagStyle fallback = TagStyle(
    bg: Color(0xFFE0E0E0),
    text: Color(0xFF111111),
    holo: false,
  );

  Map<String, dynamic> toMap() => {
        'bg': _colorToHex(bg),
        'text': _colorToHex(text),
        'holo': holo,
      };

  factory TagStyle.fromMap(Map<String, dynamic> data) {
    return TagStyle(
      bg: _hexToColor((data['bg'] ?? '#FFE0E0E0') as String),
      text: _hexToColor((data['text'] ?? '#FF111111') as String),
      holo: (data['holo'] as bool?) ?? false,
    );
  }

  static String _colorToHex(Color c) {
    return '#${c.value.toRadixString(16).padLeft(8, '0').toUpperCase()}'; // #AARRGGBB
  }

  static Color _hexToColor(String hex) {
    var h = hex.trim().toUpperCase();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h'; // assume alpha FF
    final value = int.tryParse(h, radix: 16) ?? 0xFFE0E0E0;
    return Color(value);
  }
}

class TagStyleRepository {
  TagStyleRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('groups').doc('peb').collection('config').doc('tags');

  Stream<Map<String, TagStyle>> watchStyles() {
    return _doc.snapshots().map((snap) {
      final data = snap.data() ?? const {};
      final stylesRaw = (data['styles'] as Map?)?.cast<String, dynamic>() ?? const {};
      final out = <String, TagStyle>{};
      stylesRaw.forEach((tag, v) {
        if (v is Map) {
          out[tag] = TagStyle.fromMap(v.cast<String, dynamic>());
        }
      });
      return out;
    });
  }
  Stream<List<String>> watchAllTags() {
    return _doc.snapshots().map((snap) {
      final data = snap.data() ?? const {};
      final raw = (data['allTags'] as List?)?.cast<String>() ?? const <String>[];
      final out = raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return out;
    }).handleError((_) => <String>[]);
  }

  Future<void> addGlobalTag(String tag) async {
    final clean = tag.trim();
    if (clean.isEmpty) return;

    await _doc.set({
      'allTags': FieldValue.arrayUnion([clean]),
    }, SetOptions(merge: true));
  }

  Future<void> removeGlobalTag(String tag) async {
    final clean = tag.trim();
    if (clean.isEmpty) return;

    await _doc.set({
      'allTags': FieldValue.arrayRemove([clean]),
    }, SetOptions(merge: true));
  }

  Future<TagStyle> getStyleOnce(String tag) async {
    final snap = await _doc.get();
    final data = snap.data() ?? const {};
    final stylesRaw = (data['styles'] as Map?)?.cast<String, dynamic>() ?? const {};
    final v = stylesRaw[tag];
    if (v is Map) return TagStyle.fromMap(v.cast<String, dynamic>());
    return TagStyle.fallback;
  }

  Future<void> upsertStyle(String tag, TagStyle style) async {
    await _doc.set({
      'styles': {
        tag: style.toMap(),
      }
    }, SetOptions(merge: true));
  }

  Future<void> deleteStyle(String tag) async {
    await _doc.set({
      'styles': {tag: FieldValue.delete()}
    }, SetOptions(merge: true));
  }
}
