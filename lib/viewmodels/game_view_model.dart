import 'dart:async';
import 'package:flutter/foundation.dart';

import '../interfaces/facades/challenge_facade_interface.dart';
import '../interfaces/facades/game_state_facade_interface.dart';
import '../interfaces/facades/score_facade_interface.dart';
import '../interfaces/facades/session_facade_interface.dart';
import '../models/challenge.dart';
import '../models/game_session.dart';
import '../utils/logger.dart';

/// ViewModel pour GameScreen (SRP)
/// Responsabilité unique: Logique métier du jeu
/// Extrait la logique de game_screen.dart (~500 LOC)
class GameViewModel extends ChangeNotifier {
  // === DEPENDENCIES ===
  final ISessionFacade _sessionFacade;
  final IChallengeFacade _challengeFacade;
  final IGameStateFacade _gameStateFacade;
  final IScoreFacade _scoreFacade;

  // === STATE ===
  List<Challenge> _challenges = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isAutoGenerating = false;
  String _currentScreenPhase = 'drawing';
  int _redTeamScore = 100;
  int _blueTeamScore = 100;
  final Set<String> _resolvedChallengeIds = {};

  // Timer state
  static const int drawingPhaseSeconds = 5 * 60;
  static const int guessingPhaseSeconds = 2 * 60;
  int _remaining = drawingPhaseSeconds;
  Timer? _timer;
  Timer? _refreshTimer;

  // === GETTERS ===
  List<Challenge> get challenges => _challenges;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAutoGenerating => _isAutoGenerating;
  String get currentScreenPhase => _currentScreenPhase;
  int get redTeamScore => _redTeamScore;
  int get blueTeamScore => _blueTeamScore;
  int get remaining => _remaining;
  Set<String> get resolvedChallengeIds => _resolvedChallengeIds;
  GameSession? get currentGameSession => _sessionFacade.currentGameSession;
  String? get currentPlayerRole => _gameStateFacade.getCurrentPlayerRole();

  GameViewModel({
    required ISessionFacade sessionFacade,
    required IChallengeFacade challengeFacade,
    required IGameStateFacade gameStateFacade,
    required IScoreFacade scoreFacade,
  })  : _sessionFacade = sessionFacade,
        _challengeFacade = challengeFacade,
        _gameStateFacade = gameStateFacade,
        _scoreFacade = scoreFacade;

  // === INITIALIZATION ===

  Future<void> initializeGame() async {
    try {
      _isLoading = true;
      notifyListeners();

      final gameSession = _sessionFacade.currentGameSession;
      final gamePhase = gameSession?.gamePhase;
      final status = gameSession?.status;

      final isGuessingPhase = gamePhase == 'guessing' || status == 'guessing';
      _currentScreenPhase = isGuessingPhase ? 'guessing' : 'drawing';

      _syncScoresFromSession(gameSession);

      AppLogger.info(
          '[GameViewModel] Phase initiale - gamePhase: $gamePhase, status: $status, screenPhase: $_currentScreenPhase');

      if (_currentScreenPhase == 'drawing') {
        await _challengeFacade.refreshMyChallenges();
        _challenges = _challengeFacade.myChallenges;
      } else {
        await _challengeFacade.refreshChallengesToGuess();
        _challenges = _challengeFacade.challengesToGuess;
      }

      AppLogger.info('[GameViewModel] ${_challenges.length} challenges chargés');

      _remaining = _currentScreenPhase == 'guessing'
          ? guessingPhaseSeconds
          : drawingPhaseSeconds;

      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      AppLogger.error('[GameViewModel] Erreur initialisation', e);
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // === TIMER MANAGEMENT ===

  void startTimer({required void Function() onTimerEnd}) {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        timer.cancel();
        onTimerEnd();
      } else {
        _remaining--;
        notifyListeners();
      }
    });
  }

  void startRefreshTimer({required Future<void> Function() onRefresh}) {
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await onRefresh();
    });
  }

  void stopTimers() {
    _timer?.cancel();
    _refreshTimer?.cancel();
  }

  // === CHALLENGE REFRESH ===

  Future<bool> refreshChallenges() async {
    try {
      final gameSession = _sessionFacade.currentGameSession;
      if (gameSession == null) return false;

      await _sessionFacade.refreshGameSession(gameSession.id);
      final updatedSession = _sessionFacade.currentGameSession;
      if (updatedSession == null) return false;

      _syncScoresFromSession(updatedSession);

      final gamePhase = updatedSession.gamePhase;
      final status = updatedSession.status;
      final isGuessingPhase = gamePhase == 'guessing' || status == 'guessing';
      final shouldTransition = _currentScreenPhase == 'drawing' && isGuessingPhase;

      if (_currentScreenPhase == 'drawing' && !isGuessingPhase) {
        await _challengeFacade.refreshMyChallenges();
        _challenges = _challengeFacade.myChallenges;
        notifyListeners();
      } else if (_currentScreenPhase == 'guessing') {
        await _challengeFacade.refreshChallengesToGuess();
        _challenges = _challengeFacade.challengesToGuess;
        notifyListeners();
      }

      return shouldTransition;
    } catch (e) {
      AppLogger.error('[GameViewModel] Erreur refresh challenges', e);
      return false;
    }
  }

  // === SCORE MANAGEMENT ===

  void _syncScoresFromSession(GameSession? session) {
    if (session == null) return;

    final redScore = session.teamScores['red'] ?? 100;
    final blueScore = session.teamScores['blue'] ?? 100;

    // Ne mettre à jour que si les scores ont changé
    if (_redTeamScore != redScore || _blueTeamScore != blueScore) {
      _redTeamScore = redScore;
      _blueTeamScore = blueScore;

      // Synchroniser avec la facade sans reset
      _scoreFacade.setTeamScore('red', redScore);
      _scoreFacade.setTeamScore('blue', blueScore);

      AppLogger.info('[GameViewModel] Scores synchronisés depuis session: red=$redScore, blue=$blueScore');
    }
  }

  void applyScoreDelta(String teamColor, int delta) {
    _scoreFacade.applyScoreDelta(teamColor, delta);
    if (teamColor == 'red') {
      _redTeamScore += delta;
    } else {
      _blueTeamScore += delta;
    }
    notifyListeners();
  }

  // === AUTO-GENERATION ===

  void setAutoGenerating(bool value) {
    _isAutoGenerating = value;
    notifyListeners();
  }

  // === CHALLENGE RESOLUTION ===

  void markChallengeResolved(String challengeId) {
    _resolvedChallengeIds.add(challengeId);
    notifyListeners();
  }

  bool isChallengeResolved(String challengeId) {
    return _resolvedChallengeIds.contains(challengeId);
  }

  // === GAME STATUS ===

  bool get allImagesReady {
    return _challenges.isNotEmpty &&
        _challenges.every((c) => c.imageUrl != null && c.imageUrl!.isNotEmpty);
  }

  bool get allChallengesResolved {
    return _challenges.isNotEmpty &&
        _challenges.every((c) => _resolvedChallengeIds.contains(c.id));
  }

  // === CLEANUP ===

  @override
  void dispose() {
    stopTimers();
    super.dispose();
  }
}
