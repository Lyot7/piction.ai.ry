import '../models/game_session.dart';
import 'team_validator.dart';

/// Validateur pour les sessions de jeu
/// Principe SOLID: Single Responsibility - Uniquement la validation de sessions
class SessionValidator {
  static const int requiredPlayerCount = 4;
  static const int playersPerTeam = 2;

  /// Vérifie si la session est prête à démarrer
  static bool isReadyToStart(GameSession session) {
    // Vérifier qu'il y a exactement 4 joueurs
    if (session.players.length != requiredPlayerCount) {
      return false;
    }

    // Vérifier que chaque équipe a exactement 2 joueurs
    final redCount = TeamValidator.getTeamPlayerCount(session, 'red');
    final blueCount = TeamValidator.getTeamPlayerCount(session, 'blue');

    return redCount == playersPerTeam && blueCount == playersPerTeam;
  }

  /// Vérifie si la session a le bon nombre de joueurs
  static bool hasCorrectPlayerCount(GameSession session) {
    return session.players.length == requiredPlayerCount;
  }

  /// Vérifie si les équipes sont correctement formées
  static bool areTeamsValid(GameSession session) {
    final redCount = TeamValidator.getTeamPlayerCount(session, 'red');
    final blueCount = TeamValidator.getTeamPlayerCount(session, 'blue');

    return redCount == playersPerTeam && blueCount == playersPerTeam;
  }

  /// Obtient un message d'erreur si la session n'est pas prête
  static String? getNotReadyMessage(GameSession session) {
    if (!hasCorrectPlayerCount(session)) {
      final currentCount = session.players.length;
      return 'Il faut exactement $requiredPlayerCount joueurs (actuellement: $currentCount)';
    }

    if (!areTeamsValid(session)) {
      final redCount = TeamValidator.getTeamPlayerCount(session, 'red');
      final blueCount = TeamValidator.getTeamPlayerCount(session, 'blue');
      return 'Chaque équipe doit avoir $playersPerTeam joueurs (Rouge: $redCount, Bleue: $blueCount)';
    }

    return null; // Prête à démarrer
  }

  /// Vérifie si un joueur est l'hôte
  static bool isPlayerHost(GameSession session, String playerId) {
    final player = session.players
        .where((p) => p.id == playerId)
        .firstOrNull;

    return player?.isHost ?? false;
  }

  /// Vérifie si une session est vide
  static bool isEmpty(GameSession session) {
    return session.players.isEmpty;
  }

  /// Vérifie si une session est pleine
  static bool isFull(GameSession session) {
    return session.players.length >= requiredPlayerCount;
  }

  /// Obtient le nombre de places restantes
  static int getRemainingSlots(GameSession session) {
    return requiredPlayerCount - session.players.length;
  }

  /// Vérifie si tous les joueurs ont créé leurs challenges
  static bool haveAllPlayersCreatedChallenges(GameSession session) {
    return session.players.every((p) => p.challengesSent == 3);
  }

  /// Obtient le nombre de joueurs ayant créé leurs challenges
  static int getPlayersWithChallengesCount(GameSession session) {
    return session.players.where((p) => p.challengesSent == 3).length;
  }
}
