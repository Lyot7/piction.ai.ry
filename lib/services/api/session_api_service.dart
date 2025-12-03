import 'dart:convert';

import '../../interfaces/http_client_interface.dart';
import '../../interfaces/player_api_interface.dart';
import '../../interfaces/session_api_interface.dart';
import '../../models/game_session.dart';
import '../../models/player.dart';
import '../../utils/logger.dart';

/// Service de gestion des sessions de jeu (SRP)
/// Responsabilité unique: Opérations CRUD sur les sessions
class SessionApiService implements ISessionApi {
  final IHttpClient _httpClient;
  final IPlayerApi _playerApi;

  SessionApiService({
    required IHttpClient httpClient,
    required IPlayerApi playerApi,
  })  : _httpClient = httpClient,
        _playerApi = playerApi;

  @override
  Future<GameSession> createGameSession() async {
    final response = await _httpClient.post('/game_sessions');
    _handleResponse(response);

    final data = jsonDecode(response.body);
    return GameSession.fromJson(data);
  }

  @override
  Future<void> joinGameSession(String gameSessionId, String color) async {
    AppLogger.info('[SessionApiService] JOIN REQUEST - Color: $color');
    AppLogger.info('[SessionApiService] JOIN REQUEST - Game Session: $gameSessionId');

    final response = await _httpClient.post(
      '/game_sessions/$gameSessionId/join',
      body: {'color': color},
    );
    _handleResponse(response);

    AppLogger.success(
        '[SessionApiService] JOIN RESPONSE - Status: ${response.statusCode}');
  }

  @override
  Future<void> leaveGameSession(String gameSessionId) async {
    final response = await _httpClient.get('/game_sessions/$gameSessionId/leave');
    _handleResponse(response);
  }

  @override
  Future<GameSession> getGameSession(String gameSessionId) async {
    final response = await _httpClient.get('/game_sessions/$gameSessionId');
    _handleResponse(response);

    final data = jsonDecode(response.body);

    AppLogger.info('[SessionApiService] GET SESSION RAW DATA: ${jsonEncode(data)}');

    final session = GameSession.fromJson(data);

    // Enrichir les joueurs si nécessaire
    if (session.players.isNotEmpty && session.players.first.name.isEmpty) {
      final enrichedPlayers = await _enrichPlayersFromServer(session.players, data);
      return session.copyWith(players: enrichedPlayers);
    }

    return session;
  }

  @override
  Future<String> getGameSessionStatus(String gameSessionId) async {
    final response =
        await _httpClient.get('/game_sessions/$gameSessionId/status');
    _handleResponse(response);

    final data = jsonDecode(response.body);
    return data['status'] ?? 'lobby';
  }

  @override
  Future<void> startGameSession(String gameSessionId) async {
    AppLogger.info('[SessionApiService] START GAME REQUEST - Session: $gameSessionId');

    final response = await _httpClient.post('/game_sessions/$gameSessionId/start');

    AppLogger.info(
        '[SessionApiService] START GAME RESPONSE - Status: ${response.statusCode}');

    _handleResponse(response);
  }

  /// Enrichit les joueurs en récupérant leurs infos du serveur
  Future<List<Player>> _enrichPlayersFromServer(
    List<Player> minimalPlayers,
    Map<String, dynamic> sessionData,
  ) async {
    final enrichedPlayers = <Player>[];

    final backendHostId = (sessionData['host_id'] ??
            sessionData['hostId'] ??
            sessionData['created_by'] ??
            sessionData['createdBy'])
        ?.toString();

    AppLogger.info('[SessionApiService] Host ID from backend: $backendHostId');

    for (final minimalPlayer in minimalPlayers) {
      try {
        if (minimalPlayer.name.isNotEmpty) {
          final bool isHost;
          if (backendHostId != null) {
            isHost = minimalPlayer.id == backendHostId;
          } else {
            isHost = minimalPlayer.isHost;
          }
          enrichedPlayers.add(minimalPlayer.copyWith(isHost: isHost));
          continue;
        }

        final fullPlayer = await _playerApi.getPlayer(minimalPlayer.id);

        final bool isHost;
        if (backendHostId != null) {
          isHost = minimalPlayer.id == backendHostId;
        } else {
          isHost = minimalPlayer.isHost;
        }

        enrichedPlayers.add(fullPlayer.copyWith(
          color: minimalPlayer.color,
          isHost: isHost,
          role: minimalPlayer.role ?? fullPlayer.role,
          challengesSent: minimalPlayer.challengesSent,
          hasDrawn: minimalPlayer.hasDrawn,
          hasGuessed: minimalPlayer.hasGuessed,
        ));
      } catch (e) {
        AppLogger.error(
            '[SessionApiService] Erreur enrichissement joueur ${minimalPlayer.id}',
            e);
        enrichedPlayers.add(minimalPlayer);
      }
    }

    return enrichedPlayers;
  }

  void _handleResponse(dynamic response) {
    if (response.statusCode >= 400) {
      final errorMessage = 'Erreur ${response.statusCode}: ${response.body}';
      throw Exception(errorMessage);
    }
  }
}
