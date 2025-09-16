import 'dart:async';
import '../models/player.dart';
import '../models/game_session.dart';
import '../models/challenge.dart';
import 'api_service.dart';

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
    try {
      _currentGameSession = await _apiService.createGameSession();
      _gameSessionController.add(_currentGameSession);
      _currentStatus = 'lobby';
      _statusController.add(_currentStatus);
      
      return _currentGameSession!;
    } catch (e) {
      throw Exception('Erreur lors de la création de la session: $e');
    }
  }

  /// Rejoint une session existante
  Future<void> joinGameSession(String gameSessionId, String color) async {
    try {
      await _apiService.joinGameSession(gameSessionId, color);
      await refreshGameSession(gameSessionId);
    } catch (e) {
      throw Exception('Erreur lors de la connexion à la session: $e');
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

  /// Récupère la liste des sessions disponibles
  Future<List<GameSession>> getAvailableRooms() async {
    try {
      return await _apiService.getAvailableRooms();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des sessions disponibles: $e');
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

  /// Nettoie les ressources
  void dispose() {
    _playerController.close();
    _gameSessionController.close();
    _statusController.close();
    _challengesController.close();
  }
}
