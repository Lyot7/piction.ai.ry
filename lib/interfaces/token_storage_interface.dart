/// Interface abstraite pour le stockage des tokens (DIP)
/// Permet l'injection de dépendances et le mocking pour les tests
abstract class ITokenStorage {
  /// Initialise le stockage avec les tokens existants
  Future<void> initialize();

  /// Sauvegarde le JWT
  Future<void> saveJwt(String jwt);

  /// Récupère le JWT
  String? get jwt;

  /// Sauvegarde l'ID du joueur
  Future<void> savePlayerId(String playerId);

  /// Récupère l'ID du joueur
  String? get playerId;

  /// Efface tous les tokens
  Future<void> clear();

  /// Vérifie si un JWT est présent
  bool get hasToken;
}
