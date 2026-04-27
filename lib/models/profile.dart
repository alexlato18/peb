class Profile {
  final String id;

  final String name;
  final String pinHASH;
  final String pinSalt;

  final String role;
  final String? avatarURL;
  final List<String> tags;
  final int counterTotal;

  // null = nunca configurado, [] = ocultar todos, [tags] = mostrar esos
  final List<String>? visibleTags;

  Profile({
    required this.id,
    required this.name,
    required this.pinHASH,
    required this.pinSalt,
    this.role = 'COMUN',
    this.avatarURL,
    this.tags = const [],
    this.counterTotal = 0,
    this.visibleTags,
  });

  factory Profile.fromMap(String id, Map<String, dynamic> data) {
    return Profile(
      id: id,
      name: (data['name'] ?? '') as String,
      pinHASH: (data['pinHASH'] ?? '') as String,
      pinSalt: (data['pinSalt'] ?? '') as String,
      role: (data['role'] ?? 'COMUN') as String,
      avatarURL: data['avatarURL'] as String?,
      tags: List<String>.from(data['tags'] ?? const []),
      counterTotal: (data['CounterTotal'] as num?)?.toInt() ?? 0,
      visibleTags: data['visibleTags'] != null
          ? List<String>.from(data['visibleTags'])
          : null,
    );
  }
}