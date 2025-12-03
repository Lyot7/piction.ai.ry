/// Interface pour la facade de timer (ISP)
/// Responsabilité unique: Gestion du timer de jeu (5 minutes)
abstract class ITimerFacade {
  /// Démarre le timer de jeu
  void startTimer({required void Function() onEnd});

  /// Arrête le timer
  void stopTimer();

  /// Temps restant en secondes
  int get remainingSeconds;

  /// Stream du timer
  Stream<int> get timerStream;

  /// Libère les ressources
  void dispose();
}
