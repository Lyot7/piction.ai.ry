import 'dart:async';

import '../../interfaces/facades/auth_facade_interface.dart';
import '../../interfaces/facades/game_state_facade_interface.dart';
import '../../interfaces/facades/session_facade_interface.dart';
import '../../managers/game_state_manager.dart';
import '../../managers/role_manager.dart';
import '../../utils/logger.dart';

/// Facade d'état du jeu (ISP + SRP)
/// Responsabilité unique: Gestion de l'état et des transitions de jeu
class GameStateFacade implements IGameStateFacade {
  final GameStateManager _gameStateManager;
  final RoleManager _roleManager;
  final IAuthFacade _authFacade;
  final ISessionFacade _sessionFacade;

  StreamSubscription? _sessionSubscription;
  bool _isAutoSyncActive = false;

  GameStateFacade({
    required GameStateManager gameStateManager,
    required RoleManager roleManager,
    required IAuthFacade authFacade,
    required ISessionFacade sessionFacade,
  })  : _gameStateManager = gameStateManager,
        _roleManager = roleManager,
        _authFacade = authFacade,
        _sessionFacade = sessionFacade;

  @override
  String get currentStatus => _gameStateManager.currentStatus;

  @override
  String? get currentPhase => _gameStateManager.currentPhase;

  @override
  bool get isGameActive => _gameStateManager.isGameActive;

  @override
  bool get isGameFinished => _gameStateManager.isGameFinished;

  @override
  Stream<String> get statusStream => _gameStateManager.statusStream;

  @override
  Stream<String?> get phaseStream => _gameStateManager.phaseStream;

  @override
  String? getCurrentPlayerRole() {
    return _roleManager.getCurrentPlayerRole(
      _authFacade.currentPlayer,
      _sessionFacade.currentGameSession,
    );
  }

  @override
  void startGame() {
    _gameStateManager.startGame();
  }

  @override
  void resetToLobby() {
    _gameStateManager.resetToLobby();
  }

  @override
  Future<void> syncWithSession() async {
    final session = _sessionFacade.currentGameSession;
    if (session != null) {
      AppLogger.info('[GameStateFacade] 🔄 Synchronizing with session - status: ${session.status}, phase: ${session.gamePhase}');
      await _gameStateManager.checkTransitions(session);
    }
  }

  @override
  void startAutoSync() {
    if (_isAutoSyncActive) {
      AppLogger.warning('[GameStateFacade] AutoSync already active');
      return;
    }

    _isAutoSyncActive = true;
    AppLogger.info('[GameStateFacade] 🚀 Starting auto-sync with session stream');

    _sessionSubscription = _sessionFacade.gameSessionStream.listen(
      (session) async {
        if (session != null) {
          AppLogger.info('[GameStateFacade] 📡 Session updated - triggering sync');
          await _gameStateManager.checkTransitions(session);
        }
      },
      onError: (error) {
        AppLogger.error('[GameStateFacade] AutoSync stream error', error);
      },
    );
  }

  @override
  void stopAutoSync() {
    if (!_isAutoSyncActive) return;

    _isAutoSyncActive = false;
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    AppLogger.info('[GameStateFacade] 🛑 Stopped auto-sync');
  }

  void dispose() {
    stopAutoSync();
    _gameStateManager.dispose();
  }
}
