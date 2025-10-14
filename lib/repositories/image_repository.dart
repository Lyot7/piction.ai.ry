import '../services/stable_diffusion_service.dart';
import '../utils/logger.dart';

/// Repository pour les opérations de génération d'images
/// Principe SOLID: Single Responsibility + Dependency Inversion
/// Abstrait l'accès aux services de génération d'images
class ImageRepository {
  /// Génère une image avec retry automatique
  Future<String> generateImage(
    String prompt,
    String gameSessionId,
    String challengeId,
  ) async {
    try {
      AppLogger.info('[ImageRepository] Génération d\'une image');
      return await StableDiffusionService.generateImageWithRetry(
        prompt,
        gameSessionId,
        challengeId,
      );
    } catch (e) {
      AppLogger.error('[ImageRepository] Erreur génération image', e);
      rethrow;
    }
  }

  /// Génère une image sans retry (un seul essai)
  Future<String> generateImageSingleAttempt(
    String prompt,
    String gameSessionId,
    String challengeId,
  ) async {
    try {
      AppLogger.info('[ImageRepository] Génération d\'une image (single attempt)');
      return await StableDiffusionService.generateImage(
        prompt,
        gameSessionId,
        challengeId,
      );
    } catch (e) {
      AppLogger.error('[ImageRepository] Erreur génération image', e);
      rethrow;
    }
  }
}
