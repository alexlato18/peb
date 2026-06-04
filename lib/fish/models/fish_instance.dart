import 'package:cloud_firestore/cloud_firestore.dart';

class FishInstance {
  final String id;

  final String fishId;

  final bool shiny;

  final List<String> modifiers;

  final Timestamp obtainedAt;

  const FishInstance({
    required this.id,
    required this.fishId,
    required this.shiny,
    required this.modifiers,
    required this.obtainedAt,
  });

  factory FishInstance.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FishInstance(
      id: id,
      fishId: data['fishId'] ?? '',
      shiny: data['shiny'] ?? false,
      modifiers: List<String>.from(
        data['modifiers'] ?? const [],
      ),
      obtainedAt:
          data['obtainedAt'] as Timestamp? ??
          Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fishId': fishId,
      'shiny': shiny,
      'modifiers': modifiers,
      'obtainedAt': obtainedAt,
    };
  }
}