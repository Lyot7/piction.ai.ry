import '../models/game_session.dart';
import '../models/player.dart';
import '../utils/logger.dart';
import '../utils/role_assignment.dart';

/// Manager pour la gestion des rôles (drawer/guesser)
/// Principe SOLID: Single Responsibility - Uniquement les rôles
class RoleManager {
  /// Retourne le rôle actuel du joueur courant
  String? getCurrentPlayerRole(Player? currentPlayer, GameSession? currentSession) {
    if (currentPlayer == null || currentSession == null) return null;

    final player = currentSession.players
        .where((p) => p.id == currentPlayer.id)
        .firstOrNull;

    return player?.role;
  }

  /// Vérifie si c'est le tour du joueur actuel
  bool isMyTurn(Player? currentPlayer, GameSession? currentSession) {
    if (currentPlayer == null || currentSession == null) return false;

    final player = currentSession.players
        .where((p) => p.id == currentPlayer.id)
        .firstOrNull;

    // C'est le tour du joueur s'il est drawer
    return player?.isDrawer ?? false;
  }

  /// Inverse les rôles de tous les joueurs (drawer <-> guesser)
  /// Note: L'inversion réelle est gérée par le backend
  Future<void> switchAllRoles() async {
    // Cette méthode peut être utilisée pour notifier le backend
    // si nécessaire dans le futur
    AppLogger.info('[RoleManager] Inversion des rôles demandée');
  }

  /// Détermine le rôle d'un joueur spécifique dans une session
  String? getPlayerRole(String playerId, GameSession session) {
    final player = session.players
        .where((p) => p.id == playerId)
        .firstOrNull;

    return player?.role;
  }

  /// Vérifie si un joueur est le dessinateur
  bool isPlayerDrawer(String playerId, GameSession session) {
    return getPlayerRole(playerId, session) == 'drawer';
  }

  /// Vérifie si un joueur est le devineur
  bool isPlayerGuesser(String playerId, GameSession session) {
    return getPlayerRole(playerId, session) == 'guesser';
  }

  /// Assigne les rôles initiaux aux joueurs d'une session
  /// Délègue à RoleAssignment pour la logique
  GameSession assignInitialRoles(GameSession session) {
    return RoleAssignment.assignInitialRoles(session);
  }

  /// Vérifie si tous les joueurs ont un rôle assigné
  bool allPlayersHaveRoles(GameSession session) {
    return RoleAssignment.allPlayersHaveRoles(session);
  }

  /// Vérifie si les rôles sont correctement assignés selon les règles
  bool areRolesValid(GameSession session) {
    return RoleAssignment.areRolesValid(session);
  }
}
