import 'player.dart';

/// Modèle pour une session de jeu
class GameSession {
  final String id;
  final String status; // "lobby", "challenge", "drawing", "guessing", "finished"
  final List<Player> players;
  final DateTime? createdAt;
  final DateTime? startedAt;

  const GameSession({
    required this.id,
    required this.status,
    required this.players,
    this.createdAt,
    this.startedAt,
  });

  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      id: json['id'] ?? json['_id'] ?? json['gameSessionId'] ?? '',
      status: json['status'] ?? 'lobby',
      players: (json['players'] as List<dynamic>?)
          ?.map((playerJson) => Player.fromJson(playerJson))
          .toList() ?? [],
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt']) 
          : null,
      startedAt: json['startedAt'] != null 
          ? DateTime.tryParse(json['startedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'players': players.map((player) => player.toJson()).toList(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    };
  }

  GameSession copyWith({
    String? id,
    String? status,
    List<Player>? players,
    DateTime? createdAt,
    DateTime? startedAt,
  }) {
    return GameSession(
      id: id ?? this.id,
      status: status ?? this.status,
      players: players ?? this.players,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  /// Vérifie si la session est prête à démarrer (4 joueurs)
  bool get isReadyToStart => players.length == 4;

  /// Vérifie si la session est en cours
  bool get isActive => ['challenge', 'drawing', 'guessing'].contains(status);

  /// Vérifie si la session est terminée
  bool get isFinished => status == 'finished';

  @override
  String toString() {
    return 'GameSession(id: $id, status: $status, players: ${players.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameSession && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
