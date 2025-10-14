import '../models/game_session.dart';
import 'session_manager.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

/// Manager pour la gestion des équipes
/// Principe SOLID: Single Responsibility - Uniquement les équipes
class TeamManager {
  final ApiService _apiService;
  final SessionManager _sessionManager;

  // Gestion des appels en cours pour éviter les race conditions
  Future<void>? _pendingTeamChange;

  TeamManager(this._apiService, this._sessionManager);

  /// Trouve une couleur d'équipe disponible automatiquement
  Future<String> getAvailableTeamColor(String gameSessionId) async {
    try {
      final session = await _sessionManager.refreshGameSession(gameSessionId);
      final redCount = session.players.where((p) => p.color == 'red').length;
      final blueCount = session.players.where((p) => p.color == 'blue').length;

      // Attribuer à l'équipe avec le moins de joueurs
      if (redCount <= blueCount && redCount < 2) {
        return 'red';
      } else if (blueCount < 2) {
        return 'blue';
      }

      // Si les deux équipes sont pleines, choisir rouge par défaut
      return 'red';
    } catch (e) {
      AppLogger.warning('[TeamManager] Erreur récupération couleur disponible, défaut: red');
      // En cas d'erreur, attribuer rouge par défaut
      return 'red';
    }
  }

  /// Change d'équipe dans la session actuelle (optimisé, annule les appels précédents)
  Future<void> changeTeam(String gameSessionId, String newColor) async {
    // Si un changement d'équipe est déjà en cours, on ignore ce nouveau changement
    if (_pendingTeamChange != null) {
      return;
    }

    // Marquer qu'un changement est en cours
    _pendingTeamChange = _performTeamChange(gameSessionId, newColor);

    try {
      await _pendingTeamChange;
    } finally {
      _pendingTeamChange = null;
    }
  }

  /// Effectue le changement d'équipe réel
  Future<void> _performTeamChange(String gameSessionId, String newColor) async {
    try {
      // Effectuer le changement côté serveur de manière optimisée
      await _safeChangeTeam(gameSessionId, newColor);
    } catch (e) {
      // En cas d'erreur, le refresh automatique du lobby s'en chargera
      final errorMessage = e.toString().toLowerCase();
      if (!errorMessage.contains('already in') &&
          !errorMessage.contains('connection') &&
          !errorMessage.contains('timeout')) {
        rethrow;
      }
      // Pour les erreurs transitoires, on ignore silencieusement
    }
  }

  /// Version robuste du changement d'équipe (optimisée)
  Future<void> _safeChangeTeam(String gameSessionId, String newColor) async {
    try {
      // Appels API en séquence rapide (pas de refresh entre)
      await _apiService.leaveGameSession(gameSessionId);
      await _apiService.joinGameSession(gameSessionId, newColor);

      // Un seul refresh à la fin
      await _sessionManager.refreshGameSession(gameSessionId);
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();

      if (errorMessage.contains('already in game session') ||
          errorMessage.contains('player already in') ||
          errorMessage.contains('already in room')) {
        try {
          await _apiService.joinGameSession(gameSessionId, newColor);
          await _sessionManager.refreshGameSession(gameSessionId);
        } catch (joinError) {
          await safeJoinGameSession(gameSessionId, newColor);
        }
      } else if (errorMessage.contains('not in game session') ||
                 errorMessage.contains('player not in')) {
        await safeJoinGameSession(gameSessionId, newColor);
      } else {
        rethrow;
      }
    }
  }

  /// Rejoint automatiquement une équipe disponible (sans spécifier de couleur)
  Future<void> joinAvailableTeam(String gameSessionId, String currentPlayerId) async {
    try {
      AppLogger.info('[TeamManager] Attribution automatique d\'équipe');

      final availableColor = await getAvailableTeamColor(gameSessionId);
      AppLogger.info('[TeamManager] Couleur d\'équipe attribuée: $availableColor');

      await safeJoinGameSession(gameSessionId, availableColor);
      await _sessionManager.refreshGameSession(gameSessionId);

      // Vérifier que le joueur est bien dans la session après le join
      final session = await _sessionManager.refreshGameSession(gameSessionId);
      final playerInSession = session.players
          .where((p) => p.id == currentPlayerId)
          .firstOrNull;

      if (playerInSession != null) {
        AppLogger.success('[TeamManager] Joueur trouvé dans la session: ${playerInSession.name}');
      } else {
        AppLogger.warning('[TeamManager] Joueur non trouvé dans la session après join');
      }
    } catch (e) {
      AppLogger.error('[TeamManager] Erreur attribution équipe', e);
      throw Exception('Erreur lors de l\'attribution automatique d\'équipe: $e');
    }
  }

  /// Version "safe" de joinGameSession qui gère la désynchronisation client/serveur
  Future<void> safeJoinGameSession(String gameSessionId, String color) async {
    try {
      await _apiService.joinGameSession(gameSessionId, color);
      try {
        await _sessionManager.refreshGameSession(gameSessionId);
      } catch (refreshError) {
        final refreshErrorMsg = refreshError.toString().toLowerCase();
        if (refreshErrorMsg.contains('connection closed') ||
            refreshErrorMsg.contains('timeout') ||
            refreshErrorMsg.contains('network')) {
          return; // Join réussi, le refresh sera retenté par le lobby
        } else {
          rethrow;
        }
      }
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();

      if (errorMessage.contains('already in game session') ||
          errorMessage.contains('player already in') ||
          errorMessage.contains('already in room')) {
        try {
          await _apiService.leaveGameSession(gameSessionId);
          await _apiService.joinGameSession(gameSessionId, color);
          await _sessionManager.refreshGameSession(gameSessionId);
        } catch (leaveJoinError) {
          await _sessionManager.refreshGameSession(gameSessionId);
          rethrow;
        }
      } else if (errorMessage.contains('not in game session') ||
                 errorMessage.contains('player not in')) {
        try {
          await _sessionManager.refreshGameSession(gameSessionId);
          await _apiService.joinGameSession(gameSessionId, color);
          await _sessionManager.refreshGameSession(gameSessionId);
        } catch (notInSessionError) {
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }

  /// Obtient les statistiques des équipes
  Map<String, int> getTeamStats(GameSession session) {
    final redCount = session.players.where((p) => p.color == 'red').length;
    final blueCount = session.players.where((p) => p.color == 'blue').length;

    return {'red': redCount, 'blue': blueCount};
  }
}
