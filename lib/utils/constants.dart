/// Constantes de l'application
/// Principe SOLID: Single Responsibility - Uniquement les constantes
class AppConstants {
  // Jeu
  static const int maxPlayers = 4;
  static const int playersPerTeam = 2;
  static const int gameDurationMinutes = 5;
  static const int gameDurationSeconds = gameDurationMinutes * 60;
  static const int challengesPerPlayer = 3;
  static const int forbiddenWordsPerChallenge = 3;
  static const int maxRegenerations = 2;

  // Scores
  static const int initialTeamScore = 100;
  static const int correctAnswerPoints = 25;
  static const int wrongAnswerPenalty = -1;
  static const int regenerationPenalty = -10;

  // Polling
  static const Duration defaultPollingInterval = Duration(milliseconds: 1000);
  static const Duration challengePollingInterval = Duration(seconds: 2);
  static const Duration maxWaitTime = Duration(minutes: 5);

  // Retry
  static const int maxRetries = 3;
  static const int retryDelayMs = 100;

  // UI
  static const Duration animationDuration = Duration(milliseconds: 150);
  static const Duration snackBarDuration = Duration(seconds: 2);
  static const Duration successMessageDuration = Duration(seconds: 2);

  // Équipes
  static const String teamRed = 'red';
  static const String teamBlue = 'blue';

  // États du jeu
  static const String statusLobby = 'lobby';
  static const String statusChallenge = 'challenge';
  static const String statusPlaying = 'playing';
  static const String statusFinished = 'finished';

  // Rôles
  static const String roleDrawer = 'drawer';
  static const String roleGuesser = 'guesser';

  // Articles et prépositions (pour les challenges)
  static const List<String> articles = ['Un', 'Une'];
  static const List<String> prepositions = ['Sur', 'Dans'];
}
