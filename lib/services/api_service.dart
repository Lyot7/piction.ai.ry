import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player.dart';
import '../models/game_session.dart';
import '../models/challenge.dart';
import '../utils/logger.dart';

/// Service principal pour les appels API
class ApiService {
  static const String _baseUrl = 'https://pictioniary.wevox.cloud/api';
  static const String _jwtKey = 'jwt_token';
  static const String _playerIdKey = 'player_id';

  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _jwt;
  String? _playerId;

  /// Initialise le service avec les tokens stockés
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _jwt = prefs.getString(_jwtKey);
    _playerId = prefs.getString(_playerIdKey);
  }

  /// Sauvegarde le JWT
  Future<void> _saveJwt(String jwt) async {
    _jwt = jwt;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_jwtKey, jwt);
  }

  /// Sauvegarde l'ID du joueur
  Future<void> _savePlayerId(String playerId) async {
    _playerId = playerId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playerIdKey, playerId);
  }

  /// Retourne les headers avec authentification
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_jwt != null) {
      headers['Authorization'] = 'Bearer $_jwt';
    }
    return headers;
  }

  /// Effectue une requête HTTP
  Future<http.Response> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final headers = _headers;

    // Log détaillé pour debug (masquer le JWT complet)
    AppLogger.info('[ApiService] REQUEST $method $endpoint - JWT: ${_jwt != null ? "présent (${_jwt!.substring(0, 10)}...)" : "absent"}');
    if (body != null) {
      AppLogger.info('[ApiService] REQUEST BODY: ${jsonEncode(body)}');
    }

    http.Response response;
    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(url, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          url,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(url, headers: headers);
        break;
      default:
        throw Exception('Méthode HTTP non supportée: $method');
    }

    return response;
  }

  /// Gère les erreurs de réponse
  void _handleResponse(http.Response response) {
    if (response.statusCode >= 400) {
      final errorMessage = 'Erreur ${response.statusCode}: ${response.body}';
      throw Exception(errorMessage);
    }
  }

  // ===== AUTHENTIFICATION =====

  /// Crée un nouveau joueur
  Future<Player> createPlayer(String name, String password) async {
    final response = await _request(
      'POST',
      '/players',
      body: {
        'name': name,
        'password': password,
      },
    );

    _handleResponse(response);
    final data = jsonDecode(response.body);
    return Player.fromJson(data);
  }

  /// Connecte un joueur et récupère le JWT
  Future<String> login(String name, String password) async {
    final response = await _request(
      'POST',
      '/login',
      body: {
        'name': name,
        'password': password,
      },
    );

    _handleResponse(response);
    final data = jsonDecode(response.body);
    final jwt = data['jwt'] ?? data['token'] ?? data['access_token'];
    
    if (jwt == null) {
      throw Exception('JWT manquant dans la réponse');
    }

    await _saveJwt(jwt);
    return jwt;
  }

  /// Se connecte avec juste un nom d'utilisateur (crée le compte si nécessaire)
  Future<String> loginWithUsername(String username) async {
    // Utiliser un mot de passe par défaut pour simplifier l'auth
    const String defaultPassword = 'piction2024';

    AppLogger.info('[ApiService] Tentative de connexion avec: $username');

    // Essayer de créer le compte avec le nom, ou ajouter un suffixe si déjà pris
    String attemptedName = username;
    int suffix = 2;
    const int maxAttempts = 10;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        // Essayer de créer le compte
        await createPlayer(attemptedName, defaultPassword);
        AppLogger.success('[ApiService] Compte créé pour: $attemptedName');

        // Une fois créé, se connecter
        final jwt = await login(attemptedName, defaultPassword);
        AppLogger.success('[ApiService] Connexion réussie pour: $attemptedName');
        return jwt;
      } catch (createError) {
        final errorMessage = createError.toString().toLowerCase();

        // Si le joueur existe déjà, essayer avec un suffixe
        if (errorMessage.contains('already exists') ||
            errorMessage.contains('déjà') ||
            errorMessage.contains('existe')) {
          AppLogger.warning('[ApiService] Le nom "$attemptedName" est déjà utilisé, essai avec suffixe');
          attemptedName = '${username}_$suffix';
          suffix++;
          continue;
        }

        // Autre erreur de création
        AppLogger.error('[ApiService] Erreur création compte pour: $attemptedName', createError);
        throw Exception('Impossible de créer le compte: $createError');
      }
    }

    // Si on arrive ici, on a épuisé toutes les tentatives
    throw Exception('Impossible de trouver un nom disponible après $maxAttempts tentatives');
  }

  /// Récupère les informations du joueur connecté
  Future<Player> getMe() async {
    final response = await _request('GET', '/me');
    _handleResponse(response);

    final data = jsonDecode(response.body);
    final player = Player.fromJson(data);

    // Sauvegarde l'ID du joueur
    await _savePlayerId(player.id);

    AppLogger.info('[ApiService] Joueur récupéré: ${player.name} (ID: ${player.id})');

    return player;
  }

  /// Récupère un joueur par son ID
  Future<Player> getPlayer(String playerId) async {
    final response = await _request('GET', '/players/$playerId');
    _handleResponse(response);
    
    final data = jsonDecode(response.body);
    return Player.fromJson(data);
  }

  // ===== SESSIONS DE JEU =====

  /// Crée une nouvelle session de jeu
  Future<GameSession> createGameSession() async {
    final response = await _request('POST', '/game_sessions');
    _handleResponse(response);
    
    final data = jsonDecode(response.body);
    return GameSession.fromJson(data);
  }

  /// Rejoint une session de jeu
  Future<void> joinGameSession(String gameSessionId, String color) async {
    // Log pour debug: vérifier que le JWT est bien présent
    AppLogger.info('[ApiService] JOIN REQUEST - JWT présent: ${_jwt != null}');
    AppLogger.info('[ApiService] JOIN REQUEST - Player ID: $_playerId');
    AppLogger.info('[ApiService] JOIN REQUEST - Color: $color');
    AppLogger.info('[ApiService] JOIN REQUEST - Game Session: $gameSessionId');

    final response = await _request(
      'POST',
      '/game_sessions/$gameSessionId/join',
      body: {'color': color},
    );
    _handleResponse(response);

    AppLogger.success('[ApiService] JOIN RESPONSE - Status: ${response.statusCode}');
    AppLogger.info('[ApiService] JOIN RESPONSE - Body: ${response.body}');
  }

  /// Quitte une session de jeu
  Future<void> leaveGameSession(String gameSessionId) async {
    final response = await _request('GET', '/game_sessions/$gameSessionId/leave');
    _handleResponse(response);
  }

  /// Récupère les détails d'une session
  Future<GameSession> getGameSession(String gameSessionId) async {
    final response = await _request('GET', '/game_sessions/$gameSessionId');
    _handleResponse(response);

    final data = jsonDecode(response.body);

    // Parser la session de base
    final session = GameSession.fromJson(data);

    // Enrichir les joueurs avec leurs détails complets
    if (session.players.isNotEmpty && session.players.first.name.isEmpty) {
      final enrichedPlayers = await _enrichPlayersWithDetails(session.players, data);
      return session.copyWith(players: enrichedPlayers);
    }

    return session;
  }

  /// Enrichit les joueurs minimaux avec leurs détails complets
  Future<List<Player>> _enrichPlayersWithDetails(
    List<Player> minimalPlayers,
    Map<String, dynamic> sessionData,
  ) async {
    final enrichedPlayers = <Player>[];

    // Récupérer l'ID du joueur actuel depuis la session ou depuis le token
    final currentPlayerId = sessionData['player_id']?.toString() ?? _playerId;

    // Déterminer les hosts une seule fois
    final redTeam = (sessionData['red_team'] as List<dynamic>?) ?? [];
    final blueTeam = (sessionData['blue_team'] as List<dynamic>?) ?? [];
    final hostId = redTeam.isNotEmpty ? redTeam.first.toString() :
                   (blueTeam.isNotEmpty ? blueTeam.first.toString() : null);

    // Enrichir les joueurs en parallèle pour plus de rapidité
    final futures = minimalPlayers.map((minimalPlayer) async {
      try {
        Player fullPlayer;

        if (minimalPlayer.id == currentPlayerId) {
          fullPlayer = await getMe();
        } else {
          fullPlayer = await getPlayer(minimalPlayer.id);
        }

        final isHost = minimalPlayer.id == hostId;

        return fullPlayer.copyWith(
          color: minimalPlayer.color,
          isHost: isHost,
        );
      } catch (e) {
        // En cas d'erreur, garder le joueur minimal
        return minimalPlayer;
      }
    });

    enrichedPlayers.addAll(await Future.wait(futures));
    return enrichedPlayers;
  }

  /// Récupère le statut d'une session
  Future<String> getGameSessionStatus(String gameSessionId) async {
    final response = await _request('GET', '/game_sessions/$gameSessionId/status');
    _handleResponse(response);
    
    final data = jsonDecode(response.body);
    return data['status'] ?? 'lobby';
  }

  /// Démarre une session de jeu
  Future<void> startGameSession(String gameSessionId) async {
    final response = await _request('POST', '/game_sessions/$gameSessionId/start');
    _handleResponse(response);
  }


  // ===== CHALLENGES =====

  /// Envoie un challenge avec le nouveau format
  /// Format: "Un/Une [INPUT1] Sur/Dans Un/Une [INPUT2]" + 3 mots interdits
  Future<Challenge> sendChallenge(
    String gameSessionId,
    String article1,      // "Un" ou "Une"
    String input1,        // Premier mot à deviner
    String preposition,   // "Sur" ou "Dans"
    String article2,      // "Un" ou "Une"
    String input2,        // Deuxième mot à deviner
    List<String> forbiddenWords, // 3 mots interdits
  ) async {
    final response = await _request(
      'POST',
      '/game_sessions/$gameSessionId/challenges',
      body: {
        'article1': article1,
        'input1': input1,
        'preposition': preposition,
        'article2': article2,
        'input2': input2,
        'forbidden_words': forbiddenWords,
      },
    );

    _handleResponse(response);
    final data = jsonDecode(response.body);
    return Challenge.fromJson(data);
  }

  /// Récupère les challenges du joueur pour dessiner
  Future<List<Challenge>> getMyChallenges(String gameSessionId) async {
    final response = await _request('GET', '/game_sessions/$gameSessionId/myChallenges');
    _handleResponse(response);
    
    final data = jsonDecode(response.body);
    final challengesList = data is List ? data : (data['items'] ?? []);
    
    return challengesList
        .map<Challenge>((challengeJson) => Challenge.fromJson(challengeJson))
        .toList();
  }


  /// Récupère les challenges à deviner
  Future<List<Challenge>> getMyChallengesToGuess(String gameSessionId) async {
    final response = await _request('GET', '/game_sessions/$gameSessionId/myChallengesToGuess');
    _handleResponse(response);
    
    final data = jsonDecode(response.body);
    final challengesList = data is List ? data : (data['items'] ?? []);
    
    return challengesList
        .map<Challenge>((challengeJson) => Challenge.fromJson(challengeJson))
        .toList();
  }

  /// Envoie une réponse pour un challenge
  Future<void> answerChallenge(
    String gameSessionId,
    String challengeId,
    String answer,
    bool isResolved,
  ) async {
    final response = await _request(
      'POST',
      '/game_sessions/$gameSessionId/challenges/$challengeId/answer',
      body: {
        'answer': answer,
        'is_resolved': isResolved,
      },
    );
    _handleResponse(response);
  }

  /// Génère une image pour un challenge via IA
  Future<String> generateImageForChallenge(
    String gameSessionId,
    String challengeId,
    String prompt,
  ) async {
    final response = await _request(
      'POST',
      '/api/game_sessions/$gameSessionId/challenges/$challengeId/draw',
      body: {
        'prompt': prompt,
        'real': 'yes',
      },
    );
    _handleResponse(response);
    
    final data = jsonDecode(response.body);
    final imageUrl = data['image_url'] ?? data['imageUrl'];
    if (imageUrl == null) {
      throw Exception('URL d\'image manquante dans la réponse');
    }
    return imageUrl;
  }

  /// Liste tous les challenges d'une session (mode finished)
  Future<List<Challenge>> listSessionChallenges(String gameSessionId) async {
    final response = await _request('GET', '/game_sessions/$gameSessionId/challenges');
    _handleResponse(response);
    
    final data = jsonDecode(response.body);
    final challengesList = data is List ? data : (data['items'] ?? []);
    
    return challengesList
        .map<Challenge>((challengeJson) => Challenge.fromJson(challengeJson))
        .toList();
  }

  // ===== UTILITAIRES =====

  /// Vérifie si l'utilisateur est connecté
  bool get isLoggedIn => _jwt != null;

  /// Récupère l'ID du joueur connecté
  String? get currentPlayerId => _playerId;

  /// Déconnecte l'utilisateur
  Future<void> logout() async {
    _jwt = null;
    _playerId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_jwtKey);
    await prefs.remove(_playerIdKey);
  }
}
