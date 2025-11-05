import '../models/player.dart';
import '../models/game_session.dart';
import 'logger.dart';

/// Utilitaire pour l'attribution initiale des rôles
///
/// Selon les règles du jeu:
/// - Chaque équipe a 1 Dessinateur (drawer) + 1 Devineur (guesser)
/// - Premier joueur de chaque équipe = drawer
/// - Deuxième joueur de chaque équipe = guesser
class RoleAssignment {
  /// Assigne les rôles initiaux aux joueurs d'une session
  ///
  /// Règles:
  /// - Premier joueur de chaque équipe (red/blue) = drawer
  /// - Deuxième joueur de chaque équipe (red/blue) = guesser
  ///
  /// Retourne une nouvelle GameSession avec les rôles assignés
  static GameSession assignInitialRoles(GameSession session) {
    AppLogger.info('[RoleAssignment] Attribution des rôles initiaux');

    // Vérifier que la session est prête à démarrer
    if (!session.isReadyToStart) {
      AppLogger.warning('[RoleAssignment] Session non prête (besoin de 4 joueurs, 2 par équipe)');
      return session;
    }

    final updatedPlayers = <Player>[];

    // Traiter chaque équipe séparément
    for (final teamColor in ['red', 'blue']) {
      final teamPlayers = session.players
          .where((p) => p.color == teamColor)
          .toList();

      if (teamPlayers.length != 2) {
        AppLogger.warning('[RoleAssignment] Équipe $teamColor a ${teamPlayers.length} joueurs (attendu: 2)');
        updatedPlayers.addAll(teamPlayers);
        continue;
      }

      // Attribution des rôles:
      // - Premier joueur (généralement le host de l'équipe) = drawer
      // - Deuxième joueur = guesser
      final drawer = teamPlayers[0].copyWith(role: 'drawer');
      final guesser = teamPlayers[1].copyWith(role: 'guesser');

      updatedPlayers.add(drawer);
      updatedPlayers.add(guesser);

      AppLogger.info('[RoleAssignment] Équipe $teamColor: ${drawer.name} = drawer, ${guesser.name} = guesser');
    }

    final updatedSession = session.copyWith(players: updatedPlayers);

    AppLogger.success('[RoleAssignment] Rôles assignés avec succès');
    return updatedSession;
  }

  /// Vérifie si tous les joueurs ont un rôle assigné
  static bool allPlayersHaveRoles(GameSession session) {
    return session.players.every((player) => player.role != null && player.role!.isNotEmpty);
  }

  /// Vérifie si les rôles sont correctement assignés selon les règles
  ///
  /// Règles:
  /// - Chaque équipe doit avoir exactement 1 drawer et 1 guesser
  static bool areRolesValid(GameSession session) {
    for (final teamColor in ['red', 'blue']) {
      final teamPlayers = session.players.where((p) => p.color == teamColor).toList();

      if (teamPlayers.length != 2) {
        return false;
      }

      final drawers = teamPlayers.where((p) => p.role == 'drawer').length;
      final guessers = teamPlayers.where((p) => p.role == 'guesser').length;

      if (drawers != 1 || guessers != 1) {
        AppLogger.warning('[RoleAssignment] Équipe $teamColor: drawers=$drawers, guessers=$guessers (attendu: 1 de chaque)');
        return false;
      }
    }

    return true;
  }

  /// ⚠️ DEPRECATED - NE PAS UTILISER
  ///
  /// Cette fonction n'est plus nécessaire car le jeu fonctionne avec un seul cycle
  /// et les rôles ne changent JAMAIS pendant la partie (flow simplifié).
  ///
  /// @deprecated Inutile avec le flow simplifié (1 cycle unique, pas d'inversion)
  @Deprecated('Roles ne changent pas pendant la partie - flow simplifié')
  static GameSession switchAllRoles(GameSession session) {
    AppLogger.warning('[RoleAssignment] ⚠️ switchAllRoles() called but DEPRECATED - roles should NOT change');

    final updatedPlayers = session.players.map((player) {
      return player.toggleRole();
    }).toList();

    final updatedSession = session.copyWith(players: updatedPlayers);

    return updatedSession;
  }
}
