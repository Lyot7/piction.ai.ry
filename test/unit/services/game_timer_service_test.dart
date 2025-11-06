import 'package:flutter_test/flutter_test.dart';
import 'package:piction_ai_ry/services/game_timer_service.dart';

void main() {
  group('GameTimerService', () {
    group('Initial State', () {
      test('should have correct initial state', () {
        // Arrange & Act
        final timer = GameTimerService(totalDurationSeconds: 300);

        // Assert
        expect(timer.state, GameTimerState.idle);
        expect(timer.remainingSeconds, 300);
        expect(timer.elapsedSeconds, 0);
        expect(timer.progress, 0.0);
        expect(timer.isRunning, false);
        expect(timer.isPaused, false);
        expect(timer.isFinished, false);
      });

      test('should use custom duration', () {
        // Arrange & Act
        final timer = GameTimerService(totalDurationSeconds: 60);

        // Assert
        expect(timer.remainingSeconds, 60);
      });

      test('should format time correctly', () {
        // Arrange
        final timer = GameTimerService(totalDurationSeconds: 300);

        // Assert
        expect(timer.formatTime(300), '05:00');
        expect(timer.formatTime(65), '01:05');
        expect(timer.formatTime(0), '00:00');
        expect(timer.formattedRemainingTime, '05:00');
        expect(timer.formattedElapsedTime, '00:00');
      });
    });

    group('Start/Stop', () {
      test('should start timer and transition to running state', () async {
        // Arrange
        final timer = GameTimerService(totalDurationSeconds: 5);

        // Act
        timer.start();

        // Assert
        expect(timer.state, GameTimerState.running);
        expect(timer.isRunning, true);

        // Cleanup
        timer.dispose();
      });

      test('should call onTick callback each second', () async {
        // Arrange
        final tickCalls = <int>[];
        final timer = GameTimerService(
          totalDurationSeconds: 3,
          onTick: (remaining) => tickCalls.add(remaining),
        );

        // Act
        timer.start();
        await Future.delayed(const Duration(milliseconds: 3500));

        // Assert
        expect(tickCalls.length, greaterThanOrEqualTo(3));
        expect(tickCalls, containsAllInOrder([2, 1, 0]));

        // Cleanup
        timer.dispose();
      });

      test('should call onTimeout when timer finishes', () async {
        // Arrange
        bool timeoutCalled = false;
        final timer = GameTimerService(
          totalDurationSeconds: 2,
          onTimeout: () => timeoutCalled = true,
        );

        // Act
        timer.start();
        await Future.delayed(const Duration(milliseconds: 2500));

        // Assert
        expect(timeoutCalled, true);
        expect(timer.state, GameTimerState.finished);
        expect(timer.isFinished, true);

        // Cleanup
        timer.dispose();
      });

      test('should stop timer and reset to initial state', () async {
        // Arrange
        final timer = GameTimerService(totalDurationSeconds: 10);
        timer.start();
        await Future.delayed(const Duration(milliseconds: 1500));

        // Act
        timer.stop();

        // Assert
        expect(timer.state, GameTimerState.idle);
        expect(timer.remainingSeconds, 10); // Reset to initial
        expect(timer.isRunning, false);

        // Cleanup
        timer.dispose();
      });

      test('should not start if already running', () {
        // Arrange
        final timer = GameTimerService(totalDurationSeconds: 10);
        timer.start();

        // Act
        timer.start(); // Try to start again

        // Assert
        expect(timer.state, GameTimerState.running);

        // Cleanup
        timer.dispose();
      });

      test('should not start if already finished', () {
        // Arrange
        final timer = GameTimerService(totalDurationSeconds: 1);
        timer.forceFinish();

        // Act
        timer.start();

        // Assert
        expect(timer.state, GameTimerState.finished);

        // Cleanup
        timer.dispose();
      });
    });

    group('Pause/Resume', () {
      test('should pause timer and keep remaining time', () async {
        // Arrange
        final timer = GameTimerService(totalDurationSeconds: 10);
        timer.start();
        await Future.delayed(const Duration(milliseconds: 2500));

        // Act
        timer.pause();
        final pausedTime = timer.remainingSeconds;
        await Future.delayed(const Duration(milliseconds: 1000));

        // Assert
        expect(timer.state, GameTimerState.paused);
        expect(timer.isPaused, true);
        expect(timer.remainingSeconds, pausedTime); // Time should not change

        // Cleanup
        timer.dispose();
      });

      test('should resume timer from paused state', () async {
        // Arrange
        final timer = GameTimerService(totalDurationSeconds: 10);
        timer.start();
        await Future.delayed(const Duration(milliseconds: 1500));
        timer.pause();
        final pausedTime = timer.remainingSeconds;

        // Act
        timer.resume();
        await Future.delayed(const Duration(milliseconds: 1500));

        // Assert
        expect(timer.state, GameTimerState.running);
        expect(timer.isRunning, true);
        expect(timer.remainingSeconds, lessThan(pausedTime));

        // Cleanup
        timer.dispose();
      });

      test('should not pause if not running', () {
        // Arrange
        final timer = GameTimerService(totalDurationSeconds: 10);

        // Act
        timer.pause();

        // Assert
        expect(timer.state, GameTimerState.idle);

        // Cleanup
        timer.dispose();
      });

      test('should not resume if not paused', () {
        // Arrange
        final timer = GameTimerService(totalDurationSeconds: 10);

        // Act
        timer.resume();

        // Assert
        expect(timer.state, GameTimerState.idle);

        // Cleanup
        timer.dispose();
      });
    });

    group('Progress Tracking', () {
      test('should track progress correctly', () async {
        // Arrange
        final timer = GameTimerService(totalDurationSeconds: 4);

        // Act
        timer.start();
        await Future.delayed(const Duration(milliseconds: 2500));

        // Assert
        expect(timer.elapsedSeconds, greaterThanOrEqualTo(2));
        expect(timer.progress, greaterThanOrEqualTo(0.5));
        expect(timer.progress, lessThanOrEqualTo(1.0));

        // Cleanup
        timer.dispose();
      });

      test('should have 100% progress when finished', () async {
        // Arrange
        final timer = GameTimerService(totalDurationSeconds: 2);

        // Act
        timer.start();
        await Future.delayed(const Duration(milliseconds: 2500));

        // Assert
        expect(timer.progress, 1.0);
        expect(timer.remainingSeconds, 0);
        expect(timer.elapsedSeconds, 2);

        // Cleanup
        timer.dispose();
      });
    });

    group('Force Finish', () {
      test('should force finish timer manually', () async {
        // Arrange
        bool timeoutCalled = false;
        final timer = GameTimerService(
          totalDurationSeconds: 100,
          onTimeout: () => timeoutCalled = true,
        );
        timer.start();
        await Future.delayed(const Duration(milliseconds: 500));

        // Act
        timer.forceFinish();

        // Assert
        expect(timer.state, GameTimerState.finished);
        expect(timer.remainingSeconds, 0);
        expect(timeoutCalled, true);

        // Cleanup
        timer.dispose();
      });
    });

    group('Time Formatting', () {
      test('should format minutes and seconds correctly', () {
        // Arrange
        final timer = GameTimerService(totalDurationSeconds: 300);

        // Assert
        expect(timer.formatTime(0), '00:00');
        expect(timer.formatTime(1), '00:01');
        expect(timer.formatTime(59), '00:59');
        expect(timer.formatTime(60), '01:00');
        expect(timer.formatTime(61), '01:01');
        expect(timer.formatTime(300), '05:00');
        expect(timer.formatTime(3661), '61:01'); // Over 60 minutes

        // Cleanup
        timer.dispose();
      });

      test('should update formatted time as timer runs', () async {
        // Arrange
        final timer = GameTimerService(totalDurationSeconds: 5);

        // Act
        timer.start();
        await Future.delayed(const Duration(milliseconds: 1500));

        // Assert
        expect(timer.formattedRemainingTime, isNot('00:05'));
        expect(timer.formattedElapsedTime, isNot('00:00'));

        // Cleanup
        timer.dispose();
      });
    });

    group('Dispose', () {
      test('should cleanup resources on dispose', () {
        // Arrange
        final timer = GameTimerService(totalDurationSeconds: 10);
        timer.start();

        // Act
        timer.dispose();

        // Assert - Should not throw, timer should be stopped
        expect(() => timer.dispose(), returnsNormally);
      });
    });

    group('Edge Cases', () {
      test('should handle zero duration', () {
        // Arrange & Act
        final timer = GameTimerService(totalDurationSeconds: 0);

        // Assert
        expect(timer.remainingSeconds, 0);
        expect(timer.progress, isNaN); // 0/0 = NaN

        // Cleanup
        timer.dispose();
      });

      test('should handle very short duration', () async {
        // Arrange
        bool finished = false;
        final timer = GameTimerService(
          totalDurationSeconds: 1,
          onTimeout: () => finished = true,
        );

        // Act
        timer.start();
        await Future.delayed(const Duration(milliseconds: 1500));

        // Assert
        expect(finished, true);
        expect(timer.isFinished, true);

        // Cleanup
        timer.dispose();
      });

      test('should not call onTick after dispose', () async {
        // Arrange
        int tickCount = 0;
        final timer = GameTimerService(
          totalDurationSeconds: 5,
          onTick: (_) => tickCount++,
        );

        // Act
        timer.start();
        await Future.delayed(const Duration(milliseconds: 1500));
        final ticksBeforeDispose = tickCount;
        timer.dispose();
        await Future.delayed(const Duration(milliseconds: 1500));

        // Assert
        expect(tickCount, ticksBeforeDispose); // No more ticks after dispose
      });
    });
  });
}
