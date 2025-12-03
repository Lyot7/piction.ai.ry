import '../../interfaces/facades/timer_facade_interface.dart';
import '../../managers/timer_manager.dart';

/// Facade de timer (ISP + SRP)
/// Responsabilité unique: Gestion du timer de jeu (5 minutes)
class TimerFacade implements ITimerFacade {
  final TimerManager _timerManager;

  TimerFacade({required TimerManager timerManager})
      : _timerManager = timerManager;

  @override
  void startTimer({required void Function() onEnd}) {
    _timerManager.start(onEnd: onEnd);
  }

  @override
  void stopTimer() {
    _timerManager.stop();
  }

  @override
  int get remainingSeconds => _timerManager.remainingSeconds;

  @override
  Stream<int> get timerStream => _timerManager.timerStream;

  @override
  void dispose() {
    _timerManager.dispose();
  }
}
