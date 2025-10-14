import 'dart:async';
import '../utils/logger.dart';

/// Manager pour la gestion du timer de jeu (5 minutes)
/// Principe SOLID: Single Responsibility - Uniquement le timer
class TimerManager {
  static const int totalSeconds = 5 * 60; // 5 minutes

  Timer? _timer;
  int _remainingSeconds = totalSeconds;

  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _timer != null && _timer!.isActive;

  // Stream pour notifier les changements de temps
  final StreamController<int> _timerController = StreamController<int>.broadcast();
  Stream<int> get timerStream => _timerController.stream;

  // Callback quand le temps est écoulé
  Function()? onTimerEnd;

  /// Démarre le timer
  void start({Function()? onEnd}) {
    if (isRunning) {
      AppLogger.warning('[TimerManager] Timer déjà en cours');
      return;
    }

    onTimerEnd = onEnd;
    _remainingSeconds = totalSeconds;

    AppLogger.info('[TimerManager] Démarrage du timer: ${formatTime(_remainingSeconds)}');

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _remainingSeconds = 0;
        _timerController.add(_remainingSeconds);

        AppLogger.success('[TimerManager] Timer terminé!');

        if (onTimerEnd != null) {
          onTimerEnd!();
        }
      } else {
        _remainingSeconds--;
        _timerController.add(_remainingSeconds);

        // Log toutes les minutes
        if (_remainingSeconds % 60 == 0) {
          AppLogger.info('[TimerManager] Temps restant: ${formatTime(_remainingSeconds)}');
        }
      }
    });
  }

  /// Arrête le timer
  void stop() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
      AppLogger.info('[TimerManager] Timer arrêté');
    }
  }

  /// Met le timer en pause
  void pause() {
    stop();
  }

  /// Reprend le timer
  void resume({Function()? onEnd}) {
    if (!isRunning && _remainingSeconds > 0) {
      start(onEnd: onEnd);
    }
  }

  /// Réinitialise le timer
  void reset() {
    stop();
    _remainingSeconds = totalSeconds;
    _timerController.add(_remainingSeconds);
    AppLogger.info('[TimerManager] Timer réinitialisé');
  }

  /// Formate le temps en MM:SS
  String formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  /// Obtient le temps formaté actuel
  String get formattedTime => formatTime(_remainingSeconds);

  /// Obtient les minutes restantes
  int get remainingMinutes => _remainingSeconds ~/ 60;

  /// Vérifie si le temps est presque écoulé (< 1 minute)
  bool get isAlmostOver => _remainingSeconds < 60;

  /// Vérifie si le temps est écoulé
  bool get isTimeUp => _remainingSeconds == 0;

  /// Nettoie les ressources
  void dispose() {
    stop();
    _timerController.close();
  }
}
