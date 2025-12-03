import 'dart:async';

import '../../interfaces/auth_api_interface.dart';
import '../../interfaces/facades/auth_facade_interface.dart';
import '../../models/player.dart';
import '../../utils/logger.dart';

/// Facade d'authentification (ISP + SRP)
/// Responsabilité unique: Gestion de l'authentification utilisateur
class AuthFacade implements IAuthFacade {
  final IAuthApi _authApi;

  Player? _currentPlayer;
  final StreamController<Player?> _playerController =
      StreamController<Player?>.broadcast();

  AuthFacade({required IAuthApi authApi}) : _authApi = authApi;

  @override
  Future<Player> loginWithUsername(String username) async {
    await _authApi.loginWithUsername(username);
    _currentPlayer = await _authApi.getMe();
    _playerController.add(_currentPlayer);
    AppLogger.success('[AuthFacade] Connecté en tant que: ${_currentPlayer!.name}');
    return _currentPlayer!;
  }

  @override
  Future<void> logout() async {
    await _authApi.logout();
    _currentPlayer = null;
    _playerController.add(null);
    AppLogger.info('[AuthFacade] Déconnexion effectuée');
  }

  @override
  Player? get currentPlayer => _currentPlayer;

  @override
  Stream<Player?> get playerStream => _playerController.stream;

  @override
  bool get isLoggedIn => _authApi.isLoggedIn;

  /// Initialise la facade en restaurant la session si possible
  Future<void> initialize() async {
    if (_authApi.isLoggedIn) {
      try {
        _currentPlayer = await _authApi.getMe();
        _playerController.add(_currentPlayer);
        AppLogger.success('[AuthFacade] Session restaurée pour: ${_currentPlayer!.name}');
      } catch (e) {
        AppLogger.error('[AuthFacade] Impossible de restaurer la session', e);
      }
    }
  }

  void dispose() {
    _playerController.close();
  }
}
