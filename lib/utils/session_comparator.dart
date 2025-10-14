import '../models/game_session.dart';

/// Utilitaire pour comparer deux sessions de jeu
/// Principe SOLID: Single Responsibility - Uniquement la comparaison de sessions
class SessionComparator {
  /// Vérifie si deux sessions sont différentes
  static bool hasChanged(GameSession oldSession, GameSession newSession) {
    // Comparer le nombre de joueurs
    if (oldSession.players.length != newSession.players.length) {
      return true;
    }

    // Comparer les IDs, couleurs et rôles des joueurs
    for (var i = 0; i < oldSession.players.length; i++) {
      final oldPlayer = oldSession.players[i];
      final newPlayer = newSession.players.firstWhere(
        (p) => p.id == oldPlayer.id,
        orElse: () => oldPlayer,
      );

      if (!arePlayersEqual(oldPlayer, newPlayer)) {
        return true;
      }
    }

    // Comparer le statut
    if (oldSession.status != newSession.status) {
      return true;
    }

    return false;
  }

  /// Vérifie si deux joueurs sont égaux
  static bool arePlayersEqual(player1, player2) {
    return player1.id == player2.id &&
           player1.color == player2.color &&
           player1.role == player2.role &&
           player1.name == player2.name &&
           player1.isHost == player2.isHost &&
           player1.challengesSent == player2.challengesSent;
  }

  /// Obtient les différences entre deux sessions (pour debug)
  static Map<String, dynamic> getDifferences(
    GameSession oldSession,
    GameSession newSession,
  ) {
    final differences = <String, dynamic>{};

    if (oldSession.players.length != newSession.players.length) {
      differences['playerCount'] = {
        'old': oldSession.players.length,
        'new': newSession.players.length,
      };
    }

    if (oldSession.status != newSession.status) {
      differences['status'] = {
        'old': oldSession.status,
        'new': newSession.status,
      };
    }

    // Comparer les joueurs
    final playerDifferences = <String, dynamic>{};
    for (final oldPlayer in oldSession.players) {
      final newPlayer = newSession.players
          .where((p) => p.id == oldPlayer.id)
          .firstOrNull;

      if (newPlayer != null && !arePlayersEqual(oldPlayer, newPlayer)) {
        playerDifferences[oldPlayer.id] = {
          'old': {
            'name': oldPlayer.name,
            'color': oldPlayer.color,
            'role': oldPlayer.role,
          },
          'new': {
            'name': newPlayer.name,
            'color': newPlayer.color,
            'role': newPlayer.role,
          },
        };
      }
    }

    if (playerDifferences.isNotEmpty) {
      differences['players'] = playerDifferences;
    }

    return differences;
  }
}
