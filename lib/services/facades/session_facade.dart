import 'dart:async';

import '../../interfaces/facades/auth_facade_interface.dart';
import '../../interfaces/facades/session_facade_interface.dart';
import '../../interfaces/session_api_interface.dart';
import '../../managers/role_manager.dart';
import '../../managers/team_manager.dart';
import '../../models/game_session.dart';
import '../../utils/logger.dart';

/// Facade de sessions (ISP + SRP)
/// Responsabilité unique: Gestion des sessions de jeu
class SessionFacade implements ISessionFacade {
  final ISessionApi _sessionApi;
  final IAuthFacade _authFacade;
  final TeamManager _teamManager;
  final RoleManager _roleManager;

  GameSession? _currentGameSession;
  final StreamController<GameSession?> _gameSessionController =
      StreamController<GameSession?>.broadcast();

  SessionFacade({
    required ISessionApi sessionApi,
    required IAuthFacade authFacade,
    required TeamManager teamManager,
    required RoleManager roleManager,
  })  : _sessionApi = sessionApi,
        _authFacade = authFacade,
        _teamManager = teamManager,
        _roleManager = roleManager;

  @override
  Future<GameSession> createGameSession() async {
    _currentGameSession = await _sessionApi.createGameSession();

    // S'assurer que le créateur est marqué comme host
    if (_currentGameSession!.hostId == null && _authFacade.currentPlayer != null) {
      AppLogger.info('[SessionFacade] Setting hostId to current player');
      _currentGameSession =
          _currentGameSession!.copyWith(hostId: _authFacade.currentPlayer!.id);
    }

    _gameSessionController.add(_currentGameSession);
    return _currentGameSession!;
  }

  @override
  Future<void> joinGameSession(String gameSessionId, String color) async {
    await _sessionApi.joinGameSession(gameSessionId, color);
    await refreshGameSession(gameSessionId);
  }

  @override
  Future<void> joinAvailableTeam(String gameSessionId) async {
    if (_authFacade.currentPlayer == null) {
      throw Exception('Vous devez être connecté pour rejoindre une équipe');
    }

    final gameSession = await _sessionApi.getGameSession(gameSessionId);
    final redCount = gameSession.players.where((p) => p.color == 'red').length;
    final blueCount = gameSession.players.where((p) => p.color == 'blue').length;

    String color;
    if (redCount <= blueCount && redCount < 2) {
      color = 'red';
    } else if (blueCount < 2) {
      color = 'blue';
    } else {
      color = 'red';
    }

    await joinGameSession(gameSessionId, color);
  }

  @override
  Future<void> refreshGameSession(String gameSessionId) async {
    final previousHostId = _currentGameSession?.hostId;

    _currentGameSession = await _sessionApi.getGameSession(gameSessionId);

    // Préserver le hostId si le backend ne le renvoie pas
    if (_currentGameSession != null &&
        _currentGameSession!.hostId == null &&
        previousHostId != null) {
      _currentGameSession = _currentGameSession!.copyWith(hostId: previousHostId);
    }

    _gameSessionController.add(_currentGameSession);
  }

  @override
  Future<void> leaveGameSession() async {
    if (_currentGameSession != null) {
      await _sessionApi.leaveGameSession(_currentGameSession!.id);
      _currentGameSession = null;
      _gameSessionController.add(null);
    }
  }

  @override
  Future<void> startGameSession() async {
    if (_currentGameSession == null) {
      throw Exception('Aucune session active');
    }

    if (_currentGameSession!.status != 'lobby') {
      AppLogger.warning('[SessionFacade] La session est déjà en cours');
      return;
    }

    try {
      await _sessionApi.startGameSession(_currentGameSession!.id);
      await refreshGameSession(_currentGameSession!.id);

      // Assigner les rôles si nécessaire
      if (_currentGameSession != null) {
        final allHaveRoles = _roleManager.allPlayersHaveRoles(_currentGameSession!);

        if (!allHaveRoles) {
          AppLogger.warning('[SessionFacade] Attribution locale des rôles');
          _currentGameSession = _roleManager.assignInitialRoles(_currentGameSession!);
          _gameSessionController.add(_currentGameSession);
        }

        // Initialiser la phase
        _currentGameSession = _currentGameSession!.copyWith(gamePhase: 'drawing');
        _gameSessionController.add(_currentGameSession);
      }

      AppLogger.success('[SessionFacade] Session démarrée avec succès');
    } catch (e) {
      AppLogger.error('[SessionFacade] Erreur lors du démarrage', e);
      throw Exception('Erreur lors du démarrage de la session: $e');
    }
  }

  @override
  Future<void> changeTeam(String gameSessionId, String newTeamColor) async {
    if (_authFacade.currentPlayer == null) {
      throw Exception('Aucun joueur connecté');
    }
    await _teamManager.changeTeam(gameSessionId, newTeamColor);
    await refreshGameSession(gameSessionId);
  }

  @override
  GameSession? get currentGameSession => _currentGameSession;

  @override
  Stream<GameSession?> get gameSessionStream => _gameSessionController.stream;

  void dispose() {
    _gameSessionController.close();
  }
}
