import 'dle_models.dart';

class PokedleEntry extends DleEntry {
  PokedleEntry({
    required this.id,
    required this.name,
    required this.generation,
    required this.types,
    required this.evolutionStage,
    required this.colors,
  });

  @override
  final String id;
  final String name;
  final int generation;
  final List<String> types;
  final String evolutionStage;
  final List<String> colors;

  @override
  String get displayName => name;

  @override
  int get numericTarget => generation;

  @override
  List<String> get textGroupA => types;

  @override
  List<String> get textGroupB => [evolutionStage];

  @override
  List<String> get textGroupC => colors;
}