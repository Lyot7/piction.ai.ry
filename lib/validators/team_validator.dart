import '../models/game_session.dart';

/// Validateur pour les opérations sur les équipes
/// Principe SOLID: Single Responsibility - Uniquement la validation d'équipes
class TeamValidator {
  static const int maxPlayersPerTeam = 2;

  /// Vérifie si une équipe est complète
  static bool isTeamFull(GameSession session, String teamColor) {
    final teamPlayerCount = session.players
        .where((p) => p.color == teamColor)
        .length;

    return teamPlayerCount >= maxPlayersPerTeam;
  }

  /// Vérifie si une équipe a de la place
  static bool hasTeamSpace(GameSession session, String teamColor) {
    return !isTeamFull(session, teamColor);
  }

  /// Vérifie si les deux équipes sont complètes
  static bool areAllTeamsFull(GameSession session) {
    return isTeamFull(session, 'red') && isTeamFull(session, 'blue');
  }

  /// Vérifie si une équipe est vide
  static bool isTeamEmpty(GameSession session, String teamColor) {
    final teamPlayerCount = session.players
        .where((p) => p.color == teamColor)
        .length;

    return teamPlayerCount == 0;
  }

  /// Compte le nombre de joueurs dans une équipe
  static int getTeamPlayerCount(GameSession session, String teamColor) {
    return session.players
        .where((p) => p.color == teamColor)
        .length;
  }

  /// Obtient les statistiques des équipes
  static Map<String, int> getTeamStats(GameSession session) {
    return {
      'red': getTeamPlayerCount(session, 'red'),
      'blue': getTeamPlayerCount(session, 'blue'),
    };
  }

  /// Valide qu'un joueur peut rejoindre une équipe
  static bool canJoinTeam(GameSession session, String teamColor) {
    return hasTeamSpace(session, teamColor);
  }

  /// Valide qu'un joueur peut changer d'équipe
  static bool canSwitchTeam(
    GameSession session,
    String currentTeamColor,
    String targetTeamColor,
  ) {
    // Si le joueur change d'équipe, vérifier que l'équipe cible a de la place
    return currentTeamColor != targetTeamColor &&
           hasTeamSpace(session, targetTeamColor);
  }

  /// Obtient un message d'erreur approprié
  static String? getTeamJoinErrorMessage(
    GameSession session,
    String teamColor,
  ) {
    if (isTeamFull(session, teamColor)) {
      return 'L\'équipe est déjà complète ($maxPlayersPerTeam/$maxPlayersPerTeam)';
    }

    return null; // Pas d'erreur
  }

  /// Vérifie l'équilibre des équipes
  static bool areTeamsBalanced(GameSession session) {
    final redCount = getTeamPlayerCount(session, 'red');
    final blueCount = getTeamPlayerCount(session, 'blue');

    // Équilibrées si la différence est <= 1
    return (redCount - blueCount).abs() <= 1;
  }
}
