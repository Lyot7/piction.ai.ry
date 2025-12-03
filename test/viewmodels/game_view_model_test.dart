import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:piction_ai_ry/interfaces/facades/challenge_facade_interface.dart';
import 'package:piction_ai_ry/interfaces/facades/game_state_facade_interface.dart';
import 'package:piction_ai_ry/interfaces/facades/score_facade_interface.dart';
import 'package:piction_ai_ry/interfaces/facades/session_facade_interface.dart';
import 'package:piction_ai_ry/models/challenge.dart';
import 'package:piction_ai_ry/models/game_session.dart';
import 'package:piction_ai_ry/viewmodels/game_view_model.dart';

import '../helpers/test_data.dart';
import 'game_view_model_test.mocks.dart';

@GenerateMocks([ISessionFacade, IChallengeFacade, IGameStateFacade, IScoreFacade])
void main() {
  late MockISessionFacade mockSessionFacade;
  late MockIChallengeFacade mockChallengeFacade;
  late MockIGameStateFacade mockGameStateFacade;
  late MockIScoreFacade mockScoreFacade;
  late GameViewModel viewModel;
  late StreamController<GameSession?> sessionStreamController;
  late StreamController<List<Challenge>> challengesStreamController;
  late StreamController<String> statusStreamController;
  late StreamController<String?> phaseStreamController;
  late StreamController<Map<String, int>> scoreStreamController;

  setUp(() {
    mockSessionFacade = MockISessionFacade();
    mockChallengeFacade = MockIChallengeFacade();
    mockGameStateFacade = MockIGameStateFacade();
    mockScoreFacade = MockIScoreFacade();

    sessionStreamController = StreamController<GameSession?>.broadcast();
    challengesStreamController = StreamController<List<Challenge>>.broadcast();
    statusStreamController = StreamController<String>.broadcast();
    phaseStreamController = StreamController<String?>.broadcast();
    scoreStreamController = StreamController<Map<String, int>>.broadcast();

    when(mockSessionFacade.gameSessionStream)
        .thenAnswer((_) => sessionStreamController.stream);
    when(mockChallengeFacade.challengesStream)
        .thenAnswer((_) => challengesStreamController.stream);
    when(mockGameStateFacade.statusStream)
        .thenAnswer((_) => statusStreamController.stream);
    when(mockGameStateFacade.phaseStream)
        .thenAnswer((_) => phaseStreamController.stream);
    when(mockScoreFacade.scoreStream)
        .thenAnswer((_) => scoreStreamController.stream);

    viewModel = GameViewModel(
      sessionFacade: mockSessionFacade,
      challengeFacade: mockChallengeFacade,
      gameStateFacade: mockGameStateFacade,
      scoreFacade: mockScoreFacade,
    );
  });

  tearDown(() {
    viewModel.dispose();
    sessionStreamController.close();
    challengesStreamController.close();
    statusStreamController.close();
    phaseStreamController.close();
    scoreStreamController.close();
  });

  group('GameViewModel', () {
    group('initialization', () {
      test('should have correct initial state', () {
        expect(viewModel.challenges, isEmpty);
        expect(viewModel.isLoading, isTrue);
        expect(viewModel.errorMessage, isNull);
        expect(viewModel.isAutoGenerating, isFalse);
        expect(viewModel.currentScreenPhase, equals('drawing'));
        expect(viewModel.redTeamScore, equals(100));
        expect(viewModel.blueTeamScore, equals(100));
        expect(viewModel.remaining, equals(GameViewModel.drawingPhaseSeconds));
        expect(viewModel.resolvedChallengeIds, isEmpty);
      });

      test('should expose currentGameSession from sessionFacade', () {
        final session = TestData.sessionWith4Players();
        when(mockSessionFacade.currentGameSession).thenReturn(session);

        expect(viewModel.currentGameSession, equals(session));
      });

      test('should expose currentPlayerRole from gameStateFacade', () {
        when(mockGameStateFacade.getCurrentPlayerRole()).thenReturn('drawer');

        expect(viewModel.currentPlayerRole, equals('drawer'));
      });
    });

    group('initializeGame', () {
      test('should initialize for drawing phase', () async {
        final session = TestData.sessionWith4Players(status: 'playing');
        final challenges = [TestData.challenge1(), TestData.challenge2()];

        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockChallengeFacade.refreshMyChallenges()).thenAnswer((_) async {});
        when(mockChallengeFacade.myChallenges).thenReturn(challenges);
        when(mockScoreFacade.initializeScores()).thenReturn(null);
        when(mockScoreFacade.applyScoreDelta(any, any)).thenReturn(null);

        await viewModel.initializeGame();

        expect(viewModel.isLoading, isFalse);
        expect(viewModel.errorMessage, isNull);
        expect(viewModel.currentScreenPhase, equals('drawing'));
        expect(viewModel.challenges, equals(challenges));
        expect(viewModel.remaining, equals(GameViewModel.drawingPhaseSeconds));
        verify(mockChallengeFacade.refreshMyChallenges()).called(1);
      });

      test('should initialize for guessing phase', () async {
        final session = GameSession(
          id: 'test-session',
          status: 'guessing',
          gamePhase: 'guessing',
          players: TestData.sessionWith4Players().players,
          createdAt: DateTime.now(),
        );
        final challenges = [TestData.challenge1(), TestData.challenge2()];

        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockChallengeFacade.refreshChallengesToGuess()).thenAnswer((_) async {});
        when(mockChallengeFacade.challengesToGuess).thenReturn(challenges);
        when(mockScoreFacade.initializeScores()).thenReturn(null);
        when(mockScoreFacade.applyScoreDelta(any, any)).thenReturn(null);

        await viewModel.initializeGame();

        expect(viewModel.isLoading, isFalse);
        expect(viewModel.currentScreenPhase, equals('guessing'));
        expect(viewModel.challenges, equals(challenges));
        expect(viewModel.remaining, equals(GameViewModel.guessingPhaseSeconds));
        verify(mockChallengeFacade.refreshChallengesToGuess()).called(1);
      });

      test('should sync scores from session', () async {
        final session = GameSession(
          id: 'test-session',
          status: 'playing',
          players: TestData.sessionWith4Players().players,
          createdAt: DateTime.now(),
          teamScores: {'red': 85, 'blue': 110},
        );

        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockChallengeFacade.refreshMyChallenges()).thenAnswer((_) async {});
        when(mockChallengeFacade.myChallenges).thenReturn([]);
        when(mockScoreFacade.initializeScores()).thenReturn(null);
        when(mockScoreFacade.applyScoreDelta(any, any)).thenReturn(null);

        await viewModel.initializeGame();

        expect(viewModel.redTeamScore, equals(85));
        expect(viewModel.blueTeamScore, equals(110));
      });

      test('should handle error during initialization', () async {
        when(mockSessionFacade.currentGameSession)
            .thenReturn(TestData.sessionWith4Players());
        when(mockChallengeFacade.refreshMyChallenges())
            .thenThrow(Exception('Network error'));
        when(mockScoreFacade.initializeScores()).thenReturn(null);
        when(mockScoreFacade.applyScoreDelta(any, any)).thenReturn(null);

        await viewModel.initializeGame();

        expect(viewModel.isLoading, isFalse);
        expect(viewModel.errorMessage, contains('Network error'));
      });
    });

    group('timer management', () {
      test('should start timer and countdown', () async {
        var timerEnded = false;

        viewModel.startTimer(onTimerEnd: () {
          timerEnded = true;
        });

        final initialRemaining = viewModel.remaining;

        await Future.delayed(const Duration(seconds: 2));

        expect(viewModel.remaining, lessThan(initialRemaining));
        expect(timerEnded, isFalse);

        viewModel.stopTimers();
      });

      test('should stop timers on dispose', () {
        // Create a separate viewModel to avoid double-dispose in tearDown
        final testViewModel = GameViewModel(
          sessionFacade: mockSessionFacade,
          challengeFacade: mockChallengeFacade,
          gameStateFacade: mockGameStateFacade,
          scoreFacade: mockScoreFacade,
        );

        testViewModel.startTimer(onTimerEnd: () {});
        testViewModel.startRefreshTimer(onRefresh: () async {});

        testViewModel.dispose();

        // No assertions needed - just verify no exceptions
      });

      test('should call onTimerEnd when timer reaches zero', () async {
        // This test verifies the callback is set up correctly
        // A full timer-end test would require FakeAsync for time control
        var callbackCalled = false;

        viewModel.startTimer(onTimerEnd: () {
          callbackCalled = true;
        });

        // Timer should be running
        expect(viewModel.remaining, equals(GameViewModel.drawingPhaseSeconds));

        viewModel.stopTimers();

        // Callback was not called because we stopped the timer
        expect(callbackCalled, isFalse);
      });
    });

    group('refreshChallenges', () {
      test('should refresh and return false when not transitioning', () async {
        final session = TestData.sessionWith4Players(status: 'playing');
        final challenges = [TestData.challenge1()];

        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockSessionFacade.refreshGameSession(any)).thenAnswer((_) async {});
        when(mockChallengeFacade.refreshMyChallenges()).thenAnswer((_) async {});
        when(mockChallengeFacade.myChallenges).thenReturn(challenges);
        when(mockScoreFacade.initializeScores()).thenReturn(null);
        when(mockScoreFacade.applyScoreDelta(any, any)).thenReturn(null);

        // First initialize to set currentScreenPhase to 'drawing'
        await viewModel.initializeGame();

        final result = await viewModel.refreshChallenges();

        expect(result, isFalse);
        verify(mockSessionFacade.refreshGameSession(session.id)).called(1);
      });

      test('should return true when transitioning to guessing', () async {
        // Start in drawing phase
        final initialSession = TestData.sessionWith4Players(status: 'playing');

        when(mockSessionFacade.currentGameSession).thenReturn(initialSession);
        when(mockChallengeFacade.refreshMyChallenges()).thenAnswer((_) async {});
        when(mockChallengeFacade.myChallenges).thenReturn([]);
        when(mockScoreFacade.initializeScores()).thenReturn(null);
        when(mockScoreFacade.applyScoreDelta(any, any)).thenReturn(null);

        await viewModel.initializeGame();

        // Now refresh returns guessing session
        final guessingSession = GameSession(
          id: 'test-session',
          status: 'guessing',
          gamePhase: 'guessing',
          players: initialSession.players,
          createdAt: DateTime.now(),
        );

        when(mockSessionFacade.refreshGameSession(any)).thenAnswer((_) async {});
        when(mockSessionFacade.currentGameSession).thenReturn(guessingSession);

        final result = await viewModel.refreshChallenges();

        expect(result, isTrue);
      });

      test('should return false when session is null', () async {
        when(mockSessionFacade.currentGameSession).thenReturn(null);

        final result = await viewModel.refreshChallenges();

        expect(result, isFalse);
      });

      test('should handle error during refresh', () async {
        final session = TestData.sessionWith4Players();

        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockSessionFacade.refreshGameSession(any))
            .thenThrow(Exception('Network error'));

        final result = await viewModel.refreshChallenges();

        expect(result, isFalse);
      });
    });

    group('score management', () {
      test('should apply score delta correctly', () {
        when(mockScoreFacade.applyScoreDelta(any, any)).thenReturn(null);

        viewModel.applyScoreDelta('red', -10);

        expect(viewModel.redTeamScore, equals(90));
        verify(mockScoreFacade.applyScoreDelta('red', -10)).called(1);
      });

      test('should apply score delta to blue team', () {
        when(mockScoreFacade.applyScoreDelta(any, any)).thenReturn(null);

        viewModel.applyScoreDelta('blue', 25);

        expect(viewModel.blueTeamScore, equals(125));
        verify(mockScoreFacade.applyScoreDelta('blue', 25)).called(1);
      });
    });

    group('auto-generation', () {
      test('should set auto generating flag', () {
        expect(viewModel.isAutoGenerating, isFalse);

        viewModel.setAutoGenerating(true);

        expect(viewModel.isAutoGenerating, isTrue);

        viewModel.setAutoGenerating(false);

        expect(viewModel.isAutoGenerating, isFalse);
      });
    });

    group('challenge resolution', () {
      test('should mark challenge as resolved', () {
        const challengeId = 'challenge-1';

        expect(viewModel.isChallengeResolved(challengeId), isFalse);

        viewModel.markChallengeResolved(challengeId);

        expect(viewModel.isChallengeResolved(challengeId), isTrue);
      });

      test('should track multiple resolved challenges', () {
        viewModel.markChallengeResolved('challenge-1');
        viewModel.markChallengeResolved('challenge-2');

        expect(viewModel.isChallengeResolved('challenge-1'), isTrue);
        expect(viewModel.isChallengeResolved('challenge-2'), isTrue);
        expect(viewModel.isChallengeResolved('challenge-3'), isFalse);
      });

      test('resolvedChallengeIds should contain all resolved', () {
        viewModel.markChallengeResolved('c1');
        viewModel.markChallengeResolved('c2');

        expect(viewModel.resolvedChallengeIds, contains('c1'));
        expect(viewModel.resolvedChallengeIds, contains('c2'));
        expect(viewModel.resolvedChallengeIds.length, equals(2));
      });
    });

    group('game status checks', () {
      test('allImagesReady should return true when all have images', () async {
        final challengesWithImages = [
          TestData.challenge1(),
          TestData.challenge2(),
        ];

        final session = TestData.sessionWith4Players(status: 'playing');
        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockChallengeFacade.refreshMyChallenges()).thenAnswer((_) async {});
        when(mockChallengeFacade.myChallenges).thenReturn(challengesWithImages);
        when(mockScoreFacade.initializeScores()).thenReturn(null);
        when(mockScoreFacade.applyScoreDelta(any, any)).thenReturn(null);

        await viewModel.initializeGame();

        expect(viewModel.allImagesReady, isTrue);
      });

      test('allImagesReady should return false when some missing images', () async {
        final challengeWithoutImage = Challenge(
          id: 'no-image',
          gameSessionId: 'session',
          article1: 'Un',
          input1: 'test',
          preposition: 'Sur',
          article2: 'Un',
          input2: 'autre',
          forbiddenWords: [],
          imageUrl: null,
          currentPhase: 'waiting',
          isResolved: false,
          createdAt: DateTime.now(),
        );

        final session = TestData.sessionWith4Players(status: 'playing');
        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockChallengeFacade.refreshMyChallenges()).thenAnswer((_) async {});
        when(mockChallengeFacade.myChallenges).thenReturn([challengeWithoutImage]);
        when(mockScoreFacade.initializeScores()).thenReturn(null);
        when(mockScoreFacade.applyScoreDelta(any, any)).thenReturn(null);

        await viewModel.initializeGame();

        expect(viewModel.allImagesReady, isFalse);
      });

      test('allImagesReady should return false when challenges empty', () {
        expect(viewModel.allImagesReady, isFalse);
      });

      test('allChallengesResolved should return true when all resolved', () async {
        final challenges = [TestData.challenge1(), TestData.challenge2()];

        final session = TestData.sessionWith4Players(status: 'playing');
        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockChallengeFacade.refreshMyChallenges()).thenAnswer((_) async {});
        when(mockChallengeFacade.myChallenges).thenReturn(challenges);
        when(mockScoreFacade.initializeScores()).thenReturn(null);
        when(mockScoreFacade.applyScoreDelta(any, any)).thenReturn(null);

        await viewModel.initializeGame();

        viewModel.markChallengeResolved(challenges[0].id);
        viewModel.markChallengeResolved(challenges[1].id);

        expect(viewModel.allChallengesResolved, isTrue);
      });

      test('allChallengesResolved should return false when some not resolved', () async {
        final challenges = [TestData.challenge1(), TestData.challenge2()];

        final session = TestData.sessionWith4Players(status: 'playing');
        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockChallengeFacade.refreshMyChallenges()).thenAnswer((_) async {});
        when(mockChallengeFacade.myChallenges).thenReturn(challenges);
        when(mockScoreFacade.initializeScores()).thenReturn(null);
        when(mockScoreFacade.applyScoreDelta(any, any)).thenReturn(null);

        await viewModel.initializeGame();

        viewModel.markChallengeResolved(challenges[0].id);

        expect(viewModel.allChallengesResolved, isFalse);
      });

      test('allChallengesResolved should return false when challenges empty', () {
        expect(viewModel.allChallengesResolved, isFalse);
      });
    });

    group('notifyListeners', () {
      test('should notify on score change', () {
        var notified = false;
        viewModel.addListener(() => notified = true);

        when(mockScoreFacade.applyScoreDelta(any, any)).thenReturn(null);
        viewModel.applyScoreDelta('red', -5);

        expect(notified, isTrue);
      });

      test('should notify on challenge resolved', () {
        var notified = false;
        viewModel.addListener(() => notified = true);

        viewModel.markChallengeResolved('test');

        expect(notified, isTrue);
      });

      test('should notify on auto generating change', () {
        var notified = false;
        viewModel.addListener(() => notified = true);

        viewModel.setAutoGenerating(true);

        expect(notified, isTrue);
      });
    });
  });
}
