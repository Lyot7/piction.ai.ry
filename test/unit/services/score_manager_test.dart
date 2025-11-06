import 'package:flutter_test/flutter_test.dart';
import 'package:piction_ai_ry/services/score_manager.dart';

void main() {
  group('ScoreManager', () {
    late ScoreManager manager;

    setUp(() {
      manager = ScoreManager();
    });

    tearDown(() {
      manager.dispose();
    });

    group('Initial State', () {
      test('should initialize with 100 points for each team', () {
        // Assert
        expect(manager.redScore, 100);
        expect(manager.blueScore, 100);
        expect(manager.getScore(Team.red), 100);
        expect(manager.getScore(Team.blue), 100);
      });

      test('should have empty history initially', () {
        // Assert
        expect(manager.history, isEmpty);
      });

      test('should provide scores map', () {
        // Assert
        final scores = manager.scores;
        expect(scores[Team.red], 100);
        expect(scores[Team.blue], 100);
      });

      test('should have no winner initially', () {
        // Assert
        expect(manager.getWinner(), null);
      });
    });

    group('Add Points', () {
      test('should add points to red team', () {
        // Act
        manager.addPoints(Team.red, 25, reason: 'Test');

        // Assert
        expect(manager.redScore, 125);
        expect(manager.blueScore, 100);
      });

      test('should add points to blue team', () {
        // Act
        manager.addPoints(Team.blue, 25, reason: 'Test');

        // Assert
        expect(manager.redScore, 100);
        expect(manager.blueScore, 125);
      });

      test('should record score change in history', () {
        // Act
        manager.addPoints(Team.red, 25, reason: 'Test add');

        // Assert
        expect(manager.history.length, 1);
        final event = manager.history.first;
        expect(event.team, Team.red);
        expect(event.previousScore, 100);
        expect(event.newScore, 125);
        expect(event.delta, 25);
        expect(event.reason, 'Test add');
        expect(event.isPositive, true);
        expect(event.isNegative, false);
      });

      test('should not add negative points', () {
        // Act
        manager.addPoints(Team.red, -10, reason: 'Test');

        // Assert
        expect(manager.redScore, 100); // Unchanged
        expect(manager.history, isEmpty);
      });

      test('should not add zero points', () {
        // Act
        manager.addPoints(Team.red, 0, reason: 'Test');

        // Assert
        expect(manager.redScore, 100); // Unchanged
        expect(manager.history, isEmpty);
      });
    });

    group('Subtract Points', () {
      test('should subtract points from red team', () {
        // Act
        manager.subtractPoints(Team.red, 10, reason: 'Test');

        // Assert
        expect(manager.redScore, 90);
        expect(manager.blueScore, 100);
      });

      test('should subtract points from blue team', () {
        // Act
        manager.subtractPoints(Team.blue, 10, reason: 'Test');

        // Assert
        expect(manager.redScore, 100);
        expect(manager.blueScore, 90);
      });

      test('should not go below zero', () {
        // Act
        manager.subtractPoints(Team.red, 150, reason: 'Test');

        // Assert
        expect(manager.redScore, 0); // Clamped to 0
      });

      test('should record score loss in history', () {
        // Act
        manager.subtractPoints(Team.red, 10, reason: 'Penalty');

        // Assert
        expect(manager.history.length, 1);
        final event = manager.history.first;
        expect(event.team, Team.red);
        expect(event.previousScore, 100);
        expect(event.newScore, 90);
        expect(event.delta, -10);
        expect(event.reason, 'Penalty');
        expect(event.isPositive, false);
        expect(event.isNegative, true);
      });

      test('should not subtract negative points', () {
        // Act
        manager.subtractPoints(Team.red, -10, reason: 'Test');

        // Assert
        expect(manager.redScore, 100); // Unchanged
      });
    });

    group('Game Actions', () {
      test('wordFound should add 25 points', () {
        // Act
        manager.wordFound(Team.red, 'chat');

        // Assert
        expect(manager.redScore, 125);
        expect(manager.history.first.reason, 'Mot "chat" trouvé');
      });

      test('wrongGuess should subtract 1 point', () {
        // Act
        manager.wrongGuess(Team.red);

        // Assert
        expect(manager.redScore, 99);
        expect(manager.history.first.reason, 'Mauvaise réponse');
      });

      test('imageRegenerated should subtract 10 points', () {
        // Act
        manager.imageRegenerated(Team.red);

        // Assert
        expect(manager.redScore, 90);
        expect(manager.history.first.reason, 'Régénération d\'image');
      });

      test('challengeCompleted should log success', () {
        // Act - Should not throw
        manager.challengeCompleted(Team.red);

        // Assert - No score change, just logging
        expect(manager.redScore, 100);
      });
    });

    group('Multiple Score Changes', () {
      test('should handle multiple score changes for same team', () {
        // Act
        manager.wordFound(Team.red, 'chat'); // +25 -> 125
        manager.wordFound(Team.red, 'table'); // +25 -> 150
        manager.wrongGuess(Team.red); // -1 -> 149

        // Assert
        expect(manager.redScore, 149);
        expect(manager.history.length, 3);
      });

      test('should handle score changes for both teams', () {
        // Act
        manager.wordFound(Team.red, 'chat'); // Red: 125
        manager.wordFound(Team.blue, 'chien'); // Blue: 125
        manager.wrongGuess(Team.red); // Red: 124

        // Assert
        expect(manager.redScore, 124);
        expect(manager.blueScore, 125);
        expect(manager.history.length, 3);
      });

      test('should maintain correct history order', () {
        // Act
        manager.wordFound(Team.red, 'mot1');
        manager.wrongGuess(Team.blue);
        manager.imageRegenerated(Team.red);

        // Assert
        expect(manager.history[0].reason, 'Mot "mot1" trouvé');
        expect(manager.history[1].reason, 'Mauvaise réponse');
        expect(manager.history[2].reason, 'Régénération d\'image');
      });
    });

    group('Score Change Callback', () {
      test('should call onScoreChange callback', () {
        // Arrange
        ScoreChangeEvent? capturedEvent;
        final managerWithCallback = ScoreManager(
          onScoreChange: (event) => capturedEvent = event,
        );

        // Act
        managerWithCallback.addPoints(Team.red, 25, reason: 'Test callback');

        // Assert
        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.team, Team.red);
        expect(capturedEvent!.delta, 25);
        expect(capturedEvent!.reason, 'Test callback');

        // Cleanup
        managerWithCallback.dispose();
      });

      test('should call ChangeNotifier listeners', () {
        // Arrange
        int listenerCallCount = 0;
        manager.addListener(() => listenerCallCount++);

        // Act
        manager.addPoints(Team.red, 25, reason: 'Test');

        // Assert
        expect(listenerCallCount, 1);
      });
    });

    group('Reset', () {
      test('should reset scores to initial values', () {
        // Arrange
        manager.wordFound(Team.red, 'chat');
        manager.subtractPoints(Team.blue, 10, reason: 'Test');

        // Act
        manager.reset();

        // Assert
        expect(manager.redScore, 100);
        expect(manager.blueScore, 100);
        expect(manager.history, isEmpty);
      });

      test('should notify listeners on reset', () {
        // Arrange
        int listenerCallCount = 0;
        manager.addListener(() => listenerCallCount++);

        // Act
        manager.reset();

        // Assert
        expect(listenerCallCount, 1);
      });
    });

    group('Set Score', () {
      test('should set score directly', () {
        // Act
        manager.setScore(Team.red, 150, reason: 'Direct set');

        // Assert
        expect(manager.redScore, 150);
        expect(manager.history.length, 1);
        expect(manager.history.first.delta, 50);
      });

      test('should not create event if score unchanged', () {
        // Act
        manager.setScore(Team.red, 100, reason: 'Same score');

        // Assert
        expect(manager.history, isEmpty);
      });

      test('should handle score decrease', () {
        // Act
        manager.setScore(Team.red, 80, reason: 'Decrease');

        // Assert
        expect(manager.redScore, 80);
        expect(manager.history.first.delta, -20);
      });
    });

    group('Sync from API', () {
      test('should sync scores from API map', () {
        // Arrange
        final apiScores = {
          'red': 150,
          'blue': 75,
        };

        // Act
        manager.syncFromApi(apiScores);

        // Assert
        expect(manager.redScore, 150);
        expect(manager.blueScore, 75);
        expect(manager.history.length, 2);
      });

      test('should handle case-insensitive team names', () {
        // Arrange
        final apiScores = {
          'RED': 120,
          'BLUE': 130,
        };

        // Act
        manager.syncFromApi(apiScores);

        // Assert
        expect(manager.redScore, 120);
        expect(manager.blueScore, 130);
      });
    });

    group('Winner Detection', () {
      test('should return red as winner when red has higher score', () {
        // Arrange
        manager.addPoints(Team.red, 50, reason: 'Test');

        // Act
        final winner = manager.getWinner();

        // Assert
        expect(winner, Team.red);
      });

      test('should return blue as winner when blue has higher score', () {
        // Arrange
        manager.addPoints(Team.blue, 50, reason: 'Test');

        // Act
        final winner = manager.getWinner();

        // Assert
        expect(winner, Team.blue);
      });

      test('should return null when scores are equal', () {
        // Act
        final winner = manager.getWinner();

        // Assert
        expect(winner, null);
      });
    });

    group('Negative Score Detection', () {
      test('should detect when a team has negative score', () {
        // Arrange
        manager.subtractPoints(Team.red, 150, reason: 'Test');

        // Act & Assert
        expect(manager.hasNegativeScore(), false); // Clamped to 0
        expect(manager.redScore, 0);
      });

      test('should return false when all scores positive', () {
        // Act & Assert
        expect(manager.hasNegativeScore(), false);
      });
    });

    group('Statistics', () {
      test('should provide correct statistics', () {
        // Arrange
        manager.wordFound(Team.red, 'chat');
        manager.wrongGuess(Team.red);
        manager.wordFound(Team.blue, 'chien');

        // Act
        final stats = manager.getStats();

        // Assert
        expect(stats['redScore'], 124);
        expect(stats['blueScore'], 125);
        expect(stats['winner'], 'blue');
        expect(stats['totalEvents'], 3);
        expect(stats['redEvents'], 2);
        expect(stats['blueEvents'], 1);
      });
    });

    group('Team Enum', () {
      test('should convert to API string', () {
        // Assert
        expect(Team.red.toApiString(), 'red');
        expect(Team.blue.toApiString(), 'blue');
      });

      test('should parse from string', () {
        // Assert
        expect(Team.fromString('red'), Team.red);
        expect(Team.fromString('blue'), Team.blue);
        expect(Team.fromString('RED'), Team.red);
        expect(Team.fromString('BLUE'), Team.blue);
      });

      test('should default to red for unknown values', () {
        // Assert
        expect(Team.fromString('unknown'), Team.red);
      });
    });

    group('ScoreChangeEvent', () {
      test('should create event with correct data', () {
        // Arrange & Act
        final event = ScoreChangeEvent(
          team: Team.red,
          previousScore: 100,
          newScore: 125,
          delta: 25,
          reason: 'Test',
          timestamp: DateTime.now(),
        );

        // Assert
        expect(event.team, Team.red);
        expect(event.previousScore, 100);
        expect(event.newScore, 125);
        expect(event.delta, 25);
        expect(event.isPositive, true);
        expect(event.isNegative, false);
      });

      test('should format toString correctly', () {
        // Arrange & Act
        final event = ScoreChangeEvent(
          team: Team.red,
          previousScore: 100,
          newScore: 125,
          delta: 25,
          reason: 'Test',
          timestamp: DateTime.now(),
        );

        // Assert
        final str = event.toString();
        expect(str, contains('RED'));
        expect(str, contains('100 → 125'));
        expect(str, contains('+25'));
        expect(str, contains('Test'));
      });
    });
  });
}
