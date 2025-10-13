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
  // null -> challenge -> drawing -> guessing -> finished
  void _checkTransitions() {
    if (_currentStatus == 'challenge') {
      // challenge -> drawing
      if (_currentGameSession != null &&
          _currentGameSession!.players.every((p) => p.challengesSent == 3)) {
        _currentStatus = 'drawing';
        _statusController.add(_currentStatus);
      }
    } else if (_currentStatus == 'drawing') {
      // drawing -> guessing
      if (_currentGameSession != null &&
          _currentGameSession!.players.every((p) => p.hasDrawn)) {
        _currentStatus = 'guessing';
        _statusController.add(_currentStatus);
      }
    } else if (_currentStatus == 'guessing') {
      // guessing -> finished
      final now = DateTime.now();
      if (_currentGameSession != null) {
        final start = _currentGameSession!.startTime;
        // Finir si tous ont répondu ou si >5 min
        if (_currentGameSession!.players.every((p) => p.hasGuessed) ||
            (start != null && now.difference(start).inMinutes >= 5)) {
          _currentStatus = 'finished';
          _statusController.add(_currentStatus);
        }
      }
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

  /// Actualise les informations de la session
  Future<void> refreshGameSession(String gameSessionId) async {
    try {
      _currentGameSession = await _apiService.getGameSession(gameSessionId);
      _currentStatus = await _apiService.getGameSessionStatus(gameSessionId);
      
_gameSessionController.add(_currentGameSession);
      // Vérifier si on doit changer de phase
      _checkTransitions();
      _statusController.add(_currentStatus);
    } catch (e) {
      throw Exception('Erreur lors de l\'actualisation de la session: $e');
    }
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
    AppLogger.log('[SafeChangeTeam] 🔄 Changement d\'équipe vers $newColor');

    try {
      // Quitter et rejoindre avec la nouvelle couleur
      AppLogger.log('[SafeChangeTeam] 🚪 Leave de la session...');
      await _apiService.leaveGameSession(gameSessionId);
      AppLogger.log('[SafeChangeTeam] 📡 Join avec nouvelle couleur $newColor...');
      await _apiService.joinGameSession(gameSessionId, newColor);
      AppLogger.log('[SafeChangeTeam] 🔄 Refresh...');
      await refreshGameSession(gameSessionId);
      AppLogger.success('[SafeChangeTeam] Changement d\'équipe réussi');
    } catch (e) {
      AppLogger.error('[SafeChangeTeam] Erreur', e);
      final errorMessage = e.toString().toLowerCase();

      if (errorMessage.contains('already in game session') ||
          errorMessage.contains('player already in') ||
          errorMessage.contains('already in room')) {

        AppLogger.log('[SafeChangeTeam] 🔄 Joueur encore dans session, essai join direct...');

        // Le joueur est encore dans la session, essayer juste le join sans leave
        try {
          await _apiService.joinGameSession(gameSessionId, newColor);
          await refreshGameSession(gameSessionId);
          AppLogger.success('[SafeChangeTeam] Join direct réussi');
        } catch (joinError) {
          AppLogger.error('[SafeChangeTeam] Join direct échoué', joinError);
          AppLogger.log('[SafeChangeTeam] 🔄 Utilisation du SafeJoin comme fallback...');
          // Utiliser la méthode safe join comme fallback
          await _safeJoinGameSession(gameSessionId, newColor);
        }
      } else if (errorMessage.contains('not in game session') ||
                 errorMessage.contains('player not in')) {

        AppLogger.log('[SafeChangeTeam] 🔄 Joueur not in session, utilisation du SafeJoin...');
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
    } catch (e) {
      throw Exception('Erreur lors de l\'attribution automatique d\'équipe: $e');
    }
  }

  /// Version "safe" de joinGameSession qui gère la désynchronisation client/serveur
  Future<void> _safeJoinGameSession(String gameSessionId, String color) async {
    AppLogger.log('[SafeJoin] 🎯 Tentative de rejoindre session $gameSessionId avec couleur $color');
    AppLogger.log('[SafeJoin] 👤 Joueur actuel: ${_currentPlayer?.id} (${_currentPlayer?.name})');

    try {
      // Essayer de rejoindre directement
      AppLogger.log('[SafeJoin] 📡 Appel API joinGameSession...');
      await _apiService.joinGameSession(gameSessionId, color);
      AppLogger.success('[SafeJoin] Join réussi, refresh de la session...');
      await refreshGameSession(gameSessionId);
      AppLogger.success('[SafeJoin] Refresh terminé avec succès');
    } catch (e) {
      AppLogger.error('[SafeJoin] Erreur lors du join', e);
      final errorMessage = e.toString().toLowerCase();

      if (errorMessage.contains('already in game session') ||
          errorMessage.contains('player already in') ||
          errorMessage.contains('already in room')) {

        AppLogger.log('[SafeJoin] 🔄 Le joueur est déjà dans la session, tentative leave+rejoin...');

        // Le joueur est déjà dans la session côté serveur
        // Essayer de faire un leave puis rejoin
        try {
          AppLogger.log('[SafeJoin] 🚪 Leave de la session...');
          await _apiService.leaveGameSession(gameSessionId);
          AppLogger.log('[SafeJoin] 📡 Rejoin avec couleur $color...');
          await _apiService.joinGameSession(gameSessionId, color);
          AppLogger.log('[SafeJoin] 🔄 Refresh après leave+rejoin...');
          await refreshGameSession(gameSessionId);
          AppLogger.success('[SafeJoin] Leave+rejoin réussi');
        } catch (leaveJoinError) {
          AppLogger.error('[SafeJoin] Erreur lors du leave+rejoin', leaveJoinError);
          AppLogger.log('[SafeJoin] 🔄 Tentative de refresh et vérification d\'état...');

          // Si ça échoue encore, actualiser la session et vérifier l'état
          await refreshGameSession(gameSessionId);

          // Vérifier si le joueur est maintenant dans la session
          final currentPlayer = _currentPlayer;
          AppLogger.log('[SafeJoin] 🔍 Vérification de l\'état après refresh...');
          AppLogger.log('[SafeJoin] 👤 Joueur: ${currentPlayer?.id}');
          AppLogger.log('[SafeJoin] 🎮 Session: ${_currentGameSession?.id}');

          if (currentPlayer != null && _currentGameSession != null) {
            final playerInSession = _currentGameSession!.players
                .where((p) => p.id == currentPlayer.id)
                .firstOrNull;

            AppLogger.log('[SafeJoin] 🔍 Joueur trouvé dans session: ${playerInSession?.id} (couleur: ${playerInSession?.color})');

            if (playerInSession != null) {
              // Le joueur est dans la session, changer d'équipe si nécessaire
              if (playerInSession.color != color) {
                AppLogger.log('[SafeJoin] 🔄 Changement d\'équipe nécessaire: ${playerInSession.color} -> $color');
                await changeTeam(color);
              } else {
                AppLogger.success('[SafeJoin] Joueur déjà dans la bonne équipe');
              }
              // Sinon, tout est OK, le joueur est déjà dans la bonne équipe
              return;
            }
          }

          AppLogger.error('[SafeJoin] État incohérent détecté, rethrow de l\'erreur');
          // Si on arrive ici, il y a vraiment un problème
          rethrow;
        }
      } else if (errorMessage.contains('not in game session') ||
                 errorMessage.contains('player not in')) {

        AppLogger.log('[SafeJoin] 🔄 Erreur "Player not in game session" détectée');
        AppLogger.log('[SafeJoin] 🔄 Tentative de refresh et rejoin...');

        // Le joueur n'est pas dans la session côté serveur
        try {
          await refreshGameSession(gameSessionId);
          await _apiService.joinGameSession(gameSessionId, color);
          await refreshGameSession(gameSessionId);
          AppLogger.success('[SafeJoin] Rejoin après "not in session" réussi');
        } catch (notInSessionError) {
          AppLogger.error('[SafeJoin] Échec du rejoin après "not in session"', notInSessionError);
          rethrow;
        }
      } else {
        AppLogger.error('[SafeJoin] Autre type d\'erreur', e);
        // Autre type d'erreur, la remonter
        rethrow;
      }
    }
  }


  // ===== GESTION DES CHALLENGES =====

  /// Envoie un challenge
  Future<Challenge> sendChallenge(
    String firstWord,
    String secondWord,
    String thirdWord,
    String fourthWord,
    String fifthWord,
    List<String> forbiddenWords,
  ) async {
    if (_currentGameSession == null) {
      throw Exception('Aucune session active');
    }

    try {
      final challenge = await _apiService.sendChallenge(
        _currentGameSession!.id,
        firstWord,
        secondWord,
        thirdWord,
        fourthWord,
        fifthWord,
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
      ['challenge', 'drawing', 'guessing'].contains(_currentStatus);

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
        // Double refresh avec une petite pause pour éviter les race conditions
        await refreshGameSession(_currentGameSession!.id);
        await Future.delayed(const Duration(milliseconds: 200));
        await refreshGameSession(_currentGameSession!.id);

        // Vérifier que le joueur actuel est bien dans la session côté serveur
        final currentPlayer = _currentPlayer;
        if (currentPlayer != null) {
          final me = await _apiService.getMe();
          _currentPlayer = me;
          _playerController.add(me);
        }
      } catch (e) {
        // En cas d'erreur, au moins essayer de refresh une fois
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
