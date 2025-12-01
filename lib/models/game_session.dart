import 'player.dart';
import '../utils/logger.dart';

/// Modèle pour une session de jeu
class GameSession {
  /// Alias pour la date de début, utilisé par la logique de transition
  DateTime? get startTime => startedAt;
  final String id;
  final String status; // "lobby", "challenge", "playing", "finished"
  final List<Player> players;
  final Map<String, int> teamScores; // Scores par équipe: {"red": 100, "blue": 100}
  final int currentTurn; // Index du challenge actuel (0-based)
  final String? gamePhase; // "drawing" ou "guessing" (uniquement en "playing")
  final DateTime? createdAt;
  final DateTime? startedAt;
  final String? hostId; // ID du joueur qui a créé la room (host)

  const GameSession({
    required this.id,
    required this.status,
    required this.players,
    this.teamScores = const {"red": 100, "blue": 100},
    this.currentTurn = 0,
    this.gamePhase,
    this.createdAt,
    this.startedAt,
    this.hostId,
  });

  factory GameSession.fromJson(Map<String, dynamic> json) {
    AppLogger.log('[GameSession] Parsing raw JSON keys: ${json.keys.toList()}');
    AppLogger.log('[GameSession] red_team type: ${json['red_team']?.runtimeType}');
    AppLogger.log('[GameSession] blue_team type: ${json['blue_team']?.runtimeType}');
    AppLogger.log('[GameSession] players type: ${json['players']?.runtimeType}');

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
    AppLogger.log('[GameSession] Starting player parsing...');

    if (json['players'] != null) {
      // Format standard avec champ "players"
      players = (json['players'] as List<dynamic>)
          .map((playerJson) {
            // Support pour format avec player_id au lieu de id
            if (playerJson is Map<String, dynamic> && playerJson['player_id'] != null && playerJson['id'] == null) {
              playerJson = {...playerJson, 'id': playerJson['player_id']};
            }
            return Player.fromJson(playerJson);
          })
          .toList();
    } else if (json['red_team'] != null || json['blue_team'] != null) {
      // Format alternatif avec red_team/blue_team
      final redTeam = json['red_team'] as List<dynamic>? ?? [];
      final blueTeam = json['blue_team'] as List<dynamic>? ?? [];

      AppLogger.log('[GameSession] red_team length: ${redTeam.length}');
      AppLogger.log('[GameSession] blue_team length: ${blueTeam.length}');

      // Parser red_team (peut être liste d'IDs ou liste d'objets)
      for (int i = 0; i < redTeam.length; i++) {
        final teamMember = redTeam[i];
        AppLogger.log('[GameSession] red_team[$i] type: ${teamMember.runtimeType}');

        if (teamMember is Map<String, dynamic>) {
          // Format objet avec détails
          AppLogger.log('[GameSession] red_team[$i] keys: ${teamMember.keys.toList()}');
          AppLogger.log('[GameSession] red_team[$i] challenges_sent: ${teamMember['challenges_sent']}');

          final playerData = {...teamMember};
          if (playerData['player_id'] != null && playerData['id'] == null) {
            playerData['id'] = playerData['player_id'];
          }
          playerData['color'] = 'red';
          final player = Player.fromJson(playerData);
          AppLogger.log('[GameSession] Parsed red player: ${player.name}, challengesSent=${player.challengesSent}');
          players.add(player);
        } else {
          // Format ID simple
          AppLogger.log('[GameSession] red_team[$i] is simple ID: $teamMember');
          players.add(Player(
            id: teamMember.toString(),
            name: '', // Sera rempli par enrichissement
            color: 'red',
          ));
        }
      }

      // Parser blue_team
      for (int i = 0; i < blueTeam.length; i++) {
        final teamMember = blueTeam[i];
        AppLogger.log('[GameSession] blue_team[$i] type: ${teamMember.runtimeType}');

        if (teamMember is Map<String, dynamic>) {
          // Format objet avec détails
          AppLogger.log('[GameSession] blue_team[$i] keys: ${teamMember.keys.toList()}');
          AppLogger.log('[GameSession] blue_team[$i] challenges_sent: ${teamMember['challenges_sent']}');

          final playerData = {...teamMember};
          if (playerData['player_id'] != null && playerData['id'] == null) {
            playerData['id'] = playerData['player_id'];
          }
          playerData['color'] = 'blue';
          final player = Player.fromJson(playerData);
          AppLogger.log('[GameSession] Parsed blue player: ${player.name}, challengesSent=${player.challengesSent}');
          players.add(player);
        } else {
          // Format ID simple
          AppLogger.log('[GameSession] blue_team[$i] is simple ID: $teamMember');
          players.add(Player(
            id: teamMember.toString(),
            name: '', // Sera rempli par enrichissement
            color: 'blue',
          ));
        }
      }
    }

    // ⚡ CALCUL DES CHALLENGES ENVOYÉS
    // Le backend ne renvoie pas challengesSent directement
    // Il faut compter dans la liste "challenges" combien de fois chaque joueur est "challenger_id"
    if (json['challenges'] != null && json['challenges'] is List) {
      final challenges = json['challenges'] as List<dynamic>;
      AppLogger.log('[GameSession] 🎯 Calculating challengesSent from ${challenges.length} challenges');

      // Compter les challenges par joueur
      final Map<String, int> challengesCount = {};
      for (final challenge in challenges) {
        if (challenge is Map<String, dynamic>) {
          final challengerId = challenge['challenger_id']?.toString();
          if (challengerId != null) {
            challengesCount[challengerId] = (challengesCount[challengerId] ?? 0) + 1;
          }
        }
      }

      AppLogger.log('[GameSession] 🎯 Challenges count by player: $challengesCount');

      // Mettre à jour les joueurs avec le bon nombre de challenges
      players = players.map((p) {
        final count = challengesCount[p.id] ?? 0;
        AppLogger.log('[GameSession] 🎯 Player ${p.id} (${p.name}): $count challenges');
        return p.copyWith(challengesSent: count);
      }).toList();
    }

    AppLogger.log('[GameSession] Total players parsed: ${players.length}');
    for (final p in players) {
      AppLogger.log('[GameSession] Player: ${p.name} (${p.id}), color=${p.color}, challengesSent=${p.challengesSent}');
    }

    // ✅ FIX: Parser le hostId depuis le backend (plusieurs noms possibles)
    final hostId = (json['host_id'] ?? json['hostId'] ?? json['created_by'] ?? json['createdBy'])?.toString();
    AppLogger.log('[GameSession] 👑 Host ID from backend: $hostId');

    return GameSession(
      id: (json['id'] ?? json['_id'] ?? json['gameSessionId'] ?? '').toString(),
      status: json['status'] ?? 'lobby',
      players: players,
      teamScores: scores,
      currentTurn: json['currentTurn'] ?? json['current_turn'] ?? 0,
      gamePhase: json['gamePhase'] ?? json['game_phase'],
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
      hostId: hostId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'players': players.map((player) => player.toJson()).toList(),
      'teamScores': teamScores,
      'currentTurn': currentTurn,
      if (gamePhase != null) 'gamePhase': gamePhase,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
      if (hostId != null) 'hostId': hostId,
    };
  }

  GameSession copyWith({
    String? id,
    String? status,
    List<Player>? players,
    Map<String, int>? teamScores,
    int? currentTurn,
    String? gamePhase,
    DateTime? createdAt,
    DateTime? startedAt,
    String? hostId,
  }) {
    return GameSession(
      id: id ?? this.id,
      status: status ?? this.status,
      players: players ?? this.players,
      teamScores: teamScores ?? this.teamScores,
      currentTurn: currentTurn ?? this.currentTurn,
      gamePhase: gamePhase ?? this.gamePhase,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      hostId: hostId ?? this.hostId,
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

  /// ✅ SOLID: Single Source of Truth pour le host
  /// Vérifie si un joueur est le host de la session
  bool isPlayerHost(String? playerId) {
    if (playerId == null || hostId == null) return false;
    return playerId == hostId;
  }

  /// Retourne le joueur host de la session
  Player? get host => hostId != null
      ? players.where((p) => p.id == hostId).firstOrNull
      : null;

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
