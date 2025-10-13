import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player.dart';
import '../models/game_session.dart';
import '../models/challenge.dart';

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
    
    try {
      // D'abord essayer de se connecter (si l'utilisateur existe)
      return await login(username, defaultPassword);
    } catch (e) {
      // Si échec, essayer de créer le joueur avec un nom unique
      String uniqueUsername = username;
      int attempt = 1;
      
      while (attempt <= 10) { // Limite à 10 tentatives
        try {
          await createPlayer(uniqueUsername, defaultPassword);
          return await login(uniqueUsername, defaultPassword);
        } catch (createError) {
          final errorMessage = createError.toString();
          if (errorMessage.contains('Player already exists')) {
            // Si le joueur existe déjà, essayer avec un suffixe
            attempt++;
            uniqueUsername = '${username}_$attempt';
          } else {
            // Autre erreur, la remonter
            throw Exception('Impossible de créer le compte "$uniqueUsername": $createError');
          }
        }
      }
      
      throw Exception('Impossible de créer un nom d\'utilisateur unique après 10 tentatives');
    }
  }

  /// Récupère les informations du joueur connecté
  Future<Player> getMe() async {
    final response = await _request('GET', '/me');
    _handleResponse(response);
    
    final data = jsonDecode(response.body);
    final player = Player.fromJson(data);
    
    // Sauvegarde l'ID du joueur
    await _savePlayerId(player.id);
    
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
    final response = await _request(
      'POST',
      '/game_sessions/$gameSessionId/join',
      body: {'color': color},
    );
    _handleResponse(response);
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
    return GameSession.fromJson(data);
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

  /// Envoie un challenge
  Future<Challenge> sendChallenge(
    String gameSessionId,
    String firstWord,
    String secondWord,
    String thirdWord,
    String fourthWord,
    String fifthWord,
    List<String> forbiddenWords,
  ) async {
    final response = await _request(
      'POST',
      '/game_sessions/$gameSessionId/challenges',
      body: {
        'first_word': firstWord,
        'second_word': secondWord,
        'third_word': thirdWord,
        'fourth_word': fourthWord,
        'fifth_word': fifthWord,
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
