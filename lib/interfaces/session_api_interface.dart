import '../models/game_session.dart';

/// Interface abstraite pour l'API de sessions de jeu (SRP + DIP)
/// Responsabilité unique: Gestion des sessions de jeu
abstract class ISessionApi {
  /// Crée une nouvelle session de jeu
  Future<GameSession> createGameSession();

  /// Rejoint une session de jeu
  Future<void> joinGameSession(String gameSessionId, String color);

  /// Quitte une session de jeu
  Future<void> leaveGameSession(String gameSessionId);

  /// Récupère les détails d'une session
  Future<GameSession> getGameSession(String gameSessionId);

  /// Récupère le statut d'une session
  Future<String> getGameSessionStatus(String gameSessionId);

  /// Démarre une session de jeu
  Future<void> startGameSession(String gameSessionId);
}
