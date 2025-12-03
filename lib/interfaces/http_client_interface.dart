import 'package:http/http.dart' as http;

/// Interface abstraite pour le client HTTP (DIP)
/// Permet l'injection de dépendances et le mocking pour les tests
abstract class IHttpClient {
  /// Effectue une requête GET
  Future<http.Response> get(String endpoint);

  /// Effectue une requête POST
  Future<http.Response> post(String endpoint, {Map<String, dynamic>? body});

  /// Effectue une requête PUT
  Future<http.Response> put(String endpoint, {Map<String, dynamic>? body});

  /// Effectue une requête DELETE
  Future<http.Response> delete(String endpoint);

  /// Retourne l'URL de base
  String get baseUrl;
}
