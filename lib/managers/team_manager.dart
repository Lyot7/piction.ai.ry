import '../interfaces/session_api_interface.dart';
import '../models/game_session.dart';
import '../utils/logger.dart';

/// Manager pour la gestion des équipes
/// Principe SOLID: Single Responsibility - Uniquement les équipes
/// Migré vers ISessionApi (SOLID DIP) - n'utilise plus ApiService legacy
class TeamManager {
  final ISessionApi _sessionApi;

  // Gestion des appels en cours pour éviter les race conditions
  Future<void>? _pendingTeamChange;

  // Cache local de la dernière session (pour les stats d'équipe)
  GameSession? _cachedSession;

  TeamManager(this._sessionApi);

  /// Trouve une couleur d'équipe disponible automatiquement
  Future<String> getAvailableTeamColor(String gameSessionId) async {
    try {
      final session = await _sessionApi.getGameSession(gameSessionId);
      _cachedSession = session;

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
      AppLogger.warning('[TeamManager] Changement d\'équipe déjà en cours, ignoré');
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
      AppLogger.warning('[TeamManager] Erreur transitoire ignorée: $errorMessage');
    }
  }

  /// Version robuste du changement d'équipe (optimisée)
  Future<void> _safeChangeTeam(String gameSessionId, String newColor) async {
    try {
      AppLogger.info('[TeamManager] Changement équipe: leave puis join $newColor');

      // Appels API en séquence rapide (pas de refresh entre)
      await _sessionApi.leaveGameSession(gameSessionId);
      await _sessionApi.joinGameSession(gameSessionId, newColor);

      // Un seul refresh à la fin pour mettre à jour le cache
      _cachedSession = await _sessionApi.getGameSession(gameSessionId);

      AppLogger.success('[TeamManager] Changement équipe réussi vers $newColor');
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();

      if (errorMessage.contains('already in game session') ||
          errorMessage.contains('player already in') ||
          errorMessage.contains('already in room')) {
        // Déjà dans la session, juste changer d'équipe
        try {
          AppLogger.info('[TeamManager] Déjà dans session, tentative join direct');
          await _sessionApi.joinGameSession(gameSessionId, newColor);
          _cachedSession = await _sessionApi.getGameSession(gameSessionId);
        } catch (joinError) {
          AppLogger.error('[TeamManager] Échec join direct', joinError);
          await safeJoinGameSession(gameSessionId, newColor);
        }
      } else if (errorMessage.contains('not in game session') ||
                 errorMessage.contains('player not in')) {
        // Pas dans la session, juste joindre
        AppLogger.info('[TeamManager] Pas dans session, join simple');
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
      _cachedSession = await _sessionApi.getGameSession(gameSessionId);

      // Vérifier que le joueur est bien dans la session après le join
      final playerInSession = _cachedSession?.players
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
      await _sessionApi.joinGameSession(gameSessionId, color);
      _cachedSession = await _sessionApi.getGameSession(gameSessionId);
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();

      if (errorMessage.contains('already in game session') ||
          errorMessage.contains('player already in') ||
          errorMessage.contains('already in room')) {
        // Déjà dans la session, essayer leave puis join
        try {
          AppLogger.info('[TeamManager] safeJoin: leave puis rejoin');
          await _sessionApi.leaveGameSession(gameSessionId);
          await _sessionApi.joinGameSession(gameSessionId, color);
          _cachedSession = await _sessionApi.getGameSession(gameSessionId);
        } catch (leaveJoinError) {
          _cachedSession = await _sessionApi.getGameSession(gameSessionId);
          rethrow;
        }
      } else if (errorMessage.contains('not in game session') ||
                 errorMessage.contains('player not in')) {
        // Pas dans la session, refresh puis join
        try {
          AppLogger.info('[TeamManager] safeJoin: refresh puis join');
          _cachedSession = await _sessionApi.getGameSession(gameSessionId);
          await _sessionApi.joinGameSession(gameSessionId, color);
          _cachedSession = await _sessionApi.getGameSession(gameSessionId);
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
