import 'dart:async';
import 'package:flutter/foundation.dart';

import '../interfaces/facades/auth_facade_interface.dart';
import '../interfaces/facades/session_facade_interface.dart';
import '../models/game_session.dart';
import '../models/player.dart';
import '../utils/logger.dart';

/// ViewModel pour LobbyScreen (SRP)
/// Responsabilité unique: Logique métier du lobby
/// Extrait la logique de lobby_screen.dart (~400 LOC)
class LobbyViewModel extends ChangeNotifier {
  // === DEPENDENCIES ===
  final IAuthFacade _authFacade;
  final ISessionFacade _sessionFacade;

  // === STATE ===
  bool _isLoading = false;
  String? _errorMessage;
  bool _isChangingTeam = false;
  final Map<String, String> _playersTransitioning = {};
  Timer? _pollingTimer;

  // === GETTERS ===
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isChangingTeam => _isChangingTeam;
  Map<String, String> get playersTransitioning => _playersTransitioning;

  GameSession? get currentGameSession => _sessionFacade.currentGameSession;
  Player? get currentPlayer => _authFacade.currentPlayer;

  Stream<GameSession?> get gameSessionStream => _sessionFacade.gameSessionStream;

  LobbyViewModel({
    required IAuthFacade authFacade,
    required ISessionFacade sessionFacade,
  })  : _authFacade = authFacade,
        _sessionFacade = sessionFacade;

  // === HOST CHECK ===

  bool get isHost {
    final session = _sessionFacade.currentGameSession;
    final player = _authFacade.currentPlayer;
    if (session == null || player == null) return false;

    if (session.hostId != null) {
      return session.isPlayerHost(player.id);
    }

    final playerInSession = session.players.firstWhere(
      (p) => p.id == player.id,
      orElse: () => player,
    );
    return playerInSession.isHost;
  }

  // === START GAME ===

  bool canStartGame() {
    final session = _sessionFacade.currentGameSession;
    if (session == null) return false;
    return isHost && session.isReadyToStart;
  }

  Future<bool> startGame() async {
    if (!canStartGame()) return false;

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _sessionFacade.startGameSession();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('[LobbyViewModel] Erreur démarrage', e);
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // === TEAM MANAGEMENT ===

  Future<void> handleTeamClick(String teamColor, bool isCurrentPlayerInThisTeam) async {
    if (_isChangingTeam) return;

    try {
      if (isCurrentPlayerInThisTeam) {
        // Déjà dans cette équipe, ne rien faire
        return;
      }

      final session = _sessionFacade.currentGameSession;
      if (session == null) return;

      final teamPlayers = session.players.where((p) => p.color == teamColor).length;
      if (teamPlayers >= 2) {
        _errorMessage = 'Cette équipe est complète (2/2)';
        notifyListeners();
        return;
      }

      await changeTeam(teamColor);
    } catch (e) {
      AppLogger.error('[LobbyViewModel] Erreur changement équipe', e);
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> changeTeam(String newTeamColor) async {
    final session = _sessionFacade.currentGameSession;
    if (session == null) return;

    try {
      _isChangingTeam = true;
      _errorMessage = null;
      notifyListeners();

      await _sessionFacade.changeTeam(session.id, newTeamColor);

      _isChangingTeam = false;
      notifyListeners();
    } catch (e) {
      AppLogger.error('[LobbyViewModel] Erreur changeTeam', e);
      _isChangingTeam = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // === POLLING ===

  void startPolling({int intervalSeconds = 3}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => refreshSession(),
    );
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  Future<void> refreshSession() async {
    final session = _sessionFacade.currentGameSession;
    if (session == null) return;

    try {
      await _sessionFacade.refreshGameSession(session.id);
      notifyListeners();
    } catch (e) {
      AppLogger.error('[LobbyViewModel] Erreur refresh', e);
    }
  }

  // === LEAVE SESSION ===

  Future<void> leaveSession() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _sessionFacade.leaveGameSession();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      AppLogger.error('[LobbyViewModel] Erreur leave', e);
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // === PLAYER IN TEAM CHECK ===

  bool isPlayerInTeam(String teamColor) {
    final session = _sessionFacade.currentGameSession;
    final player = _authFacade.currentPlayer;
    if (session == null || player == null) return false;

    return session.players.any((p) => p.id == player.id && p.color == teamColor);
  }

  List<Player> getTeamPlayers(String teamColor) {
    final session = _sessionFacade.currentGameSession;
    if (session == null) return [];
    return session.getTeamPlayers(teamColor);
  }

  // === CLEANUP ===

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
