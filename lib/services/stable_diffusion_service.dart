import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Service pour la génération d'images via l'API de jeu (backend)
class StableDiffusionService {
  static final ApiService _apiService = ApiService();

  /// Génère une image à partir d'un prompt via l'API de jeu
  static Future<String> generateImage(String prompt, String gameSessionId, String challengeId) async {
    try {
      // Appeler l'API de jeu qui gère StableDiffusion en backend
      final response = await _apiService.generateImageForChallenge(gameSessionId, challengeId, prompt);
      return response;
    } catch (e) {
      debugPrint('Erreur génération image: $e');
      rethrow;
    }
  }

  /// Génère une image avec retry en cas d'échec
  static Future<String> generateImageWithRetry(String prompt, String gameSessionId, String challengeId, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await generateImage(prompt, gameSessionId, challengeId);
      } catch (e) {
        if (i == maxRetries - 1) {
          rethrow; // Relancer l'erreur au dernier essai
        }
        // Attendre avant de réessayer
        await Future.delayed(Duration(seconds: 2 * (i + 1)));
      }
    }
    throw Exception('Impossible de générer l\'image après $maxRetries tentatives');
  }
}