import '../models/player.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

/// Repository pour les opérations sur les joueurs
/// Principe SOLID: Single Responsibility + Dependency Inversion
/// Abstrait l'accès aux données des joueurs
class PlayerRepository {
  final ApiService _apiService;

  PlayerRepository(this._apiService);

  /// Crée un nouveau joueur
  Future<Player> createPlayer(String name, String password) async {
    try {
      AppLogger.info('[PlayerRepository] Création du joueur: $name');
      return await _apiService.createPlayer(name, password);
    } catch (e) {
      AppLogger.error('[PlayerRepository] Erreur création joueur', e);
      rethrow;
    }
  }

  /// Récupère un joueur par son ID
  Future<Player> getPlayer(String playerId) async {
    try {
      return await _apiService.getPlayer(playerId);
    } catch (e) {
      AppLogger.error('[PlayerRepository] Erreur récupération joueur $playerId', e);
      rethrow;
    }
  }

  /// Récupère les informations du joueur connecté
  Future<Player> getMe() async {
    try {
      return await _apiService.getMe();
    } catch (e) {
      AppLogger.error('[PlayerRepository] Erreur récupération joueur connecté', e);
      rethrow;
    }
  }
}
