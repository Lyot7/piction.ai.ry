/// Interface abstraite pour l'API de génération d'images (SRP + DIP)
/// Responsabilité unique: Génération d'images via IA
abstract class IImageApi {
  /// Génère une image pour un challenge via StableDiffusion
  /// Retourne l'URL de l'image générée
  Future<String> generateImageForChallenge(
    String gameSessionId,
    String challengeId,
    String prompt,
  );

  /// Génère une image avec retry automatique en cas d'échec
  /// [maxRetries] - Nombre maximum de tentatives (défaut: 3)
  Future<String> generateImageWithRetry(
    String gameSessionId,
    String challengeId,
    String prompt, {
    int maxRetries = 3,
  });
}
