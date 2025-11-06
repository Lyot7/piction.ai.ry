import 'package:flutter_test/flutter_test.dart';
import 'package:piction_ai_ry/services/phase_transition_service.dart';

void main() {
  group('PhaseTransitionService', () {
    late PhaseTransitionService service;

    setUp(() {
      service = PhaseTransitionService();
    });

    tearDown(() {
      service.dispose();
    });

    test('should trigger transition when condition becomes true', () async {
      // Arrange
      bool conditionResult = false;
      bool transitionCalled = false;

      // Act
      service.startListening(
        checkCondition: () async => conditionResult,
        onTransition: () {
          transitionCalled = true;
        },
        pollingInterval: const Duration(milliseconds: 100),
      );

      // Attendre un peu pour que le premier poll ait lieu
      await Future.delayed(const Duration(milliseconds: 150));
      expect(transitionCalled, false, reason: 'Transition should not happen yet');

      // Changer la condition
      conditionResult = true;
      await Future.delayed(const Duration(milliseconds: 150));

      // Assert
      expect(transitionCalled, true, reason: 'Transition should have been triggered');
    });

    test('should not trigger transition multiple times', () async {
      // Arrange
      int transitionCount = 0;

      // Act
      service.startListening(
        checkCondition: () async => true,
        onTransition: () {
          transitionCount++;
        },
        pollingInterval: const Duration(milliseconds: 100),
      );

      // Attendre plusieurs cycles de polling
      await Future.delayed(const Duration(milliseconds: 500));

      // Assert
      expect(transitionCount, 1, reason: 'Transition should only happen once');
    });

    test('should stop listening when stopListening is called', () async {
      // Arrange
      bool transitionCalled = false;

      service.startListening(
        checkCondition: () async => true,
        onTransition: () {
          transitionCalled = true;
        },
        pollingInterval: const Duration(milliseconds: 100),
      );

      // Act
      service.stopListening();
      await Future.delayed(const Duration(milliseconds: 150));

      // Assert
      expect(transitionCalled, false, reason: 'Transition should not happen after stop');
    });

    test('should handle errors gracefully', () async {
      // Arrange
      bool transitionCalled = false;

      // Act
      service.startListening(
        checkCondition: () async {
          throw Exception('Test error');
        },
        onTransition: () {
          transitionCalled = true;
        },
        pollingInterval: const Duration(milliseconds: 100),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Assert
      expect(transitionCalled, false, reason: 'Error should not trigger transition');
    });
  });

  group('TransitionConditions', () {
    test('waitForPhase should return true when phase matches', () async {
      // Arrange
      String currentPhase = 'drawing';
      final condition = TransitionConditions.waitForPhase(
        getCurrentPhase: () async => currentPhase,
        targetPhase: 'guessing',
      );

      // Act & Assert
      expect(await condition(), false);

      currentPhase = 'guessing';
      expect(await condition(), true);
    });

    test('waitForStatus should return true when status matches', () async {
      // Arrange
      String currentStatus = 'lobby';
      final condition = TransitionConditions.waitForStatus(
        getCurrentStatus: () async => currentStatus,
        targetStatus: 'finished',
      );

      // Act & Assert
      expect(await condition(), false);

      currentStatus = 'finished';
      expect(await condition(), true);
    });

    test('waitForPlayersReady should return true when count reached', () async {
      // Arrange
      int readyPlayers = 2;
      final condition = TransitionConditions.waitForPlayersReady(
        getReadyPlayersCount: () async => readyPlayers,
        requiredCount: 4,
      );

      // Act & Assert
      expect(await condition(), false);

      readyPlayers = 4;
      expect(await condition(), true);

      readyPlayers = 5;
      expect(await condition(), true);
    });
  });
}
