import '../models/challenge.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

/// Repository pour les opérations sur les challenges
/// Principe SOLID: Single Responsibility + Dependency Inversion
/// Abstrait l'accès aux données des challenges
class ChallengeRepository {
  final ApiService _apiService;

  ChallengeRepository(this._apiService);

  /// Envoie un nouveau challenge
  Future<Challenge> sendChallenge(
    String gameSessionId,
    String article1,
    String input1,
    String preposition,
    String article2,
    String input2,
    List<String> forbiddenWords,
  ) async {
    try {
      AppLogger.info('[ChallengeRepository] Envoi d\'un challenge');
      return await _apiService.sendChallenge(
        gameSessionId,
        article1,
        input1,
        preposition,
        article2,
        input2,
        forbiddenWords,
      );
    } catch (e) {
      AppLogger.error('[ChallengeRepository] Erreur envoi challenge', e);
      rethrow;
    }
  }

  /// Récupère les challenges créés par le joueur
  Future<List<Challenge>> getMyChallenges(String gameSessionId) async {
    try {
      return await _apiService.getMyChallenges(gameSessionId);
    } catch (e) {
      AppLogger.error('[ChallengeRepository] Erreur récupération mes challenges', e);
      rethrow;
    }
  }

  /// Récupère les challenges à deviner
  Future<List<Challenge>> getMyChallengesToGuess(String gameSessionId) async {
    try {
      return await _apiService.getMyChallengesToGuess(gameSessionId);
    } catch (e) {
      AppLogger.error('[ChallengeRepository] Erreur récupération challenges à deviner', e);
      rethrow;
    }
  }

  /// Liste tous les challenges d'une session
  Future<List<Challenge>> listSessionChallenges(String gameSessionId) async {
    try {
      return await _apiService.listSessionChallenges(gameSessionId);
    } catch (e) {
      AppLogger.error('[ChallengeRepository] Erreur liste challenges session', e);
      rethrow;
    }
  }

  /// Envoie une réponse à un challenge
  Future<void> answerChallenge(
    String gameSessionId,
    String challengeId,
    String answer,
    bool isResolved,
  ) async {
    try {
      AppLogger.info('[ChallengeRepository] Réponse au challenge $challengeId');
      await _apiService.answerChallenge(gameSessionId, challengeId, answer, isResolved);
    } catch (e) {
      AppLogger.error('[ChallengeRepository] Erreur réponse challenge', e);
      rethrow;
    }
  }
}
