import '../models/player.dart';

/// Interface abstraite pour l'API d'authentification (SRP + DIP)
/// Responsabilité unique: Gestion de l'authentification
abstract class IAuthApi {
  /// Crée un nouveau joueur
  Future<Player> createPlayer(String name, String password);

  /// Connecte un joueur et retourne le JWT
  Future<String> login(String name, String password);

  /// Se connecte avec juste un nom d'utilisateur (crée le compte si nécessaire)
  Future<String> loginWithUsername(String username);

  /// Récupère les informations du joueur connecté
  Future<Player> getMe();

  /// Déconnecte l'utilisateur
  Future<void> logout();

  /// Vérifie si l'utilisateur est connecté
  bool get isLoggedIn;

  /// Récupère l'ID du joueur connecté
  String? get currentPlayerId;
}
