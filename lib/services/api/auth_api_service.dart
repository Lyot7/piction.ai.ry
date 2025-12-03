import 'dart:convert';

import '../../interfaces/auth_api_interface.dart';
import '../../interfaces/http_client_interface.dart';
import '../../interfaces/token_storage_interface.dart';
import '../../models/player.dart';
import '../../utils/logger.dart';

/// Service d'authentification (SRP)
/// Responsabilité unique: Gestion de l'authentification
class AuthApiService implements IAuthApi {
  final IHttpClient _httpClient;
  final ITokenStorage _tokenStorage;

  AuthApiService({
    required IHttpClient httpClient,
    required ITokenStorage tokenStorage,
  })  : _httpClient = httpClient,
        _tokenStorage = tokenStorage;

  @override
  Future<Player> createPlayer(String name, String password) async {
    final response = await _httpClient.post(
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

  @override
  Future<String> login(String name, String password) async {
    final response = await _httpClient.post(
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

    await _tokenStorage.saveJwt(jwt);
    return jwt;
  }

  @override
  Future<String> loginWithUsername(String username) async {
    const String defaultPassword = 'piction2024';

    AppLogger.info('[AuthApiService] Tentative de connexion avec: $username');

    // 1. D'abord essayer de se connecter au compte existant
    try {
      final jwt = await login(username, defaultPassword);
      AppLogger.success('[AuthApiService] Connexion réussie pour compte existant: $username');
      return jwt;
    } catch (loginError) {
      final loginErrorMsg = loginError.toString().toLowerCase();

      // Si c'est une erreur d'authentification (compte n'existe pas ou mauvais mot de passe)
      // on essaie de créer le compte
      if (loginErrorMsg.contains('401') ||
          loginErrorMsg.contains('unauthorized') ||
          loginErrorMsg.contains('invalid') ||
          loginErrorMsg.contains('not found') ||
          loginErrorMsg.contains('introuvable')) {
        AppLogger.info('[AuthApiService] Compte inexistant, tentative de création: $username');
      } else {
        // Autre erreur (réseau, etc.) - on propage
        AppLogger.error('[AuthApiService] Erreur login inattendue', loginError);
        rethrow;
      }
    }

    // 2. Le compte n'existe pas, on le crée
    try {
      await createPlayer(username, defaultPassword);
      AppLogger.success('[AuthApiService] Compte créé pour: $username');

      final jwt = await login(username, defaultPassword);
      AppLogger.success('[AuthApiService] Connexion réussie pour nouveau compte: $username');
      return jwt;
    } catch (createError) {
      final errorMessage = createError.toString().toLowerCase();

      // Si le nom est déjà pris (race condition ou problème de cache)
      // on réessaie simplement de se connecter
      if (errorMessage.contains('already exists') ||
          errorMessage.contains('déjà') ||
          errorMessage.contains('existe')) {
        AppLogger.warning('[AuthApiService] Compte créé entre-temps, reconnexion: $username');
        try {
          final jwt = await login(username, defaultPassword);
          return jwt;
        } catch (retryError) {
          AppLogger.error('[AuthApiService] Échec reconnexion', retryError);
          throw Exception('Le compte "$username" existe mais le mot de passe est incorrect');
        }
      }

      AppLogger.error('[AuthApiService] Erreur création compte', createError);
      throw Exception('Impossible de créer le compte: $createError');
    }
  }

  @override
  Future<Player> getMe() async {
    final response = await _httpClient.get('/me');
    _handleResponse(response);

    final data = jsonDecode(response.body);
    final player = Player.fromJson(data);

    await _tokenStorage.savePlayerId(player.id);

    AppLogger.info(
        '[AuthApiService] Joueur récupéré: ${player.name} (ID: ${player.id})');

    return player;
  }

  @override
  Future<void> logout() async {
    await _tokenStorage.clear();
  }

  @override
  bool get isLoggedIn => _tokenStorage.hasToken;

  @override
  String? get currentPlayerId => _tokenStorage.playerId;

  void _handleResponse(dynamic response) {
    if (response.statusCode >= 400) {
      final errorMessage = 'Erreur ${response.statusCode}: ${response.body}';
      throw Exception(errorMessage);
    }
  }
}
