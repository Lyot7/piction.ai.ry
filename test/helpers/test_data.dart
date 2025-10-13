import 'package:piction_ai_ry/models/player.dart';
import 'package:piction_ai_ry/models/game_session.dart';
import 'package:piction_ai_ry/models/challenge.dart';

/// Test data fixtures for unit and integration tests
class TestData {
  // ===== PLAYERS =====

  static Player player1Host({
    String? id,
    String? name,
    String? color,
    String? role,
    bool? isHost,
  }) {
    return Player(
      id: id ?? 'player-1-id',
      name: name ?? 'Alice',
      color: color ?? 'red',
      role: role ?? 'drawer',
      isHost: isHost ?? true,
    );
  }

  static Player player2({
    String? id,
    String? name,
    String? color,
    String? role,
  }) {
    return Player(
      id: id ?? 'player-2-id',
      name: name ?? 'Bob',
      color: color ?? 'red',
      role: role ?? 'guesser',
      isHost: false,
    );
  }

  static Player player3({
    String? id,
    String? name,
    String? color,
    String? role,
  }) {
    return Player(
      id: id ?? 'player-3-id',
      name: name ?? 'Charlie',
      color: color ?? 'blue',
      role: role ?? 'drawer',
      isHost: false,
    );
  }

  static Player player4({
    String? id,
    String? name,
    String? color,
    String? role,
  }) {
    return Player(
      id: id ?? 'player-4-id',
      name: name ?? 'Diana',
      color: color ?? 'blue',
      role: role ?? 'guesser',
      isHost: false,
    );
  }

  // ===== GAME SESSIONS =====

  /// Session vide (juste créée)
  static GameSession emptySession({String? id}) {
    return GameSession(
      id: id ?? 'session-empty',
      status: 'lobby',
      players: [],
      createdAt: DateTime.now(),
    );
  }

  /// Session avec uniquement le host
  static GameSession sessionWithHost({String? id, Player? host}) {
    final hostPlayer = host ?? player1Host();
    return GameSession(
      id: id ?? 'session-with-host',
      status: 'lobby',
      players: [hostPlayer],
      createdAt: DateTime.now(),
    );
  }

  /// Session avec 2 joueurs (1 par équipe)
  static GameSession sessionWith2Players({String? id}) {
    return GameSession(
      id: id ?? 'session-2-players',
      status: 'lobby',
      players: [
        player1Host(),
        player3(),
      ],
      createdAt: DateTime.now(),
    );
  }

  /// Session avec 4 joueurs (prête à démarrer)
  static GameSession sessionWith4Players({String? id, String? status}) {
    return GameSession(
      id: id ?? 'session-4-players',
      status: status ?? 'lobby',
      players: [
        player1Host(),
        player2(),
        player3(),
        player4(),
      ],
      createdAt: DateTime.now(),
    );
  }

  /// Session en cours de jeu
  static GameSession sessionInProgress({String? id, int? turn}) {
    return GameSession(
      id: id ?? 'session-in-progress',
      status: 'playing',
      players: [
        player1Host(),
        player2(),
        player3(),
        player4(),
      ],
      currentTurn: turn ?? 1,
      startedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  // ===== CHALLENGES =====

  static Challenge challenge1({
    String? id,
    String? gameSessionId,
    String? drawerId,
    String? guesserId,
  }) {
    return Challenge(
      id: id ?? 'challenge-1-id',
      gameSessionId: gameSessionId ?? 'session-test',
      article1: 'Un',
      input1: 'chat',
      preposition: 'Sur',
      article2: 'Une',
      input2: 'lune',
      forbiddenWords: ['félin', 'nuit', 'lunaire'],
      imageUrl: 'https://example.com/image1.png',
      currentPhase: 'resolved',
      isResolved: true,
      drawerId: drawerId ?? 'player-1-id',
      guesserId: guesserId ?? 'player-2-id',
      createdAt: DateTime.now(),
    );
  }

  static Challenge challenge2({
    String? id,
    String? gameSessionId,
    String? drawerId,
    String? guesserId,
  }) {
    return Challenge(
      id: id ?? 'challenge-2-id',
      gameSessionId: gameSessionId ?? 'session-test',
      article1: 'Un',
      input1: 'robot',
      preposition: 'Dans',
      article2: 'Une',
      input2: 'plage',
      forbiddenWords: ['androïde', 'sable', 'océan'],
      imageUrl: 'https://example.com/image2.png',
      currentPhase: 'resolved',
      isResolved: true,
      drawerId: drawerId ?? 'player-3-id',
      guesserId: guesserId ?? 'player-4-id',
      createdAt: DateTime.now(),
    );
  }

  static Challenge challenge3({
    String? id,
    String? gameSessionId,
    String? drawerId,
    String? guesserId,
  }) {
    return Challenge(
      id: id ?? 'challenge-3-id',
      gameSessionId: gameSessionId ?? 'session-test',
      article1: 'Un',
      input1: 'dragon',
      preposition: 'Sur',
      article2: 'Un',
      input2: 'château',
      forbiddenWords: ['feu', 'médiéval', 'chevalier'],
      currentPhase: 'waiting_prompt',
      isResolved: false,
      drawerId: drawerId ?? 'player-1-id',
      guesserId: guesserId ?? 'player-2-id',
      createdAt: DateTime.now(),
    );
  }

  // ===== API RESPONSES (JSON) =====

  /// Response JSON pour une session vide
  static Map<String, dynamic> emptySessionJson({String? id}) {
    return {
      'id': id ?? 'session-empty',
      'status': 'lobby',
      'players': [],
      'teamScores': {'red': 100, 'blue': 100},
      'currentTurn': 0,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  /// Response JSON pour une session avec host
  static Map<String, dynamic> sessionWithHostJson({String? id, String? playerId}) {
    return {
      'id': id ?? 'session-with-host',
      'status': 'lobby',
      'players': [
        {
          'id': playerId ?? 'player-1-id',
          'name': 'Alice',
          'color': 'red',
          'role': 'drawer',
          'isHost': true,
          'score': 0,
        }
      ],
      'teamScores': {'red': 100, 'blue': 100},
      'currentTurn': 0,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  /// Response JSON pour une session avec 4 joueurs
  static Map<String, dynamic> sessionWith4PlayersJson({String? id}) {
    return {
      'id': id ?? 'session-4-players',
      'status': 'lobby',
      'players': [
        {
          'id': 'player-1-id',
          'name': 'Alice',
          'color': 'red',
          'role': 'drawer',
          'isHost': true,
          'score': 0,
        },
        {
          'id': 'player-2-id',
          'name': 'Bob',
          'color': 'red',
          'role': 'guesser',
          'isHost': false,
          'score': 0,
        },
        {
          'id': 'player-3-id',
          'name': 'Charlie',
          'color': 'blue',
          'role': 'drawer',
          'isHost': false,
          'score': 0,
        },
        {
          'id': 'player-4-id',
          'name': 'Diana',
          'color': 'blue',
          'role': 'guesser',
          'isHost': false,
          'score': 0,
        },
      ],
      'teamScores': {'red': 100, 'blue': 100},
      'currentTurn': 0,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  /// Response JSON pour un join réussi
  static Map<String, dynamic> joinSuccessJson({
    required String playerId,
    String? playerName,
    String? color,
  }) {
    return {
      'success': true,
      'player': {
        'id': playerId,
        'name': playerName ?? 'Test Player',
        'color': color ?? 'red',
        'role': 'drawer',
        'isHost': false,
        'score': 0,
      },
    };
  }

  // ===== ERROR RESPONSES =====

  static Map<String, dynamic> errorResponse({
    required String message,
    int? statusCode,
  }) {
    return {
      'error': message,
      'statusCode': statusCode ?? 400,
    };
  }

  static Map<String, dynamic> sessionNotFoundError() {
    return errorResponse(
      message: 'Game session not found',
      statusCode: 404,
    );
  }

  static Map<String, dynamic> sessionFullError() {
    return errorResponse(
      message: 'Game session is full (max 4 players)',
      statusCode: 400,
    );
  }

  static Map<String, dynamic> teamFullError() {
    return errorResponse(
      message: 'This team is already full',
      statusCode: 400,
    );
  }
}
