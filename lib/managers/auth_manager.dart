import '../models/player.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

/// Manager pour la gestion de l'authentification
/// Principe SOLID: Single Responsibility - Uniquement l'authentification
class AuthManager {
  final ApiService _apiService;

  AuthManager(this._apiService);

  /// Crée un compte et se connecte
  Future<Player> createAccountAndLogin(String name, String password) async {
    try {
      AppLogger.info('[AuthManager] Création du compte: $name');

      // Créer le joueur
      await _apiService.createPlayer(name, password);

      // Se connecter
      await _apiService.login(name, password);

      // Récupérer les infos
      final player = await _apiService.getMe();
      AppLogger.success('[AuthManager] Compte créé et connecté: ${player.name}');

      return player;
    } catch (e) {
      AppLogger.error('[AuthManager] Erreur création compte', e);
      throw Exception('Erreur lors de la création du compte: $e');
    }
  }

  /// Se connecte avec un compte existant
  Future<Player> login(String name, String password) async {
    try {
      AppLogger.info('[AuthManager] Connexion: $name');

      await _apiService.login(name, password);
      final player = await _apiService.getMe();

      AppLogger.success('[AuthManager] Connecté: ${player.name}');
      return player;
    } catch (e) {
      AppLogger.error('[AuthManager] Erreur connexion', e);
      throw Exception('Erreur de connexion: $e');
    }
  }

  /// Se connecte avec juste un nom d'utilisateur
  Future<Player> loginWithUsername(String username) async {
    try {
      AppLogger.info('[AuthManager] Connexion avec username: $username');

      await _apiService.loginWithUsername(username);
      final player = await _apiService.getMe();

      AppLogger.success('[AuthManager] Connecté: ${player.name}');
      return player;
    } catch (e) {
      AppLogger.error('[AuthManager] Erreur connexion username', e);
      throw Exception('Erreur de connexion: $e');
    }
  }

  /// Déconnecte l'utilisateur
  Future<void> logout() async {
    try {
      AppLogger.info('[AuthManager] Déconnexion');
      await _apiService.logout();
      AppLogger.success('[AuthManager] Déconnecté');
    } catch (e) {
      AppLogger.error('[AuthManager] Erreur déconnexion', e);
      throw Exception('Erreur lors de la déconnexion: $e');
    }
  }

  /// Vérifie si l'utilisateur est connecté
  bool get isLoggedIn => _apiService.isLoggedIn;
}
