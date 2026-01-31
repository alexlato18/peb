class Profile {
  final String id;

  // Ya tenías:
  final String name;     // Firestore: name
  final String pinHASH;  // Firestore: pinHASH
  final String pinSalt;  // Firestore: pinSalt

  // Nuevos (existen en Firestore según tus capturas):
  final String role;       // Firestore: role  ("COMUN", "ADMIN", "ORGANIZADOR", "DIOS")
  final String? avatarURL; // Firestore: avatarURL
  final List<String> tags; // Firestore: tags
  final int counterTotal;  // Firestore: CounterTotal

  Profile({
    required this.id,
    required this.name,
    required this.pinHASH,
    required this.pinSalt,
    this.role = 'COMUN',
    this.avatarURL,
    this.tags = const [],
    this.counterTotal = 0,
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
    );
  }
}
