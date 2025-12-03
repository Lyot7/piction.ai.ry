import 'dart:convert';

import '../../interfaces/http_client_interface.dart';
import '../../interfaces/player_api_interface.dart';
import '../../models/player.dart';
import '../../utils/logger.dart';

/// Service de gestion des joueurs avec cache (SRP)
/// Responsabilité unique: Récupération des données des joueurs
class PlayerApiService implements IPlayerApi {
  final IHttpClient _httpClient;
  final Map<String, Player> _playerCache = {};

  PlayerApiService({required IHttpClient httpClient})
      : _httpClient = httpClient;

  @override
  Future<Player> getPlayer(String playerId) async {
    // Vérifier le cache d'abord
    if (_playerCache.containsKey(playerId)) {
      return _playerCache[playerId]!;
    }

    AppLogger.info(
        '[PlayerApiService] Cache MISS pour joueur: $playerId - Fetching from API');

    final response = await _httpClient.get('/players/$playerId');
    _handleResponse(response);

    final data = jsonDecode(response.body);
    final player = Player.fromJson(data);

    // Mettre en cache
    _playerCache[playerId] = player;

    return player;
  }

  @override
  void clearPlayerCache() {
    _playerCache.clear();
    AppLogger.info('[PlayerApiService] Player cache cleared');
  }

  void _handleResponse(dynamic response) {
    if (response.statusCode >= 400) {
      final errorMessage = 'Erreur ${response.statusCode}: ${response.body}';
      throw Exception(errorMessage);
    }
  }
}
