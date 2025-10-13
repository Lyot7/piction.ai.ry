import 'player.dart';

/// Modèle pour une session de jeu
class GameSession {
  /// Alias pour la date de début, utilisé par la logique de transition
  DateTime? get startTime => startedAt;
  final String id;
  final String status; // "lobby", "challenge", "playing", "finished"
  final List<Player> players;
  final Map<String, int> teamScores; // Scores par équipe: {"red": 100, "blue": 100}
  final int currentTurn; // Index du challenge actuel (0-based)
  final DateTime? createdAt;
  final DateTime? startedAt;

  const GameSession({
    required this.id,
    required this.status,
    required this.players,
    this.teamScores = const {"red": 100, "blue": 100},
    this.currentTurn = 0,
    this.createdAt,
    this.startedAt,
  });

  factory GameSession.fromJson(Map<String, dynamic> json) {
    // Parser les scores d'équipe
    Map<String, int> scores = {"red": 100, "blue": 100};
    if (json['teamScores'] != null && json['teamScores'] is Map) {
      final Map teamScoresJson = json['teamScores'];
      scores = {
        'red': teamScoresJson['red'] ?? 100,
        'blue': teamScoresJson['blue'] ?? 100,
      };
    }

    // Parser les joueurs depuis le format standard OU depuis red_team/blue_team
    List<Player> players = [];

    if (json['players'] != null) {
      // Format standard avec champ "players"
      players = (json['players'] as List<dynamic>)
          .map((playerJson) => Player.fromJson(playerJson))
          .toList();
    } else if (json['red_team'] != null || json['blue_team'] != null) {
      // Format alternatif avec red_team/blue_team (liste d'IDs seulement)
      // Note: Les détails complets des joueurs seront ajoutés par getGameSession()
      final redTeamIds = (json['red_team'] as List<dynamic>?) ?? [];
      final blueTeamIds = (json['blue_team'] as List<dynamic>?) ?? [];

      // Créer des objets Player minimaux avec juste l'ID et la couleur
      // Ces Players seront enrichis plus tard avec les vraies données
      for (final playerId in redTeamIds) {
        players.add(Player(
          id: playerId.toString(),
          name: '', // Sera rempli par enrichissement
          color: 'red',
        ));
      }
      for (final playerId in blueTeamIds) {
        players.add(Player(
          id: playerId.toString(),
          name: '', // Sera rempli par enrichissement
          color: 'blue',
        ));
      }
    }

    return GameSession(
      id: (json['id'] ?? json['_id'] ?? json['gameSessionId'] ?? '').toString(),
      status: json['status'] ?? 'lobby',
      players: players,
      teamScores: scores,
      currentTurn: json['currentTurn'] ?? json['current_turn'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : json['created_at'] != null
              ? DateTime.tryParse(json['created_at'])
              : null,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'])
          : json['started_at'] != null
              ? DateTime.tryParse(json['started_at'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'players': players.map((player) => player.toJson()).toList(),
      'teamScores': teamScores,
      'currentTurn': currentTurn,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    };
  }

  GameSession copyWith({
    String? id,
    String? status,
    List<Player>? players,
    Map<String, int>? teamScores,
    int? currentTurn,
    DateTime? createdAt,
    DateTime? startedAt,
  }) {
    return GameSession(
      id: id ?? this.id,
      status: status ?? this.status,
      players: players ?? this.players,
      teamScores: teamScores ?? this.teamScores,
      currentTurn: currentTurn ?? this.currentTurn,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  /// Vérifie si la session est prête à démarrer (4 joueurs, 2 par équipe)
  bool get isReadyToStart {
    if (players.length != 4) return false;
    final redCount = players.where((p) => p.color == 'red').length;
    final blueCount = players.where((p) => p.color == 'blue').length;
    return redCount == 2 && blueCount == 2;
  }

  /// Vérifie si la session est en cours
  bool get isActive => ['challenge', 'playing'].contains(status);

  /// Vérifie si la session est terminée
  bool get isFinished => status == 'finished';

  /// Retourne le score d'une équipe
  int getTeamScore(String teamColor) => teamScores[teamColor] ?? 100;

  /// Retourne les joueurs d'une équipe
  List<Player> getTeamPlayers(String teamColor) =>
      players.where((p) => p.color == teamColor).toList();

  /// Retourne le dessinateur actuel d'une équipe
  Player? getTeamDrawer(String teamColor) =>
      players.where((p) => p.color == teamColor && p.isDrawer).firstOrNull;

  /// Retourne le devineur actuel d'une équipe
  Player? getTeamGuesser(String teamColor) =>
      players.where((p) => p.color == teamColor && p.isGuesser).firstOrNull;

  @override
  String toString() {
    return 'GameSession(id: $id, status: $status, players: ${players.length}, turn: $currentTurn, scores: $teamScores)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameSession && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
