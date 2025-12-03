import '../models/player.dart';

/// Interface abstraite pour l'API des joueurs (SRP + DIP)
/// Responsabilité unique: Récupération des données des joueurs
abstract class IPlayerApi {
  /// Récupère un joueur par son ID
  /// Utilise un cache pour éviter les appels API répétés
  Future<Player> getPlayer(String playerId);

  /// Nettoie le cache des joueurs
  void clearPlayerCache();
}
