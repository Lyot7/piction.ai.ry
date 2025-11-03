import 'package:piction_ai_ry/models/game_session.dart';
import 'package:piction_ai_ry/models/player.dart';
import 'test_data.dart';

/// Mock ApiService pour les tests
/// Simule les réponses API sans faire de vrais appels réseau
class MockApiService {
  // État du mock
  final Map<String, GameSession> _sessions = {};
  final Map<String, Player> _players = {};
  bool _shouldFail = false;
  String? _errorMessage;
  int _callCount = 0;
  Duration? _simulatedDelay;

  // Getters pour les tests
  int get callCount => _callCount;
  Map<String, GameSession> get sessions => Map.unmodifiable(_sessions);
  Map<String, Player> get players => Map.unmodifiable(_players);

  /// Configure le mock pour échouer
  void setShouldFail(bool shouldFail, [String? errorMessage]) {
    _shouldFail = shouldFail;
    _errorMessage = errorMessage ?? 'Mock API error';
  }

  /// Configure un délai simulé pour les appels API
  void setSimulatedDelay(Duration delay) {
    _simulatedDelay = delay;
  }

  /// Reset l'état du mock
  void reset() {
    _sessions.clear();
    _players.clear();
    _shouldFail = false;
    _errorMessage = null;
    _callCount = 0;
    _simulatedDelay = null;
  }

  /// Pré-remplir le mock avec des données
  void seedData({
    List<GameSession>? sessions,
    List<Player>? players,
  }) {
    if (sessions != null) {
      for (final session in sessions) {
        _sessions[session.id] = session;
      }
    }
    if (players != null) {
      for (final player in players) {
        _players[player.id] = player;
      }
    }
  }

  // ===== API METHODS =====

  /// Créer une nouvelle session
  Future<GameSession> createGameSession() async {
    _callCount++;
    await _simulateDelay();
    if (_shouldFail) throw Exception(_errorMessage);

    final session = TestData.emptySession(
      id: 'mock-session-${DateTime.now().millisecondsSinceEpoch}',
    );
    _sessions[session.id] = session;
    return session;
  }

  /// Récupérer une session par ID
  Future<GameSession> getGameSession(String sessionId) async {
    _callCount++;
    await _simulateDelay();
    if (_shouldFail) throw Exception(_errorMessage);

    final session = _sessions[sessionId];
    if (session == null) {
      throw Exception('Game session not found');
    }
    return session;
  }

  /// Rejoindre une session
  Future<Player> joinGameSession(String sessionId, String teamColor) async {
    _callCount++;
    await _simulateDelay();
    if (_shouldFail) throw Exception(_errorMessage);

    final session = _sessions[sessionId];
    if (session == null) {
      throw Exception('Game session not found');
    }

    // Vérifier que l'équipe n'est pas pleine
    final teamPlayers = session.players.where((p) => p.color == teamColor).toList();
    if (teamPlayers.length >= 2) {
      throw Exception('This team is already full');
    }

    // Créer un nouveau joueur
    final player = Player(
      id: 'mock-player-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Player ${session.players.length + 1}',
      color: teamColor,
      role: teamPlayers.isEmpty ? 'drawer' : 'guesser',
      isHost: session.players.isEmpty,
    );

    // Ajouter le joueur à la session
    final updatedPlayers = [...session.players, player];
    final updatedSession = session.copyWith(players: updatedPlayers);
    _sessions[sessionId] = updatedSession;
    _players[player.id] = player;

    return player;
  }

  /// Changer d'équipe
  Future<void> switchTeam(String sessionId, String playerId, String newTeamColor) async {
    _callCount++;
    await _simulateDelay();
    if (_shouldFail) throw Exception(_errorMessage);

    final session = _sessions[sessionId];
    if (session == null) {
      throw Exception('Game session not found');
    }

    // Trouver le joueur
    final playerIndex = session.players.indexWhere((p) => p.id == playerId);
    if (playerIndex == -1) {
      throw Exception('Player not found in session');
    }

    // Vérifier que la nouvelle équipe n'est pas pleine
    final teamPlayers = session.players.where((p) => p.color == newTeamColor).toList();
    if (teamPlayers.length >= 2) {
      throw Exception('This team is already full');
    }

    // Mettre à jour le joueur
    final player = session.players[playerIndex];
    final updatedPlayer = player.copyWith(color: newTeamColor);
    final updatedPlayers = [...session.players];
    updatedPlayers[playerIndex] = updatedPlayer;

    final updatedSession = session.copyWith(players: updatedPlayers);
    _sessions[sessionId] = updatedSession;
  }

  /// Quitter une session
  Future<void> leaveGameSession(String sessionId, String playerId) async {
    _callCount++;
    await _simulateDelay();
    if (_shouldFail) throw Exception(_errorMessage);

    final session = _sessions[sessionId];
    if (session == null) {
      throw Exception('Game session not found');
    }

    // Retirer le joueur de la session
    final updatedPlayers = session.players.where((p) => p.id != playerId).toList();
    final updatedSession = session.copyWith(players: updatedPlayers);
    _sessions[sessionId] = updatedSession;

    // Retirer le joueur de la map des joueurs
    _players.remove(playerId);
  }

  /// Démarrer une session
  Future<void> startGameSession(String sessionId) async {
    _callCount++;
    await _simulateDelay();
    if (_shouldFail) throw Exception(_errorMessage);

    final session = _sessions[sessionId];
    if (session == null) {
      throw Exception('Game session not found');
    }

    if (!session.isReadyToStart) {
      throw Exception('Session not ready to start (need 4 players, 2 per team)');
    }

    final updatedSession = session.copyWith(
      status: 'challenge',
      startedAt: DateTime.now(),
    );
    _sessions[sessionId] = updatedSession;
  }

  /// Rafraîchir une session (simule un GET)
  Future<GameSession> refreshGameSession(String sessionId) async {
    return getGameSession(sessionId);
  }

  // ===== HELPERS PRIVÉS =====

  /// Simule un délai réseau
  Future<void> _simulateDelay() async {
    if (_simulatedDelay != null) {
      await Future.delayed(_simulatedDelay!);
    }
  }

  /// Obtenir la couleur d'équipe disponible
  Future<String> getAvailableTeamColor(String sessionId) async {
    _callCount++;
    await _simulateDelay();
    if (_shouldFail) throw Exception(_errorMessage);

    final session = _sessions[sessionId];
    if (session == null) {
      throw Exception('Game session not found');
    }

    final redCount = session.players.where((p) => p.color == 'red').length;
    final blueCount = session.players.where((p) => p.color == 'blue').length;

    if (redCount < 2) return 'red';
    if (blueCount < 2) return 'blue';
    throw Exception('No available team (session is full)');
  }
}

/// Factory pour créer des mocks pré-configurés
class MockApiServiceFactory {
  /// Mock avec session vide
  static MockApiService empty() {
    return MockApiService();
  }

  /// Mock avec session contenant le host
  static MockApiService withHost() {
    final mock = MockApiService();
    final session = TestData.sessionWithHost();
    mock.seedData(sessions: [session]);
    return mock;
  }

  /// Mock avec session complète (4 joueurs)
  static MockApiService withFullSession() {
    final mock = MockApiService();
    final session = TestData.sessionWith4Players();
    mock.seedData(sessions: [session]);
    return mock;
  }

  /// Mock configuré pour échouer
  static MockApiService failing([String? errorMessage]) {
    final mock = MockApiService();
    mock.setShouldFail(true, errorMessage);
    return mock;
  }

  /// Mock avec délai réseau
  static MockApiService withDelay(Duration delay) {
    final mock = MockApiService();
    mock.setSimulatedDelay(delay);
    return mock;
  }
}
