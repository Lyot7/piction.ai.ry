import 'dart:convert';
import 'package:http/http.dart' as http;

/// Interface pour le pattern Strategy des méthodes HTTP (OCP)
/// Open for extension, closed for modification
abstract class HttpMethodStrategy {
  Future<http.Response> execute(
    Uri url,
    Map<String, String> headers, {
    Map<String, dynamic>? body,
  });
}

/// Stratégie pour les requêtes GET
class GetStrategy implements HttpMethodStrategy {
  @override
  Future<http.Response> execute(
    Uri url,
    Map<String, String> headers, {
    Map<String, dynamic>? body,
  }) async {
    return await http.get(url, headers: headers);
  }
}

/// Stratégie pour les requêtes POST
class PostStrategy implements HttpMethodStrategy {
  @override
  Future<http.Response> execute(
    Uri url,
    Map<String, String> headers, {
    Map<String, dynamic>? body,
  }) async {
    return await http.post(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }
}

/// Stratégie pour les requêtes PUT
class PutStrategy implements HttpMethodStrategy {
  @override
  Future<http.Response> execute(
    Uri url,
    Map<String, String> headers, {
    Map<String, dynamic>? body,
  }) async {
    return await http.put(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }
}

/// Stratégie pour les requêtes DELETE
class DeleteStrategy implements HttpMethodStrategy {
  @override
  Future<http.Response> execute(
    Uri url,
    Map<String, String> headers, {
    Map<String, dynamic>? body,
  }) async {
    return await http.delete(url, headers: headers);
  }
}

/// Stratégie pour les requêtes PATCH (extensibilité OCP)
class PatchStrategy implements HttpMethodStrategy {
  @override
  Future<http.Response> execute(
    Uri url,
    Map<String, String> headers, {
    Map<String, dynamic>? body,
  }) async {
    return await http.patch(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }
}
