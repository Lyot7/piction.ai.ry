import '../models/game_session.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

/// Manager pour la gestion des sessions de jeu
/// Principe SOLID: Single Responsibility - Uniquement les sessions
class SessionManager {
  final ApiService _apiService;

  SessionManager(this._apiService);

  /// Crée une nouvelle session de jeu
  Future<GameSession> createGameSession() async {
    try {
      AppLogger.info('[SessionManager] Création d\'une nouvelle session');

      final session = await _apiService.createGameSession();

      AppLogger.success('[SessionManager] Session créée: ${session.id}');
      return session;
    } catch (e) {
      AppLogger.error('[SessionManager] Erreur création session', e);
      throw Exception('Erreur lors de la création de la session: $e');
    }
  }

  /// Rejoint une session existante
  Future<void> joinGameSession(String gameSessionId, String color) async {
    try {
      AppLogger.info('[SessionManager] Rejoindre la session $gameSessionId (équipe: $color)');

      await _apiService.joinGameSession(gameSessionId, color);

      AppLogger.success('[SessionManager] Session rejointe: $gameSessionId');
    } catch (e) {
      AppLogger.error('[SessionManager] Erreur rejoindre session', e);
      throw Exception('Erreur lors de la connexion à la session: $e');
    }
  }

  /// Actualise les informations de la session avec retry automatique
  Future<GameSession> refreshGameSession(String gameSessionId, {int maxRetries = 3}) async {
    int attempt = 0;
    Exception? lastError;

    while (attempt < maxRetries) {
      try {
        final session = await _apiService.getGameSession(gameSessionId);
        return session;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        attempt++;

        // Vérifier si c'est une erreur réseau transitoire
        final errorMessage = e.toString().toLowerCase();
        final isTransientError = errorMessage.contains('connection closed') ||
            errorMessage.contains('connection reset') ||
            errorMessage.contains('timeout') ||
            errorMessage.contains('socket') ||
            errorMessage.contains('network');

        if (isTransientError && attempt < maxRetries) {
          // Délai rapide et progressif: 100ms, 200ms, 300ms
          final delayMs = 100 * attempt;
          await Future.delayed(Duration(milliseconds: delayMs));
        } else if (!isTransientError) {
          throw Exception('Erreur lors de l\'actualisation de la session: $e');
        }
      }
    }

    throw Exception('Erreur lors de l\'actualisation de la session après $maxRetries tentatives: $lastError');
  }

  /// Obtient le statut de la session
  Future<String> getGameSessionStatus(String gameSessionId) async {
    try {
      return await _apiService.getGameSessionStatus(gameSessionId);
    } catch (e) {
      AppLogger.error('[SessionManager] Erreur récupération statut', e);
      throw Exception('Erreur lors de la récupération du statut: $e');
    }
  }

  /// Démarre la session de jeu
  Future<void> startGameSession(String gameSessionId) async {
    try {
      AppLogger.info('[SessionManager] Démarrage de la session: $gameSessionId');

      await _apiService.startGameSession(gameSessionId);

      AppLogger.success('[SessionManager] Session démarrée: $gameSessionId');
    } catch (e) {
      AppLogger.error('[SessionManager] Erreur démarrage session', e);
      throw Exception('Erreur lors du démarrage de la session: $e');
    }
  }

  /// Quitte la session actuelle
  Future<void> leaveGameSession(String gameSessionId) async {
    try {
      AppLogger.info('[SessionManager] Quitter la session: $gameSessionId');

      await _apiService.leaveGameSession(gameSessionId);

      AppLogger.success('[SessionManager] Session quittée: $gameSessionId');
    } catch (e) {
      AppLogger.error('[SessionManager] Erreur quitter session', e);
      throw Exception('Erreur lors de la déconnexion de la session: $e');
    }
  }
}
