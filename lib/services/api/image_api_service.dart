import 'dart:convert';

import '../../interfaces/http_client_interface.dart';
import '../../interfaces/image_api_interface.dart';
import '../../utils/logger.dart';

/// Service de génération d'images (SRP)
/// Responsabilité unique: Génération d'images via StableDiffusion
class ImageApiService implements IImageApi {
  final IHttpClient _httpClient;

  ImageApiService({required IHttpClient httpClient}) : _httpClient = httpClient;

  @override
  Future<String> generateImageForChallenge(
    String gameSessionId,
    String challengeId,
    String prompt,
  ) async {
    final response = await _httpClient.post(
      '/game_sessions/$gameSessionId/challenges/$challengeId/draw',
      body: {
        'prompt': prompt,
        'real': 'yes',
      },
    );

    _handleResponse(response);

    final data = jsonDecode(response.body);
    AppLogger.info('[ImageApiService] Réponse génération image: $data');

    // Essayer différents formats possibles
    final imageUrl = data['image_url'] ??
        data['imageUrl'] ??
        data['url'] ??
        (data['challenge'] != null ? data['challenge']['image_url'] : null) ??
        (data['challenge'] != null ? data['challenge']['imageUrl'] : null);

    if (imageUrl != null && imageUrl.toString().isNotEmpty) {
      return imageUrl.toString();
    }

    AppLogger.warning(
        '[ImageApiService] URL d\'image non trouvée, sera récupérée au prochain refresh');
    return '';
  }

  @override
  Future<String> generateImageWithRetry(
    String gameSessionId,
    String challengeId,
    String prompt, {
    int maxRetries = 3,
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await generateImageForChallenge(gameSessionId, challengeId, prompt);
      } catch (e) {
        if (i == maxRetries - 1) {
          rethrow; // Relancer l'erreur au dernier essai
        }
        AppLogger.warning('[ImageApiService] Tentative ${i + 1}/$maxRetries échouée, retry...');
        // Attendre avant de réessayer (délai exponentiel)
        await Future.delayed(Duration(seconds: 2 * (i + 1)));
      }
    }
    throw Exception('Impossible de générer l\'image après $maxRetries tentatives');
  }

  void _handleResponse(dynamic response) {
    if (response.statusCode >= 400) {
      final errorMessage = 'Erreur ${response.statusCode}: ${response.body}';
      throw Exception(errorMessage);
    }
  }
}
