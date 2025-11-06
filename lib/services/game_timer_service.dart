import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// État du timer de jeu
enum GameTimerState {
  idle,     // Non démarré
  running,  // En cours
  paused,   // En pause
  finished, // Terminé
}

/// Service responsable de gérer le timer du jeu (5 minutes)
///
/// Principe SOLID:
/// - Single Responsibility Principle: UNE responsabilité - gérer le timer
/// - Dependency Inversion Principle: Dépend de callbacks, pas de concrétions
/// - Open/Closed Principle: Extensible via callbacks sans modifier le code
class GameTimerService {
  /// Durée totale du jeu en secondes (5 minutes = 300 secondes)
  final int totalDurationSeconds;

  /// Callback appelé à chaque tick (chaque seconde)
  /// Reçoit le temps restant en secondes
  final void Function(int remainingSeconds)? onTick;

  /// Callback appelé quand le timer se termine
  final VoidCallback? onTimeout;

  /// Timer interne
  Timer? _timer;

  /// Temps restant en secondes
  int _remainingSeconds;

  /// État actuel du timer
  GameTimerState _state = GameTimerState.idle;

  GameTimerService({
    this.totalDurationSeconds = 300, // 5 minutes par défaut
    this.onTick,
    this.onTimeout,
  }) : _remainingSeconds = totalDurationSeconds;

  /// État actuel (read-only)
  GameTimerState get state => _state;

  /// Temps restant en secondes (read-only)
  int get remainingSeconds => _remainingSeconds;

  /// Temps écoulé en secondes
  int get elapsedSeconds => totalDurationSeconds - _remainingSeconds;

  /// Progression en pourcentage (0.0 à 1.0)
  double get progress => elapsedSeconds / totalDurationSeconds;

  /// Vérifie si le timer est actif
  bool get isRunning => _state == GameTimerState.running;

  /// Vérifie si le timer est en pause
  bool get isPaused => _state == GameTimerState.paused;

  /// Vérifie si le timer est terminé
  bool get isFinished => _state == GameTimerState.finished;

  /// Démarre le timer
  ///
  /// Si le timer est en pause, reprend depuis le temps restant
  /// Si le timer est idle, démarre un nouveau timer
  /// Ne fait rien si le timer est déjà terminé
  void start() {
    if (_state == GameTimerState.finished) {
      AppLogger.warning('[GameTimerService] Timer déjà terminé, impossible de démarrer');
      return;
    }

    if (_state == GameTimerState.running) {
      AppLogger.warning('[GameTimerService] Timer déjà en cours');
      return;
    }

    _state = GameTimerState.running;
    AppLogger.info('[GameTimerService] Timer démarré: ${_remainingSeconds}s restants');

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state != GameTimerState.running) {
        return; // Ne pas décrémenter si en pause
      }

      _remainingSeconds--;

      // Notifier le tick
      onTick?.call(_remainingSeconds);

      AppLogger.info('[GameTimerService] Tick: ${_remainingSeconds}s restants (${(progress * 100).toStringAsFixed(1)}%)');

      // Vérifier si terminé
      if (_remainingSeconds <= 0) {
        _finish();
      }
    });
  }

  /// Met le timer en pause
  ///
  /// Garde le temps restant en mémoire
  /// Peut être repris avec start()
  void pause() {
    if (_state != GameTimerState.running) {
      AppLogger.warning('[GameTimerService] Timer non actif, impossible de mettre en pause');
      return;
    }

    _state = GameTimerState.paused;
    AppLogger.info('[GameTimerService] Timer mis en pause: ${_remainingSeconds}s restants');
  }

  /// Reprend le timer après une pause
  ///
  /// Alias pour start() - plus lisible dans le code
  void resume() {
    if (_state != GameTimerState.paused) {
      AppLogger.warning('[GameTimerService] Timer non en pause, impossible de reprendre');
      return;
    }

    AppLogger.info('[GameTimerService] Timer repris');
    _state = GameTimerState.idle; // Reset state pour permettre start()
    start();
  }

  /// Arrête le timer complètement
  ///
  /// Annule le timer et réinitialise à l'état idle
  void stop() {
    _timer?.cancel();
    _timer = null;
    _state = GameTimerState.idle;
    _remainingSeconds = totalDurationSeconds;

    AppLogger.info('[GameTimerService] Timer arrêté et réinitialisé');
  }

  /// Termine le timer
  ///
  /// Appelé automatiquement quand le temps est écoulé
  /// Peut aussi être appelé manuellement pour forcer la fin
  void _finish() {
    _timer?.cancel();
    _timer = null;
    _state = GameTimerState.finished;
    _remainingSeconds = 0;

    AppLogger.success('[GameTimerService] Timer terminé!');

    // Notifier le timeout
    onTimeout?.call();
  }

  /// Forcer la fin du timer manuellement
  void forceFinish() {
    AppLogger.warning('[GameTimerService] Timer forcé à se terminer');
    _finish();
  }

  /// Nettoie les ressources
  ///
  /// IMPORTANT: Toujours appeler dispose() pour éviter les fuites mémoire
  void dispose() {
    _timer?.cancel();
    _timer = null;
    AppLogger.info('[GameTimerService] Timer disposed');
  }

  /// Formatte le temps restant en MM:SS
  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Retourne le temps restant formaté
  String get formattedRemainingTime => formatTime(_remainingSeconds);

  /// Retourne le temps écoulé formaté
  String get formattedElapsedTime => formatTime(elapsedSeconds);
}
