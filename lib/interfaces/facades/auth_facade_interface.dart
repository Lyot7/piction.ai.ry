import '../../models/player.dart';

/// Interface pour la facade d'authentification (ISP)
/// Responsabilité unique: Gestion de l'authentification utilisateur
abstract class IAuthFacade {
  /// Se connecte avec un nom d'utilisateur
  Future<Player> loginWithUsername(String username);

  /// Déconnecte l'utilisateur
  Future<void> logout();

  /// Joueur actuellement connecté
  Player? get currentPlayer;

  /// Stream du joueur connecté
  Stream<Player?> get playerStream;

  /// Vérifie si un utilisateur est connecté
  bool get isLoggedIn;
}
