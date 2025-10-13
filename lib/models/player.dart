/// Modèle pour un joueur
class Player {
  final String id;
  final String name;
  final String? color; // "red" ou "blue"
  final String? role; // "drawer" ou "guesser"
  final bool isHost; // Est le maître de la room

  // États pour gestion des phases automatiques
  final int challengesSent;  // Nombre de challenges envoyés
  final bool hasDrawn;       // A dessiné son challenge
  final bool hasGuessed;     // A deviné son challenge

  const Player({
    required this.id,
    required this.name,
    this.color,
    this.role,
    this.isHost = false,
    this.challengesSent = 0,
    this.hasDrawn = false,
    this.hasGuessed = false,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['name'] ?? '',
      color: json['color'],
      role: json['role'],
      isHost: json['isHost'] ?? false,
      challengesSent: json['challengesSent'] ?? 0,
      hasDrawn: json['hasDrawn'] ?? false,
      hasGuessed: json['hasGuessed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (color != null) 'color': color,
      if (role != null) 'role': role,
      'isHost': isHost,
      'challengesSent': challengesSent,
      'hasDrawn': hasDrawn,
      'hasGuessed': hasGuessed,
    };
  }

  Player copyWith({
    String? id,
    String? name,
    String? color,
    String? role,
    bool? isHost,
    int? challengesSent,
    bool? hasDrawn,
    bool? hasGuessed,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      role: role ?? this.role,
      isHost: isHost ?? this.isHost,
      challengesSent: challengesSent ?? this.challengesSent,
      hasDrawn: hasDrawn ?? this.hasDrawn,
      hasGuessed: hasGuessed ?? this.hasGuessed,
    );
  }

  @override
  String toString() {
    return 'Player(id: $id, name: $name, color: $color, role: $role, isHost: $isHost, challengesSent: $challengesSent, hasDrawn: $hasDrawn, hasGuessed: $hasGuessed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Player && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}