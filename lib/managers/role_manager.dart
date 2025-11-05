import '../models/game_session.dart';
import '../models/player.dart';
import '../utils/role_assignment.dart';

/// Manager pour la gestion des rôles (drawer/guesser)
/// Principe SOLID: Single Responsibility - Uniquement les rôles
///
/// **IMPORTANT**: Les rôles sont attribués UNE SEULE FOIS au début du jeu
/// et ne changent JAMAIS pendant la partie (flow simplifié avec 1 cycle unique).
///
/// Flow simplifié:
/// 1. Attribution initiale des rôles (1er joueur de chaque équipe = drawer, 2ème = guesser)
/// 2. Phase drawing: TOUS les drawers dessinent EN MÊME TEMPS
/// 3. Phase guessing: TOUS les guessers devinent EN MÊME TEMPS
/// 4. Jeu terminé (pas de cycles supplémentaires, pas d'inversion)
class RoleManager {
  /// Retourne le rôle actuel du joueur courant
  String? getCurrentPlayerRole(Player? currentPlayer, GameSession? currentSession) {
    if (currentPlayer == null || currentSession == null) return null;

    final player = currentSession.players
        .where((p) => p.id == currentPlayer.id)
        .firstOrNull;

    return player?.role;
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
