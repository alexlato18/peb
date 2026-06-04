import 'package:cloud_firestore/cloud_firestore.dart';

enum FishRarity { comun, pocoComun, epico, legendario }

enum FishModifier { fuego, hielo, arcoiris, electrico, toxico, fantasma }

class FishInstance {
  final String id;
  final String fishId;
  final bool shiny;
  final double? shinyHue;
  final List<String> modifiers;
  final String ownerProfileId;
  final String? senderProfileId;
  final String? customImageUrl;
  final Timestamp? obtainedAt;

  const FishInstance({
    required this.id,
    required this.fishId,
    required this.shiny,
    this.shinyHue,
    required this.modifiers,
    required this.ownerProfileId,
    this.senderProfileId,
    this.customImageUrl,
    this.obtainedAt,
  });

  FishInstance copyWith({
    String? id,
    String? fishId,
    bool? shiny,
    double? shinyHue,
    List<String>? modifiers,
    String? ownerProfileId,
    String? senderProfileId,
    String? customImageUrl,
    Timestamp? obtainedAt,
  }) {
    return FishInstance(
      id: id ?? this.id,
      fishId: fishId ?? this.fishId,
      shiny: shiny ?? this.shiny,
      shinyHue: shinyHue ?? this.shinyHue,
      modifiers: modifiers ?? this.modifiers,
      ownerProfileId: ownerProfileId ?? this.ownerProfileId,
      senderProfileId: senderProfileId ?? this.senderProfileId,
      customImageUrl: customImageUrl ?? this.customImageUrl,
      obtainedAt: obtainedAt ?? this.obtainedAt,
    );
  }

  factory FishInstance.fromMap(String id, Map<String, dynamic> data) {
    return FishInstance(
      id: id,
      fishId: data['fishId'] ?? '',
      shiny: data['shiny'] ?? false,
      shinyHue: (data['shinyHue'] as num?)?.toDouble(),
      modifiers: List<String>.from(data['modifiers'] ?? const []),
      ownerProfileId: data['ownerProfileId'] ?? '',
      senderProfileId: data['senderProfileId'],
      customImageUrl: data['customImageUrl'],
      obtainedAt: data['obtainedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fishId': fishId,
      'shiny': shiny,
      'shinyHue': shinyHue,
      'modifiers': modifiers,
      'ownerProfileId': ownerProfileId,
      'senderProfileId': senderProfileId,
      'customImageUrl': customImageUrl,
      'obtainedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toPendingMap() {
    return {
      'id': id,
      'fishId': fishId,
      'shiny': shiny,
      'shinyHue': shinyHue,
      'modifiers': modifiers,
      'ownerProfileId': ownerProfileId,
      'senderProfileId': senderProfileId,
      'customImageUrl': customImageUrl,
    };
  }

  factory FishInstance.fromPendingMap(Map<String, dynamic> data) {
    return FishInstance(
      id: data['id'] ?? '',
      fishId: data['fishId'] ?? '',
      shiny: data['shiny'] ?? false,
      shinyHue: (data['shinyHue'] as num?)?.toDouble(),
      modifiers: List<String>.from(data['modifiers'] ?? const []),
      ownerProfileId: data['ownerProfileId'] ?? '',
      senderProfileId: data['senderProfileId'],
      customImageUrl: data['customImageUrl'],
      obtainedAt: Timestamp.now(),
    );
  }
}