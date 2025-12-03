import 'package:http/http.dart' as http;

import '../../interfaces/http_client_interface.dart';
import '../../interfaces/token_storage_interface.dart';
import '../../utils/logger.dart';
import 'http_method_strategy.dart';

/// Exception pour les méthodes HTTP non supportées
class UnsupportedHttpMethodException implements Exception {
  final String method;
  UnsupportedHttpMethodException(this.method);

  @override
  String toString() => 'Méthode HTTP non supportée: $method';
}

/// Service HTTP utilisant le Strategy Pattern (OCP)
/// Responsabilité unique: Orchestration des requêtes HTTP
class HttpService implements IHttpClient {
  final String _baseUrl;
  final ITokenStorage _tokenStorage;
  final Map<String, HttpMethodStrategy> _strategies;

  HttpService({
    required String baseUrl,
    required ITokenStorage tokenStorage,
    Map<String, HttpMethodStrategy>? strategies,
  })  : _baseUrl = baseUrl,
        _tokenStorage = tokenStorage,
        _strategies = strategies ??
            {
              'GET': GetStrategy(),
              'POST': PostStrategy(),
              'PUT': PutStrategy(),
              'DELETE': DeleteStrategy(),
              'PATCH': PatchStrategy(),
            };

  @override
  String get baseUrl => _baseUrl;

  /// Retourne les headers avec authentification
  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_tokenStorage.jwt != null) {
      headers['Authorization'] = 'Bearer ${_tokenStorage.jwt}';
    }
    return headers;
  }

  /// Effectue une requête HTTP avec la stratégie appropriée
  Future<http.Response> request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final strategy = _strategies[method.toUpperCase()];

    if (strategy == null) {
      throw UnsupportedHttpMethodException(method);
    }

    // Log pour debug
    final jwtPreview = _tokenStorage.jwt != null
        ? '${_tokenStorage.jwt!.substring(0, 10)}...'
        : 'absent';
    AppLogger.info('[HttpService] $method $endpoint - JWT: $jwtPreview');

    return await strategy.execute(url, _headers, body: body);
  }

  @override
  Future<http.Response> get(String endpoint) async {
    return await request('GET', endpoint);
  }

  @override
  Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) async {
    return await request('POST', endpoint, body: body);
  }

  @override
  Future<http.Response> put(String endpoint, {Map<String, dynamic>? body}) async {
    return await request('PUT', endpoint, body: body);
  }

  @override
  Future<http.Response> delete(String endpoint) async {
    return await request('DELETE', endpoint);
  }
}
