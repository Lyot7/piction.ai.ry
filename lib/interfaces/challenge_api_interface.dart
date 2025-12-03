import '../models/challenge.dart';

/// Interface abstraite pour l'API de challenges (SRP + DIP)
/// Responsabilité unique: Gestion des challenges
abstract class IChallengeApi {
  /// Envoie un challenge avec le format complet
  /// Format: "Un/Une [INPUT1] Sur/Dans Un/Une [INPUT2]" + 3 mots interdits
  Future<Challenge> sendChallenge(
    String gameSessionId,
    String article1,
    String input1,
    String preposition,
    String article2,
    String input2,
    List<String> forbiddenWords,
  );

  /// Récupère les challenges du joueur pour dessiner
  Future<List<Challenge>> getMyChallenges(String gameSessionId);

  /// Récupère les challenges à deviner
  Future<List<Challenge>> getMyChallengesToGuess(String gameSessionId);

  /// Envoie une réponse pour un challenge
  Future<void> answerChallenge(
    String gameSessionId,
    String challengeId,
    String answer,
    bool isResolved,
  );

  /// Liste tous les challenges d'une session
  Future<List<Challenge>> listSessionChallenges(String gameSessionId);
}
