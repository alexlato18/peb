import 'dle_models.dart';

class LoldleEntry extends DleEntry {
  LoldleEntry({
    required this.id,
    required this.name,
    required this.releaseYear,
    required this.attackTypes,
    required this.lanes,
    required this.roles,
  });

  @override
  final String id;
  final String name;
  final int releaseYear;
  final List<String> attackTypes;
  final List<String> lanes;
  final List<String> roles;

  @override
  String get displayName => name;

  @override
  int get numericTarget => releaseYear;

  @override
  List<String> get textGroupA => attackTypes;

  @override
  List<String> get textGroupB => lanes;

  @override
  List<String> get textGroupC => roles;
}