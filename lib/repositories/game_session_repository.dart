import '../models/game_session.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

/// Repository pour les opérations sur les sessions de jeu
/// Principe SOLID: Single Responsibility + Dependency Inversion
/// Abstrait l'accès aux données des sessions
class GameSessionRepository {
  final ApiService _apiService;

  GameSessionRepository(this._apiService);

  /// Crée une nouvelle session de jeu
  Future<GameSession> createGameSession() async {
    try {
      AppLogger.info('[GameSessionRepository] Création d\'une session');
      return await _apiService.createGameSession();
    } catch (e) {
      AppLogger.error('[GameSessionRepository] Erreur création session', e);
      rethrow;
    }
  }

  /// Récupère une session par son ID
  Future<GameSession> getGameSession(String gameSessionId) async {
    try {
      return await _apiService.getGameSession(gameSessionId);
    } catch (e) {
      AppLogger.error('[GameSessionRepository] Erreur récupération session $gameSessionId', e);
      rethrow;
    }
  }

  /// Récupère le statut d'une session
  Future<String> getGameSessionStatus(String gameSessionId) async {
    try {
      return await _apiService.getGameSessionStatus(gameSessionId);
    } catch (e) {
      AppLogger.error('[GameSessionRepository] Erreur récupération statut session $gameSessionId', e);
      rethrow;
    }
  }

  /// Rejoint une session existante
  Future<void> joinGameSession(String gameSessionId, String color) async {
    try {
      AppLogger.info('[GameSessionRepository] Join session $gameSessionId avec couleur $color');
      await _apiService.joinGameSession(gameSessionId, color);
    } catch (e) {
      AppLogger.error('[GameSessionRepository] Erreur join session', e);
      rethrow;
    }
  }

  /// Quitte une session
  Future<void> leaveGameSession(String gameSessionId) async {
    try {
      AppLogger.info('[GameSessionRepository] Leave session $gameSessionId');
      await _apiService.leaveGameSession(gameSessionId);
    } catch (e) {
      AppLogger.error('[GameSessionRepository] Erreur leave session', e);
      rethrow;
    }
  }

  /// Démarre une session de jeu
  Future<void> startGameSession(String gameSessionId) async {
    try {
      AppLogger.info('[GameSessionRepository] Start session $gameSessionId');
      await _apiService.startGameSession(gameSessionId);
    } catch (e) {
      AppLogger.error('[GameSessionRepository] Erreur start session', e);
      rethrow;
    }
  }
}
