import '../models/challenge.dart';
import '../services/stable_diffusion_service.dart';
import '../utils/logger.dart';

/// Résultat d'une génération d'images
class ImageGenerationResult {
  final int successCount;
  final int totalCount;
  final bool phaseClosed;
  final List<String> generatedChallengeIds;
  final String? errorMessage;

  /// Map des URLs générées: challengeId -> imageUrl
  /// ✅ CRITIQUE: Permet de mettre à jour l'état local sans refresh backend
  final Map<String, String> generatedUrls;

  const ImageGenerationResult({
    required this.successCount,
    required this.totalCount,
    required this.phaseClosed,
    this.generatedChallengeIds = const [],
    this.errorMessage,
    this.generatedUrls = const {},
  });

  bool get isComplete => successCount == totalCount;
  bool get hasPartialSuccess => successCount > 0 && successCount < totalCount;
  bool get hasErrors => errorMessage != null;
}

/// Service responsable de la génération d'images pour les challenges
///
/// Principe SOLID:
/// - Single Responsibility Principle: UNE responsabilité - générer des images
/// - Dependency Inversion Principle: Dépend d'abstractions (callbacks), pas de concrétions
class ImageGenerationService {
  /// Callback pour vérifier si la phase est toujours valide
  final Future<bool> Function() isPhaseValid;

  /// Callback de progression (challengeIndex, totalChallenges)
  final void Function(int, int)? onProgress;

  /// Fonction de génération d'images (injectable pour les tests)
  /// Si null, utilise StableDiffusionService par défaut
  /// ✅ IMPORTANT: Retourne l'URL de l'image générée
  final Future<String> Function(String prompt, String gameSessionId, String challengeId)? imageGenerator;

  ImageGenerationService({
    required this.isPhaseValid,
    this.onProgress,
    this.imageGenerator,
  });

  /// Génère automatiquement des images pour une liste de challenges
  ///
  /// [challenges] - Liste des challenges à traiter
  /// [gameSessionId] - ID de la session de jeu
  /// [promptGenerator] - Fonction pour générer le prompt (permet l'injection)
  ///
  /// Returns [ImageGenerationResult] avec les détails de l'opération
  Future<ImageGenerationResult> generateImagesForChallenges({
    required List<Challenge> challenges,
    required String gameSessionId,
    String Function(Challenge)? promptGenerator,
  }) async {
    int successCount = 0;
    bool phaseClosed = false;
    final List<String> generatedIds = [];
    final Map<String, String> generatedUrls = {}; // ✅ NOUVEAU: Stocker les URLs
    String? errorMessage;

    AppLogger.info('[ImageGenerationService] Début génération pour ${challenges.length} challenges');

    try {
      for (int i = 0; i < challenges.length; i++) {
        final challenge = challenges[i];

        // Skip si image existe déjà
        if (challenge.imageUrl != null && challenge.imageUrl!.isNotEmpty) {
          AppLogger.info('[ImageGenerationService] Challenge ${i + 1} a déjà une image');
          successCount++;
          generatedIds.add(challenge.id);
          onProgress?.call(i + 1, challenges.length);
          continue;
        }

        // Vérifier la phase avant chaque génération
        final isValid = await isPhaseValid();
        if (!isValid) {
          AppLogger.warning('[ImageGenerationService] Phase invalidée, arrêt génération');
          phaseClosed = true;
          break;
        }

        // Générer le prompt
        final prompt = promptGenerator?.call(challenge) ?? _defaultPromptGenerator(challenge);

        try {
          // Générer l'image (utilise imageGenerator si fourni, sinon StableDiffusionService)
          final generator = imageGenerator ?? StableDiffusionService.generateImageWithRetry;

          // ✅ CRITIQUE: Capturer l'URL retournée par la génération
          final generatedUrl = await generator(prompt, gameSessionId, challenge.id);

          // ✅ CRITIQUE: Stocker l'URL dans la map pour mise à jour locale
          generatedUrls[challenge.id] = generatedUrl;

          successCount++;
          generatedIds.add(challenge.id);
          AppLogger.success('[ImageGenerationService] Image ${i + 1}/${challenges.length} générée: $generatedUrl');

          onProgress?.call(i + 1, challenges.length);

          // Petit délai entre générations
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (imageError) {
          AppLogger.error('[ImageGenerationService] Erreur génération ${i + 1}', imageError);

          // Détecter erreur de phase
          if (_isPhaseError(imageError)) {
            phaseClosed = true;
            break;
          }

          // Continuer avec les autres images en cas d'erreur non-critique
          errorMessage = imageError.toString();
          continue;
        }
      }
    } catch (e) {
      AppLogger.error('[ImageGenerationService] Erreur critique', e);
      errorMessage = e.toString();
    }

    final result = ImageGenerationResult(
      successCount: successCount,
      totalCount: challenges.length,
      phaseClosed: phaseClosed,
      generatedChallengeIds: generatedIds,
      errorMessage: errorMessage,
      generatedUrls: generatedUrls, // ✅ CRITIQUE: Retourner les URLs générées
    );

    AppLogger.info('[ImageGenerationService] Terminé: $successCount/${challenges.length} succès, ${generatedUrls.length} URLs capturées');
    return result;
  }

  /// Génère une image pour un seul challenge
  ///
  /// Returns true si succès, false sinon
  Future<bool> generateImageForChallenge({
    required Challenge challenge,
    required String gameSessionId,
    required String prompt,
  }) async {
    try {
      // Vérifier la phase
      final isValid = await isPhaseValid();
      if (!isValid) {
        AppLogger.warning('[ImageGenerationService] Phase invalide');
        return false;
      }

      // Générer l'image (utilise imageGenerator si fourni, sinon StableDiffusionService)
      final generator = imageGenerator ?? StableDiffusionService.generateImageWithRetry;
      await generator(prompt, gameSessionId, challenge.id);

      AppLogger.success('[ImageGenerationService] Image générée pour challenge ${challenge.id}');
      return true;
    } catch (e) {
      AppLogger.error('[ImageGenerationService] Erreur génération', e);
      return false;
    }
  }

  /// Prompt par défaut si aucun générateur fourni
  String _defaultPromptGenerator(Challenge challenge) {
    return 'A simple illustration showing the concept, digital art style, clean background';
  }

  /// Détecte si l'erreur est liée au changement de phase
  bool _isPhaseError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('not in the drawing phase') ||
        errorString.contains('400') ||
        errorString.contains('phase');
  }
}
