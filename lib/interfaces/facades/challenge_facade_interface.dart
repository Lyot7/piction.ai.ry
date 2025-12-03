import '../../models/challenge.dart';

/// Interface pour la facade de challenges (ISP)
/// Responsabilité unique: Gestion des challenges
abstract class IChallengeFacade {
  /// Envoie un challenge
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

  /// Rafraîchit les challenges créés par le joueur
  Future<void> refreshMyChallenges();

  /// Rafraîchit les challenges à deviner
  Future<void> refreshChallengesToGuess();

  /// Génère une image pour un challenge
  Future<String> generateImageForChallenge(
    String gameSessionId,
    String challengeId,
    String prompt,
  );

  /// Répond à un challenge
  Future<void> answerChallenge(
    String gameSessionId,
    String challengeId,
    String answer,
    bool isResolved,
  );

  /// Liste tous les challenges d'une session
  Future<List<Challenge>> listSessionChallenges(String gameSessionId);

  /// Challenges créés par le joueur
  List<Challenge> get myChallenges;

  /// Challenges à deviner
  List<Challenge> get challengesToGuess;

  /// Stream des challenges
  Stream<List<Challenge>> get challengesStream;
}
