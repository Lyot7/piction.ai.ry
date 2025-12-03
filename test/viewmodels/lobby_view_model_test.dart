import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:piction_ai_ry/interfaces/facades/auth_facade_interface.dart';
import 'package:piction_ai_ry/interfaces/facades/session_facade_interface.dart';
import 'package:piction_ai_ry/models/game_session.dart';
import 'package:piction_ai_ry/models/player.dart';
import 'package:piction_ai_ry/viewmodels/lobby_view_model.dart';

import '../helpers/test_data.dart';
import 'lobby_view_model_test.mocks.dart';

@GenerateMocks([IAuthFacade, ISessionFacade])
void main() {
  late MockIAuthFacade mockAuthFacade;
  late MockISessionFacade mockSessionFacade;
  late LobbyViewModel viewModel;
  late StreamController<Player?> playerStreamController;
  late StreamController<GameSession?> sessionStreamController;

  setUp(() {
    mockAuthFacade = MockIAuthFacade();
    mockSessionFacade = MockISessionFacade();
    playerStreamController = StreamController<Player?>.broadcast();
    sessionStreamController = StreamController<GameSession?>.broadcast();

    when(mockAuthFacade.playerStream).thenAnswer((_) => playerStreamController.stream);
    when(mockSessionFacade.gameSessionStream).thenAnswer((_) => sessionStreamController.stream);

    viewModel = LobbyViewModel(
      authFacade: mockAuthFacade,
      sessionFacade: mockSessionFacade,
    );
  });

  tearDown(() {
    viewModel.dispose();
    playerStreamController.close();
    sessionStreamController.close();
  });

  group('LobbyViewModel', () {
    group('initialization', () {
      test('should have initial state correctly set', () {
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.errorMessage, isNull);
        expect(viewModel.isChangingTeam, isFalse);
        expect(viewModel.playersTransitioning, isEmpty);
      });

      test('should expose currentGameSession from sessionFacade', () {
        final session = TestData.sessionWith4Players();
        when(mockSessionFacade.currentGameSession).thenReturn(session);

        expect(viewModel.currentGameSession, equals(session));
      });

      test('should expose currentPlayer from authFacade', () {
        final player = TestData.player1Host();
        when(mockAuthFacade.currentPlayer).thenReturn(player);

        expect(viewModel.currentPlayer, equals(player));
      });
    });

    group('isHost', () {
      test('should return true when player is host by hostId', () {
        final player = TestData.player1Host();
        final session = GameSession(
          id: 'test-session',
          status: 'lobby',
          players: [player],
          createdAt: DateTime.now(),
          hostId: player.id,
        );

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionFacade.currentGameSession).thenReturn(session);

        expect(viewModel.isHost, isTrue);
      });

      test('should return true when player.isHost is true', () {
        final player = TestData.player1Host(isHost: true);
        final session = GameSession(
          id: 'test-session',
          status: 'lobby',
          players: [player],
          createdAt: DateTime.now(),
        );

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionFacade.currentGameSession).thenReturn(session);

        expect(viewModel.isHost, isTrue);
      });

      test('should return false when player is not host', () {
        final player = TestData.player2();
        final session = TestData.sessionWith4Players();

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionFacade.currentGameSession).thenReturn(session);

        expect(viewModel.isHost, isFalse);
      });

      test('should return false when session is null', () {
        when(mockAuthFacade.currentPlayer).thenReturn(TestData.player1Host());
        when(mockSessionFacade.currentGameSession).thenReturn(null);

        expect(viewModel.isHost, isFalse);
      });

      test('should return false when player is null', () {
        when(mockAuthFacade.currentPlayer).thenReturn(null);
        when(mockSessionFacade.currentGameSession).thenReturn(TestData.sessionWith4Players());

        expect(viewModel.isHost, isFalse);
      });
    });

    group('canStartGame', () {
      test('should return true when host and session is ready', () {
        final player = TestData.player1Host();
        final session = TestData.sessionWith4Players();

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionFacade.currentGameSession).thenReturn(session);

        expect(viewModel.canStartGame(), isTrue);
      });

      test('should return false when not host', () {
        final player = TestData.player2();
        final session = TestData.sessionWith4Players();

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionFacade.currentGameSession).thenReturn(session);

        expect(viewModel.canStartGame(), isFalse);
      });

      test('should return false when session not ready', () {
        final player = TestData.player1Host();
        final session = TestData.sessionWith2Players();

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionFacade.currentGameSession).thenReturn(session);

        expect(viewModel.canStartGame(), isFalse);
      });

      test('should return false when session is null', () {
        when(mockAuthFacade.currentPlayer).thenReturn(TestData.player1Host());
        when(mockSessionFacade.currentGameSession).thenReturn(null);

        expect(viewModel.canStartGame(), isFalse);
      });
    });

    group('startGame', () {
      test('should start game successfully when can start', () async {
        final player = TestData.player1Host();
        final session = TestData.sessionWith4Players();

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockSessionFacade.startGameSession()).thenAnswer((_) async {});

        final result = await viewModel.startGame();

        expect(result, isTrue);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.errorMessage, isNull);
        verify(mockSessionFacade.startGameSession()).called(1);
      });

      test('should return false when canStartGame is false', () async {
        final player = TestData.player2();
        final session = TestData.sessionWith4Players();

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionFacade.currentGameSession).thenReturn(session);

        final result = await viewModel.startGame();

        expect(result, isFalse);
        verifyNever(mockSessionFacade.startGameSession());
      });

      test('should handle error during start game', () async {
        final player = TestData.player1Host();
        final session = TestData.sessionWith4Players();

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockSessionFacade.startGameSession())
            .thenThrow(Exception('Network error'));

        final result = await viewModel.startGame();

        expect(result, isFalse);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.errorMessage, contains('Network error'));
      });

      test('should set isLoading true during operation', () async {
        final player = TestData.player1Host();
        final session = TestData.sessionWith4Players();
        final completer = Completer<void>();

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockSessionFacade.startGameSession())
            .thenAnswer((_) => completer.future);

        final future = viewModel.startGame();

        expect(viewModel.isLoading, isTrue);

        completer.complete();
        await future;

        expect(viewModel.isLoading, isFalse);
      });
    });

    group('handleTeamClick', () {
      test('should do nothing when already in team', () async {
        final player = TestData.player1Host(color: 'red');
        final session = TestData.sessionWith4Players();

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionFacade.currentGameSession).thenReturn(session);

        await viewModel.handleTeamClick('red', true);

        verifyNever(mockSessionFacade.changeTeam(any, any));
      });

      test('should set error when team is full', () async {
        final player = TestData.player3(color: 'blue');
        final session = TestData.sessionWith4Players();

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionFacade.currentGameSession).thenReturn(session);

        await viewModel.handleTeamClick('red', false);

        expect(viewModel.errorMessage, contains('complète'));
        verifyNever(mockSessionFacade.changeTeam(any, any));
      });

      test('should change team when team has space', () async {
        final player = TestData.player1Host(color: 'red');
        final session = GameSession(
          id: 'test-session',
          status: 'lobby',
          players: [player, TestData.player3(color: 'blue')],
          createdAt: DateTime.now(),
        );

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockSessionFacade.changeTeam(any, any)).thenAnswer((_) async {});

        await viewModel.handleTeamClick('blue', false);

        verify(mockSessionFacade.changeTeam('test-session', 'blue')).called(1);
      });

      test('should not change team when isChangingTeam is true', () async {
        final player = TestData.player1Host(color: 'red');
        final session = TestData.sessionWith2Players();
        final completer = Completer<void>();

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockSessionFacade.changeTeam(any, any))
            .thenAnswer((_) => completer.future);

        // Start first change
        viewModel.handleTeamClick('blue', false);

        // Try second change while first is in progress
        await viewModel.handleTeamClick('blue', false);

        // Only one call should have been made
        verify(mockSessionFacade.changeTeam(any, any)).called(1);

        completer.complete();
      });
    });

    group('changeTeam', () {
      test('should change team successfully', () async {
        final session = TestData.sessionWith2Players();

        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockSessionFacade.changeTeam(any, any)).thenAnswer((_) async {});

        await viewModel.changeTeam('blue');

        expect(viewModel.isChangingTeam, isFalse);
        expect(viewModel.errorMessage, isNull);
        verify(mockSessionFacade.changeTeam(session.id, 'blue')).called(1);
      });

      test('should handle error during change team', () async {
        final session = TestData.sessionWith2Players();

        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockSessionFacade.changeTeam(any, any))
            .thenThrow(Exception('Team full'));

        await viewModel.changeTeam('red');

        expect(viewModel.isChangingTeam, isFalse);
        expect(viewModel.errorMessage, contains('Team full'));
      });

      test('should do nothing when session is null', () async {
        when(mockSessionFacade.currentGameSession).thenReturn(null);

        await viewModel.changeTeam('blue');

        verifyNever(mockSessionFacade.changeTeam(any, any));
      });
    });

    group('polling', () {
      test('should start and stop polling correctly', () async {
        final session = TestData.sessionWith4Players();

        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockSessionFacade.refreshGameSession(any)).thenAnswer((_) async {});

        viewModel.startPolling(intervalSeconds: 1);

        // Wait for one interval
        await Future.delayed(const Duration(milliseconds: 1100));

        verify(mockSessionFacade.refreshGameSession(session.id)).called(greaterThan(0));

        viewModel.stopPolling();
      });

      test('should refresh session on poll', () async {
        final session = TestData.sessionWith4Players();

        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockSessionFacade.refreshGameSession(any)).thenAnswer((_) async {});

        await viewModel.refreshSession();

        verify(mockSessionFacade.refreshGameSession(session.id)).called(1);
      });

      test('should handle error during refresh silently', () async {
        final session = TestData.sessionWith4Players();

        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockSessionFacade.refreshGameSession(any))
            .thenThrow(Exception('Network error'));

        // Should not throw
        await viewModel.refreshSession();
      });
    });

    group('leaveSession', () {
      test('should leave session successfully', () async {
        when(mockSessionFacade.leaveGameSession()).thenAnswer((_) async {});

        await viewModel.leaveSession();

        expect(viewModel.isLoading, isFalse);
        verify(mockSessionFacade.leaveGameSession()).called(1);
      });

      test('should handle error during leave', () async {
        when(mockSessionFacade.leaveGameSession())
            .thenThrow(Exception('Leave failed'));

        await viewModel.leaveSession();

        expect(viewModel.isLoading, isFalse);
        expect(viewModel.errorMessage, contains('Leave failed'));
      });
    });

    group('isPlayerInTeam', () {
      test('should return true when player is in specified team', () {
        final player = TestData.player1Host(color: 'red');
        final session = TestData.sessionWith4Players();

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionFacade.currentGameSession).thenReturn(session);

        expect(viewModel.isPlayerInTeam('red'), isTrue);
        expect(viewModel.isPlayerInTeam('blue'), isFalse);
      });

      test('should return false when session is null', () {
        when(mockAuthFacade.currentPlayer).thenReturn(TestData.player1Host());
        when(mockSessionFacade.currentGameSession).thenReturn(null);

        expect(viewModel.isPlayerInTeam('red'), isFalse);
      });

      test('should return false when player is null', () {
        when(mockAuthFacade.currentPlayer).thenReturn(null);
        when(mockSessionFacade.currentGameSession).thenReturn(TestData.sessionWith4Players());

        expect(viewModel.isPlayerInTeam('red'), isFalse);
      });
    });

    group('getTeamPlayers', () {
      test('should return players of specified team', () {
        final session = TestData.sessionWith4Players();

        when(mockSessionFacade.currentGameSession).thenReturn(session);

        final redPlayers = viewModel.getTeamPlayers('red');
        final bluePlayers = viewModel.getTeamPlayers('blue');

        expect(redPlayers.length, equals(2));
        expect(bluePlayers.length, equals(2));
        expect(redPlayers.every((p) => p.color == 'red'), isTrue);
        expect(bluePlayers.every((p) => p.color == 'blue'), isTrue);
      });

      test('should return empty list when session is null', () {
        when(mockSessionFacade.currentGameSession).thenReturn(null);

        expect(viewModel.getTeamPlayers('red'), isEmpty);
      });
    });

    group('dispose', () {
      test('should stop polling on dispose', () async {
        // Create a separate viewModel for this test to avoid double-dispose
        final testViewModel = LobbyViewModel(
          authFacade: mockAuthFacade,
          sessionFacade: mockSessionFacade,
        );

        final session = TestData.sessionWith4Players();

        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockSessionFacade.refreshGameSession(any)).thenAnswer((_) async {});

        testViewModel.startPolling(intervalSeconds: 1);

        // Wait for at least one poll
        await Future.delayed(const Duration(milliseconds: 1100));

        // Should stop polling without exception
        testViewModel.dispose();

        // The test passes if no exception is thrown
      });
    });

    group('notifyListeners', () {
      test('should notify listeners on state change', () async {
        final session = TestData.sessionWith4Players();
        var notificationCount = 0;

        when(mockSessionFacade.currentGameSession).thenReturn(session);
        when(mockSessionFacade.refreshGameSession(any)).thenAnswer((_) async {});

        viewModel.addListener(() {
          notificationCount++;
        });

        await viewModel.refreshSession();

        expect(notificationCount, greaterThan(0));
      });
    });
  });
}
