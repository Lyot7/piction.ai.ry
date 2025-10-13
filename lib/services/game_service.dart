import 'dart:async';
import '../models/player.dart';
import '../models/game_session.dart';
import '../models/challenge.dart';
import 'api_service.dart';
import '../utils/logger.dart';

/// Service de gestion de l'état du jeu
class GameService {
  static final GameService _instance = GameService._internal();
  
  // ===== Flux d'états automatique =====
  // lobby -> challenge -> playing -> finished
  void _checkTransitions() {
    if (_currentStatus == 'challenge') {
      // challenge -> playing: Tous les joueurs ont envoyé 3 challenges
      if (_currentGameSession != null &&
          _currentGameSession!.players.every((p) => p.challengesSent == 3)) {
        _currentStatus = 'playing';
        _statusController.add(_currentStatus);
      }
    } else if (_currentStatus == 'playing') {
      // playing -> finished: Timer écoulé ou tous challenges terminés
      final now = DateTime.now();
      if (_currentGameSession != null) {
        final start = _currentGameSession!.startTime;
        // Finir si timer >5 min
        if (start != null && now.difference(start).inMinutes >= 5) {
          _currentStatus = 'finished';
          _statusController.add(_currentStatus);
        }
        // Vérifier si tous les challenges sont terminés (async)
        _checkAllChallengesCompleted();
      }
    }
  }

  /// Vérifie si tous les challenges sont terminés (async)
  Future<void> _checkAllChallengesCompleted() async {
    if (_currentGameSession == null || _currentStatus != 'playing') return;

    try {
      final allChallenges = await _apiService.listSessionChallenges(_currentGameSession!.id);

      // Si tous les challenges sont résolus, finir la partie
      if (allChallenges.isNotEmpty && allChallenges.every((c) => c.isCompleted)) {
        _currentStatus = 'finished';
        _statusController.add(_currentStatus);
        AppLogger.success('[GameService] Tous les challenges terminés, fin de la partie');
      }
    } catch (e) {
      AppLogger.error('[GameService] Erreur lors de la vérification des challenges', e);
    }
  }

  factory GameService() {
    final service = _instance;
    // Écoute en continu les mises à jour de session et de statut
    service.statusStream.listen((_) => service._checkTransitions());
    service.gameSessionStream.listen((_) => service._checkTransitions());
    return service;
  }

  GameService._internal();

  final ApiService _apiService = ApiService();
  
  // État actuel
  Player? _currentPlayer;
  GameSession? _currentGameSession;
  List<Challenge> _myChallenges = [];
  List<Challenge> _challengesToGuess = [];
  String _currentStatus = 'lobby';

  // Streams pour notifier les changements
  final StreamController<Player?> _playerController = StreamController<Player?>.broadcast();
  final StreamController<GameSession?> _gameSessionController = StreamController<GameSession?>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();
  final StreamController<List<Challenge>> _challengesController = StreamController<List<Challenge>>.broadcast();

  // Getters pour les streams
  Stream<Player?> get playerStream => _playerController.stream;
  Stream<GameSession?> get gameSessionStream => _gameSessionController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<List<Challenge>> get challengesStream => _challengesController.stream;

  // Getters pour l'état actuel
  Player? get currentPlayer => _currentPlayer;
  GameSession? get currentGameSession => _currentGameSession;
  List<Challenge> get myChallenges => _myChallenges;
  List<Challenge> get challengesToGuess => _challengesToGuess;
  String get currentStatus => _currentStatus;

  /// Initialise le service
  Future<void> initialize() async {
    await _apiService.initialize();
    
    if (_apiService.isLoggedIn) {
      try {
        _currentPlayer = await _apiService.getMe();
        _playerController.add(_currentPlayer);
      } catch (e) {
        // Token invalide, déconnecter
        await logout();
      }
    }
  }

  // ===== AUTHENTIFICATION =====

  /// Crée un compte et se connecte
  Future<Player> createAccountAndLogin(String name, String password) async {
    try {
      // Créer le joueur
      await _apiService.createPlayer(name, password);
      
      // Se connecter
      await _apiService.login(name, password);
      
      // Récupérer les infos
      _currentPlayer = await _apiService.getMe();
      _playerController.add(_currentPlayer);
      
      return _currentPlayer!;
    } catch (e) {
      throw Exception('Erreur lors de la création du compte: $e');
    }
  }

  /// Se connecte avec un compte existant
  Future<Player> login(String name, String password) async {
    try {
      await _apiService.login(name, password);
      _currentPlayer = await _apiService.getMe();
      _playerController.add(_currentPlayer);
      
      return _currentPlayer!;
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  /// Se connecte avec juste un nom d'utilisateur
  Future<Player> loginWithUsername(String username) async {
    try {
      await _apiService.loginWithUsername(username);
      _currentPlayer = await _apiService.getMe();
      _playerController.add(_currentPlayer);
      
      return _currentPlayer!;
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  /// Déconnecte l'utilisateur
  Future<void> logout() async {
    await _apiService.logout();
    _currentPlayer = null;
    _currentGameSession = null;
    _myChallenges = [];
    _challengesToGuess = [];
    _currentStatus = 'lobby';
    
    _playerController.add(null);
    _gameSessionController.add(null);
    _statusController.add(_currentStatus);
    _challengesController.add([]);
  }

  // ===== GESTION DES SESSIONS =====

  /// Crée une nouvelle session de jeu
  Future<GameSession> createGameSession() async {
    if (!isLoggedIn) {
      throw Exception('Vous devez être connecté pour créer une session');
    }
    
    try {
      _currentGameSession = await _apiService.createGameSession();
      _currentStatus = 'lobby';
      
      // Actualiser la session pour récupérer l'état complet
      await refreshGameSession(_currentGameSession!.id);
      
      return _currentGameSession!;
    } catch (e) {
      throw Exception('Erreur lors de la création de la session: $e');
    }
  }

  /// Rejoint une session existante
  Future<void> joinGameSession(String gameSessionId, [String? color]) async {
    try {
      // Si aucune couleur n'est spécifiée, attribuer automatiquement
      color ??= await _getAvailableTeamColor(gameSessionId);

      await _safeJoinGameSession(gameSessionId, color);
    } catch (e) {
      throw Exception('Erreur lors de la connexion à la session: $e');
    }
  }

  /// Trouve une couleur d'équipe disponible automatiquement
  Future<String> _getAvailableTeamColor(String gameSessionId) async {
    try {
      final session = await _apiService.getGameSession(gameSessionId);
      final redCount = session.players.where((p) => p.color == 'red').length;
      final blueCount = session.players.where((p) => p.color == 'blue').length;

      // Attribuer à l'équipe avec le moins de joueurs
      if (redCount <= blueCount && redCount < 2) {
        return 'red';
      } else if (blueCount < 2) {
        return 'blue';
      }

      // Si les deux équipes sont pleines, choisir rouge par défaut
      return 'red';
    } catch (e) {
      // En cas d'erreur, attribuer rouge par défaut
      return 'red';
    }
  }

  /// Actualise les informations de la session avec retry automatique
  Future<void> refreshGameSession(String gameSessionId, {int maxRetries = 3}) async {
    int attempt = 0;
    Exception? lastError;

    while (attempt < maxRetries) {
      try {
        _currentGameSession = await _apiService.getGameSession(gameSessionId);
        _currentStatus = await _apiService.getGameSessionStatus(gameSessionId);

        _gameSessionController.add(_currentGameSession);
        _checkTransitions();
        _statusController.add(_currentStatus);

        return;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        attempt++;

        // Vérifier si c'est une erreur réseau transitoire
        final errorMessage = e.toString().toLowerCase();
        final isTransientError = errorMessage.contains('connection closed') ||
            errorMessage.contains('connection reset') ||
            errorMessage.contains('timeout') ||
            errorMessage.contains('socket') ||
            errorMessage.contains('network');

        if (isTransientError && attempt < maxRetries) {
          // Délai exponentiel: 500ms, 1s, 2s
          final delayMs = 500 * (1 << (attempt - 1));
          await Future.delayed(Duration(milliseconds: delayMs));
        } else if (!isTransientError) {
          throw Exception('Erreur lors de l\'actualisation de la session: $e');
        }
      }
    }

    throw Exception('Erreur lors de l\'actualisation de la session après $maxRetries tentatives: $lastError');
  }

  /// Démarre la session de jeu
  Future<void> startGameSession() async {
    if (_currentGameSession == null) {
      throw Exception('Aucune session active');
    }

    try {
      await _apiService.startGameSession(_currentGameSession!.id);
      _currentStatus = 'challenge';
_statusController.add(_currentStatus);
    // Tenter transition auto
    _checkTransitions();
    } catch (e) {
      throw Exception('Erreur lors du démarrage de la session: $e');
    }
  }

  /// Quitte la session actuelle
  Future<void> leaveGameSession() async {
    if (_currentGameSession == null) return;

    try {
      await _apiService.leaveGameSession(_currentGameSession!.id);
      _currentGameSession = null;
      _currentStatus = 'lobby';
      _myChallenges = [];
      _challengesToGuess = [];
      
      _gameSessionController.add(null);
      _statusController.add(_currentStatus);
      _challengesController.add([]);
    } catch (e) {
      throw Exception('Erreur lors de la déconnexion de la session: $e');
    }
  }

  /// Change d'équipe dans la session actuelle
  Future<void> changeTeam(String newColor) async {
    if (_currentGameSession == null) {
      throw Exception('Aucune session active');
    }

    try {
      // Actualiser d'abord la session pour avoir l'état le plus récent
      await refreshGameSession(_currentGameSession!.id);

      // Vérifier que l'équipe cible n'est pas pleine
      final targetTeamCount = _currentGameSession!.players
          .where((p) => p.color == newColor)
          .length;

      if (targetTeamCount >= 2) {
        throw Exception('L\'équipe $newColor est déjà complète');
      }

      // Version robuste du changement d'équipe
      await _safeChangeTeam(_currentGameSession!.id, newColor);
    } catch (e) {
      throw Exception('Erreur lors du changement d\'équipe: $e');
    }
  }

  /// Version robuste du changement d'équipe
  Future<void> _safeChangeTeam(String gameSessionId, String newColor) async {
    try {
      await _apiService.leaveGameSession(gameSessionId);
      await _apiService.joinGameSession(gameSessionId, newColor);
      await refreshGameSession(gameSessionId);
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();

      if (errorMessage.contains('already in game session') ||
          errorMessage.contains('player already in') ||
          errorMessage.contains('already in room')) {
        try {
          await _apiService.joinGameSession(gameSessionId, newColor);
          await refreshGameSession(gameSessionId);
        } catch (joinError) {
          await _safeJoinGameSession(gameSessionId, newColor);
        }
      } else if (errorMessage.contains('not in game session') ||
                 errorMessage.contains('player not in')) {
        await _safeJoinGameSession(gameSessionId, newColor);
      } else {
        rethrow;
      }
    }
  }

  /// Rejoint automatiquement une équipe disponible (sans spécifier de couleur)
  Future<void> joinAvailableTeam(String gameSessionId) async {
    try {
      final availableColor = await _getAvailableTeamColor(gameSessionId);
      await _safeJoinGameSession(gameSessionId, availableColor);
      await refreshGameSession(gameSessionId);
    } catch (e) {
      throw Exception('Erreur lors de l\'attribution automatique d\'équipe: $e');
    }
  }

  /// Version "safe" de joinGameSession qui gère la désynchronisation client/serveur
  Future<void> _safeJoinGameSession(String gameSessionId, String color) async {
    try {
      await _apiService.joinGameSession(gameSessionId, color);
      try {
        await refreshGameSession(gameSessionId);
      } catch (refreshError) {
        final refreshErrorMsg = refreshError.toString().toLowerCase();
        if (refreshErrorMsg.contains('connection closed') ||
            refreshErrorMsg.contains('timeout') ||
            refreshErrorMsg.contains('network')) {
          return; // Join réussi, le refresh sera retenté par le lobby
        } else {
          rethrow;
        }
      }
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();

      if (errorMessage.contains('already in game session') ||
          errorMessage.contains('player already in') ||
          errorMessage.contains('already in room')) {
        try {
          await _apiService.leaveGameSession(gameSessionId);
          await _apiService.joinGameSession(gameSessionId, color);
          await refreshGameSession(gameSessionId);
        } catch (leaveJoinError) {
          await refreshGameSession(gameSessionId);
          final currentPlayer = _currentPlayer;

          if (currentPlayer != null && _currentGameSession != null) {
            final playerInSession = _currentGameSession!.players
                .where((p) => p.id == currentPlayer.id)
                .firstOrNull;

            if (playerInSession != null) {
              if (playerInSession.color != color) {
                await changeTeam(color);
              }
              return;
            }
          }
          rethrow;
        }
      } else if (errorMessage.contains('not in game session') ||
                 errorMessage.contains('player not in')) {
        try {
          await refreshGameSession(gameSessionId);
          await _apiService.joinGameSession(gameSessionId, color);
          await refreshGameSession(gameSessionId);
        } catch (notInSessionError) {
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }


  // ===== GESTION DES CHALLENGES =====

  /// Envoie un challenge avec le nouveau format
  /// Format: "Un/Une [INPUT1] Sur/Dans Un/Une [INPUT2]" + 3 mots interdits
  Future<Challenge> sendChallenge(
    String article1,      // "Un" ou "Une"
    String input1,        // Premier mot à deviner
    String preposition,   // "Sur" ou "Dans"
    String article2,      // "Un" ou "Une"
    String input2,        // Deuxième mot à deviner
    List<String> forbiddenWords, // 3 mots interdits
  ) async {
    if (_currentGameSession == null) {
      throw Exception('Aucune session active');
    }

    try {
      final challenge = await _apiService.sendChallenge(
        _currentGameSession!.id,
        article1,
        input1,
        preposition,
        article2,
        input2,
        forbiddenWords,
      );

      return challenge;
    } catch (e) {
      throw Exception('Erreur lors de l\'envoi du challenge: $e');
    }
  }

  /// Actualise les challenges du joueur
  Future<void> refreshMyChallenges() async {
    if (_currentGameSession == null) return;

    try {
      _myChallenges = await _apiService.getMyChallenges(_currentGameSession!.id);
      _challengesController.add(_myChallenges);
    } catch (e) {
      throw Exception('Erreur lors de l\'actualisation des challenges: $e');
    }
  }

  /// Actualise les challenges à deviner
  Future<void> refreshChallengesToGuess() async {
    if (_currentGameSession == null) return;

    try {
      _challengesToGuess = await _apiService.getMyChallengesToGuess(_currentGameSession!.id);
      _challengesController.add(_challengesToGuess);
    } catch (e) {
      throw Exception('Erreur lors de l\'actualisation des challenges à deviner: $e');
    }
  }


  /// Envoie une réponse pour un challenge
  Future<void> answerChallenge(String challengeId, String answer, bool isResolved) async {
    if (_currentGameSession == null) {
      throw Exception('Aucune session active');
    }

    try {
      await _apiService.answerChallenge(_currentGameSession!.id, challengeId, answer, isResolved);
    } catch (e) {
      throw Exception('Erreur lors de l\'envoi de la réponse: $e');
    }
  }

  // ===== GESTION DES RÔLES =====

  /// Inverse les rôles de tous les joueurs (drawer <-> guesser)
  Future<void> switchAllRoles() async {
    if (_currentGameSession == null) {
      throw Exception('Aucune session active');
    }

    try {
      // Notifier le backend de l'inversion des rôles
      // Note: Ceci peut être géré automatiquement par le backend
      await refreshGameSession(_currentGameSession!.id);

      AppLogger.success('[GameService] Rôles inversés avec succès');
    } catch (e) {
      throw Exception('Erreur lors de l\'inversion des rôles: $e');
    }
  }

  /// Valide qu'un prompt ne contient pas de mots interdits
  bool validatePrompt(String prompt, Challenge challenge) {
    return !challenge.promptContainsForbiddenWords(prompt);
  }

  /// Retourne le rôle actuel du joueur courant
  String? getCurrentPlayerRole() {
    if (_currentPlayer == null || _currentGameSession == null) return null;

    final player = _currentGameSession!.players
        .where((p) => p.id == _currentPlayer!.id)
        .firstOrNull;

    return player?.role;
  }

  /// Vérifie si c'est le tour du joueur actuel
  bool isMyTurn() {
    if (_currentPlayer == null || _currentGameSession == null) return false;

    final player = _currentGameSession!.players
        .where((p) => p.id == _currentPlayer!.id)
        .firstOrNull;

    // C'est le tour du joueur s'il est drawer
    return player?.isDrawer ?? false;
  }

  // ===== UTILITAIRES =====

  /// Vérifie si l'utilisateur est connecté
  bool get isLoggedIn => _apiService.isLoggedIn;

  /// Vérifie si une session est active
  bool get hasActiveSession => _currentGameSession != null;

  /// Vérifie si la session est prête à démarrer
  bool get isSessionReadyToStart => 
      _currentGameSession?.isReadyToStart ?? false;

  /// Vérifie si le jeu est en cours
  bool get isGameActive =>
      ['challenge', 'playing'].contains(_currentStatus);

  /// Vérifie si le jeu est terminé
  bool get isGameFinished => _currentStatus == 'finished';

  /// Obtient les statistiques des équipes dans la session actuelle
  Map<String, int> get teamStats {
    if (_currentGameSession == null) return {'red': 0, 'blue': 0};

    final redCount = _currentGameSession!.players.where((p) => p.color == 'red').length;
    final blueCount = _currentGameSession!.players.where((p) => p.color == 'blue').length;

    return {'red': redCount, 'blue': blueCount};
  }

  /// Force une synchronisation complète de l'état avec le serveur
  Future<void> forceSyncWithServer() async {
    if (_currentGameSession != null) {
      try {
        await refreshGameSession(_currentGameSession!.id);
        if (_currentPlayer != null) {
          final me = await _apiService.getMe();
          _currentPlayer = me;
          _playerController.add(me);
        }
      } catch (e) {
        if (_currentGameSession != null) {
          await refreshGameSession(_currentGameSession!.id);
        }
      }
    }
  }

  /// Nettoie les ressources
  void dispose() {
    _playerController.close();
    _gameSessionController.close();
    _statusController.close();
    _challengesController.close();
  }
}
