/// Modèle pour un joueur
class Player {
  final String id;
  final String name;
  final String? color; // "red" ou "blue"
  final String? role; // "drawer" ou "guesser"

  const Player({
    required this.id,
    required this.name,
    this.color,
    this.role,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      color: json['color'],
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (color != null) 'color': color,
      if (role != null) 'role': role,
    };
  }

  Player copyWith({
    String? id,
    String? name,
    String? color,
    String? role,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      role: role ?? this.role,
    );
  }

  @override
  String toString() {
    return 'Player(id: $id, name: $name, color: $color, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Player && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
