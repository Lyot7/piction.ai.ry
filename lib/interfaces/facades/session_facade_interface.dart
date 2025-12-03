import '../../models/game_session.dart';

/// Interface pour la facade de sessions (ISP)
/// Responsabilité unique: Gestion des sessions de jeu
abstract class ISessionFacade {
  /// Crée une nouvelle session de jeu
  Future<GameSession> createGameSession();

  /// Rejoint une session de jeu
  Future<void> joinGameSession(String gameSessionId, String color);

  /// Rejoint automatiquement une équipe disponible
  Future<void> joinAvailableTeam(String gameSessionId);

  /// Rafraîchit les informations de la session
  Future<void> refreshGameSession(String gameSessionId);

  /// Quitte la session actuelle
  Future<void> leaveGameSession();

  /// Démarre la session de jeu
  Future<void> startGameSession();

  /// Change d'équipe
  Future<void> changeTeam(String gameSessionId, String newTeamColor);

  /// Session de jeu actuelle
  GameSession? get currentGameSession;

  /// Stream de la session de jeu
  Stream<GameSession?> get gameSessionStream;
}
