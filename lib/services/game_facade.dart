import 'dart:async';
import '../models/player.dart';
import '../models/game_session.dart';
import '../models/challenge.dart';
import '../managers/auth_manager.dart';
import '../managers/session_manager.dart';
import '../managers/team_manager.dart';
import '../managers/challenge_manager.dart';
import '../managers/role_manager.dart';
import '../managers/game_state_manager.dart';
import '../managers/score_manager.dart';
import '../managers/timer_manager.dart';
import 'api_service.dart';
import '../utils/logger.dart';

/// Facade qui compose tous les managers SOLID pour remplacer GameService
///
/// Cette classe implémente le pattern Facade pour simplifier l'utilisation
/// des managers spécialisés. Elle est le point d'entrée unique pour toute
/// la logique métier de l'application.
///
/// **Architecture SOLID:**
/// - AuthManager: Authentification
/// - SessionManager: Sessions de jeu
/// - TeamManager: Gestion des équipes
/// - ChallengeManager: Challenges
/// - RoleManager: Rôles des joueurs
/// - GameStateManager: Transitions d'état
/// - ScoreManager: Scores
/// - TimerManager: Timer de jeu
///
/// **Usage:**
/// ```dart
/// final facade = GameFacade();
/// await facade.initialize();
/// final player = await facade.auth.loginWithUsername('Alice');
/// final session = await facade.session.createGameSession();
/// ```
class GameFacade {
  // === MANAGERS ===

  /// Manager d'authentification
  late final AuthManager auth;

  /// Manager de sessions
  late final SessionManager session;

  /// Manager d'équipes
  late final TeamManager team;

  /// Manager de challenges
  late final ChallengeManager challenge;

  /// Manager de rôles
  late final RoleManager role;

  /// Manager d'état du jeu
  late final GameStateManager gameState;

  /// Manager de scores
  late final ScoreManager score;

  /// Manager de timer
  late final TimerManager timer;

  // === INTERNAL STATE ===

  final ApiService _apiService;

  /// Joueur actuellement connecté
  Player? _currentPlayer;
  Player? get currentPlayer => _currentPlayer;

  /// Session de jeu actuelle
  GameSession? _currentGameSession;
  GameSession? get currentGameSession => _currentGameSession;

  /// Challenges créés par le joueur
  List<Challenge> _myChallenges = [];
  List<Challenge> get myChallenges => _myChallenges;

  /// Challenges à deviner
  List<Challenge> _challengesToGuess = [];
  List<Challenge> get challengesToGuess => _challengesToGuess;

  // === STREAMS ===

  /// Stream du joueur connecté
  final StreamController<Player?> _playerController = StreamController<Player?>.broadcast();
  Stream<Player?> get playerStream => _playerController.stream;

  /// Stream de la session de jeu
  final StreamController<GameSession?> _gameSessionController = StreamController<GameSession?>.broadcast();
  Stream<GameSession?> get gameSessionStream => _gameSessionController.stream;

  /// Stream du statut du jeu
  Stream<String> get statusStream => gameState.statusStream;

  /// Stream des challenges
  final StreamController<List<Challenge>> _challengesController = StreamController<List<Challenge>>.broadcast();
  Stream<List<Challenge>> get challengesStream => _challengesController.stream;

  // === SINGLETON ===

  static final GameFacade _instance = GameFacade._internal();
  factory GameFacade() => _instance;

  GameFacade._internal() : _apiService = ApiService() {
    // Initialiser tous les managers avec ApiService
    auth = AuthManager(_apiService);
    session = SessionManager(_apiService);
    team = TeamManager(_apiService, session); // TeamManager needs SessionManager
    challenge = ChallengeManager(_apiService);
    role = RoleManager();

    // ChallengeManager est nécessaire pour GameStateManager
    gameState = GameStateManager(challenge);

    score = ScoreManager();
    timer = TimerManager();

    AppLogger.info('[GameFacade] Facade initialisée avec tous les managers SOLID');
  }

  // === INITIALIZATION ===

  /// Initialise la facade et restaure la session si possible
  Future<void> initialize() async {
    await _apiService.initialize();

    // Tenter de restaurer le joueur connecté
    if (_apiService.isLoggedIn) {
      try {
        _currentPlayer = await _apiService.getMe();
        _playerController.add(_currentPlayer);
        AppLogger.success('[GameFacade] Session restaurée pour: ${_currentPlayer!.name}');
      } catch (e) {
        AppLogger.error('[GameFacade] Impossible de restaurer la session', e);
      }
    }
  }

  // === CONVENIENT METHODS (Forwards to managers) ===

  // --- Authentication ---

  /// Se connecte avec un nom d'utilisateur (crée le compte si nécessaire)
  Future<Player> loginWithUsername(String username) async {
    _currentPlayer = await auth.loginWithUsername(username);
    _playerController.add(_currentPlayer);
    return _currentPlayer!;
  }

  /// Déconnecte l'utilisateur
  Future<void> logout() async {
    await auth.logout();
    _currentPlayer = null;
    _currentGameSession = null;
    _playerController.add(null);
    _gameSessionController.add(null);
  }

  // --- Session Management ---

  /// Crée une nouvelle session de jeu
  Future<GameSession> createGameSession() async {
    _currentGameSession = await session.createGameSession();
    _gameSessionController.add(_currentGameSession);
    return _currentGameSession!;
  }

  /// Rejoint une session de jeu
  Future<void> joinGameSession(String gameSessionId, String color) async {
    await session.joinGameSession(gameSessionId, color);
    await refreshGameSession(gameSessionId);
  }

  /// Rejoint automatiquement une équipe disponible
  Future<void> joinAvailableTeam(String gameSessionId) async {
    if (_currentPlayer == null) {
      throw Exception('Vous devez être connecté pour rejoindre une équipe');
    }

    // Récupérer la session pour vérifier les équipes
    final gameSession = await _apiService.getGameSession(gameSessionId);
    final redCount = gameSession.players.where((p) => p.color == 'red').length;
    final blueCount = gameSession.players.where((p) => p.color == 'blue').length;

    // Attribuer à l'équipe avec le moins de joueurs
    String color;
    if (redCount <= blueCount && redCount < 2) {
      color = 'red';
    } else if (blueCount < 2) {
      color = 'blue';
    } else {
      // Si les deux équipes sont pleines, choisir rouge par défaut
      color = 'red';
    }

    await joinGameSession(gameSessionId, color);
  }

  /// Rafraîchit les informations de la session
  Future<void> refreshGameSession(String gameSessionId) async {
    _currentGameSession = await session.refreshGameSession(gameSessionId);
    _gameSessionController.add(_currentGameSession);

    // Vérifier les transitions d'état automatiques
    await gameState.checkTransitions(_currentGameSession);
  }

  /// Quitte la session actuelle
  Future<void> leaveGameSession() async {
    if (_currentGameSession != null) {
      await session.leaveGameSession(_currentGameSession!.id);
      _currentGameSession = null;
      _gameSessionController.add(null);
      gameState.resetToLobby();
    }
  }

  /// Démarre la session de jeu
  Future<void> startGameSession() async {
    if (_currentGameSession == null) {
      throw Exception('Aucune session active');
    }

    await session.startGameSession(_currentGameSession!.id);
    gameState.startGame();

    // Rafraîchir pour récupérer les changements
    await refreshGameSession(_currentGameSession!.id);
  }

  // --- Team Management ---

  /// Change d'équipe
  Future<void> changeTeam(String gameSessionId, String newTeamColor) async {
    if (_currentPlayer == null) throw Exception('Aucun joueur connecté');
    await team.changeTeam(gameSessionId, newTeamColor);
    await refreshGameSession(gameSessionId);
  }

  // --- Challenge Management ---

  /// Envoie un challenge
  Future<Challenge> sendChallenge(
    String gameSessionId,
    String article1,
    String input1,
    String preposition,
    String article2,
    String input2,
    List<String> forbiddenWords,
  ) async {
    return await challenge.sendChallenge(
      gameSessionId,
      article1,
      input1,
      preposition,
      article2,
      input2,
      forbiddenWords,
    );
  }

  /// Récupère les challenges du joueur
  Future<List<Challenge>> getMyChallenges(String gameSessionId) async {
    final challenges = await challenge.getMyChallenges(gameSessionId);
    _challengesController.add(challenges);
    return challenges;
  }

  /// Récupère les challenges à deviner
  Future<List<Challenge>> getMyChallengesToGuess(String gameSessionId) async {
    // TODO: Add method to ChallengeManager
    return await _apiService.getMyChallengesToGuess(gameSessionId);
  }

  /// Rafraîchit les challenges créés par le joueur
  Future<void> refreshMyChallenges() async {
    if (_currentGameSession == null) return;

    try {
      _myChallenges = await challenge.getMyChallenges(_currentGameSession!.id);
      _challengesController.add(_myChallenges);
    } catch (e) {
      throw Exception('Erreur lors de l\'actualisation des challenges: $e');
    }
  }

  /// Rafraîchit les challenges à deviner
  Future<void> refreshChallengesToGuess() async {
    if (_currentGameSession == null) return;

    try {
      _challengesToGuess = await _apiService.getMyChallengesToGuess(_currentGameSession!.id);
      _challengesController.add(_challengesToGuess);
    } catch (e) {
      throw Exception('Erreur lors de l\'actualisation des challenges à deviner: $e');
    }
  }

  /// Génère une image pour un challenge
  Future<String> generateImageForChallenge(
    String gameSessionId,
    String challengeId,
    String prompt,
  ) async {
    // TODO: Add method to ChallengeManager
    return await _apiService.generateImageForChallenge(gameSessionId, challengeId, prompt);
  }

  /// Répond à un challenge
  Future<void> answerChallenge(
    String gameSessionId,
    String challengeId,
    String answer,
    bool isResolved,
  ) async {
    // TODO: Add method to ChallengeManager
    await _apiService.answerChallenge(gameSessionId, challengeId, answer, isResolved);
  }

  /// Liste tous les challenges d'une session
  Future<List<Challenge>> listSessionChallenges(String gameSessionId) async {
    return await challenge.listSessionChallenges(gameSessionId);
  }

  // --- Role Management ---

  /// Récupère le rôle du joueur actuel
  String? getCurrentPlayerRole() {
    return role.getCurrentPlayerRole(_currentPlayer, _currentGameSession);
  }

  /// Inverse les rôles de tous les joueurs
  Future<void> switchAllRoles() async {
    // TODO: Implémenter l'inversion côté backend ou local
    // Pour l'instant, juste rafraîchir
    if (_currentGameSession != null) {
      await refreshGameSession(_currentGameSession!.id);
    }
  }

  // --- Game State ---

  /// Statut actuel du jeu
  String get currentStatus => gameState.currentStatus;

  /// Vérifie si le jeu est actif
  bool get isGameActive => gameState.isGameActive;

  /// Vérifie si le jeu est terminé
  bool get isGameFinished => gameState.isGameFinished;

  // --- Score Management ---

  /// Met à jour le score d'une équipe
  void applyScoreDelta(String teamColor, int delta) {
    score.applyScoreDelta(teamColor, delta);
  }

  /// Récupère le score de l'équipe rouge
  int get redTeamScore => score.redTeamScore;

  /// Récupère le score de l'équipe bleue
  int get blueTeamScore => score.blueTeamScore;

  /// Stream des scores
  Stream<Map<String, int>> get scoreStream => score.scoreStream;

  /// Initialise les scores à 100
  void initializeScores() {
    score.initializeScores();
  }

  // --- Timer Management ---

  /// Démarre le timer de jeu (5 minutes)
  void startTimer({required void Function() onEnd}) {
    timer.start(onEnd: onEnd);
  }

  /// Arrête le timer
  void stopTimer() {
    timer.stop();
  }

  /// Temps restant en secondes
  int get remainingSeconds => timer.remainingSeconds;

  /// Stream du timer
  Stream<int> get timerStream => timer.timerStream;

  // === CLEANUP ===

  /// Libère les ressources
  void dispose() {
    _playerController.close();
    _gameSessionController.close();
    _challengesController.close();
    gameState.dispose();
    timer.dispose();
  }
}
