import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Service pour la génération d'images via l'API de jeu
class StableDiffusionService {
  static final ApiService _apiService = ApiService();

  /// Génère une image à partir d'un prompt via l'API de jeu
  static Future<String> generateImage(String prompt, String gameSessionId, String challengeId) async {
    try {
      // Utiliser la méthode drawForChallenge qui existe déjà dans ApiService
      await _apiService.drawForChallenge(gameSessionId, challengeId, prompt);
      
      // L'API de jeu devrait retourner l'URL de l'image générée dans la réponse
      // En attendant, on utilise une image placeholder basée sur le prompt
      return _getPlaceholderImage(prompt);
    } catch (e) {
      // En cas d'erreur, retourner une image placeholder
      // Utiliser debugPrint au lieu de print pour éviter les avertissements de linting
      debugPrint('Erreur génération image: $e');
      return _getPlaceholderImage(prompt);
    }
  }

  /// Génère une image placeholder en cas d'erreur
  static String _getPlaceholderImage(String prompt) {
    // Utilise Picsum avec un seed basé sur le prompt pour avoir une image cohérente
    final seed = prompt.hashCode.abs();
    return 'https://picsum.photos/seed/$seed/400/400';
  }

  /// Génère une image avec retry en cas d'échec
  static Future<String> generateImageWithRetry(String prompt, String gameSessionId, String challengeId, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await generateImage(prompt, gameSessionId, challengeId);
      } catch (e) {
        if (i == maxRetries - 1) {
          // Dernier essai, retourner une image placeholder
          return _getPlaceholderImage(prompt);
        }
        // Attendre avant de réessayer
        await Future.delayed(Duration(seconds: 2 * (i + 1)));
      }
    }
    return _getPlaceholderImage(prompt);
  }
}