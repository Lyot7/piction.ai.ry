import '../models/challenge.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

/// Manager pour la gestion des challenges
/// Principe SOLID: Single Responsibility - Uniquement les challenges
class ChallengeManager {
  final ApiService _apiService;

  ChallengeManager(this._apiService);

  /// Envoie un challenge avec le nouveau format
  /// Format: "Un/Une [INPUT1] Sur/Dans Un/Une [INPUT2]" + 3 mots interdits
  Future<Challenge> sendChallenge(
    String gameSessionId,
    String article1,      // "Un" ou "Une"
    String input1,        // Premier mot à deviner
    String preposition,   // "Sur" ou "Dans"
    String article2,      // "Un" ou "Une"
    String input2,        // Deuxième mot à deviner
    List<String> forbiddenWords, // 3 mots interdits
  ) async {
    try {
      AppLogger.info('[ChallengeManager] Envoi d\'un challenge');

      final challenge = await _apiService.sendChallenge(
        gameSessionId,
        article1,
        input1,
        preposition,
        article2,
        input2,
        forbiddenWords,
      );

      AppLogger.success('[ChallengeManager] Challenge envoyé: ${challenge.id}');
      return challenge;
    } catch (e) {
      AppLogger.error('[ChallengeManager] Erreur envoi challenge', e);
      throw Exception('Erreur lors de l\'envoi du challenge: $e');
    }
  }

  /// Actualise les challenges du joueur
  Future<List<Challenge>> getMyChallenges(String gameSessionId) async {
    try {
      final challenges = await _apiService.getMyChallenges(gameSessionId);
      AppLogger.info('[ChallengeManager] ${challenges.length} challenges récupérés');
      return challenges;
    } catch (e) {
      AppLogger.error('[ChallengeManager] Erreur récupération challenges', e);
      throw Exception('Erreur lors de l\'actualisation des challenges: $e');
    }
  }

  /// Actualise les challenges à deviner
  Future<List<Challenge>> getChallengesToGuess(String gameSessionId) async {
    try {
      final challenges = await _apiService.getMyChallengesToGuess(gameSessionId);
      AppLogger.info('[ChallengeManager] ${challenges.length} challenges à deviner récupérés');
      return challenges;
    } catch (e) {
      AppLogger.error('[ChallengeManager] Erreur récupération challenges à deviner', e);
      throw Exception('Erreur lors de l\'actualisation des challenges à deviner: $e');
    }
  }

  /// Liste tous les challenges d'une session
  Future<List<Challenge>> listSessionChallenges(String gameSessionId) async {
    try {
      return await _apiService.listSessionChallenges(gameSessionId);
    } catch (e) {
      AppLogger.error('[ChallengeManager] Erreur liste challenges session', e);
      throw Exception('Erreur lors de la récupération des challenges: $e');
    }
  }

  /// Envoie une réponse pour un challenge
  Future<void> answerChallenge(
    String gameSessionId,
    String challengeId,
    String answer,
    bool isResolved
  ) async {
    try {
      AppLogger.info('[ChallengeManager] Réponse au challenge $challengeId: $answer (résolu: $isResolved)');

      await _apiService.answerChallenge(gameSessionId, challengeId, answer, isResolved);

      AppLogger.success('[ChallengeManager] Réponse envoyée');
    } catch (e) {
      AppLogger.error('[ChallengeManager] Erreur envoi réponse', e);
      throw Exception('Erreur lors de l\'envoi de la réponse: $e');
    }
  }
}
