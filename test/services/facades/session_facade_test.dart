import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:piction_ai_ry/interfaces/facades/auth_facade_interface.dart';
import 'package:piction_ai_ry/interfaces/session_api_interface.dart';
import 'package:piction_ai_ry/managers/role_manager.dart';
import 'package:piction_ai_ry/managers/team_manager.dart';
import 'package:piction_ai_ry/models/game_session.dart';
import 'package:piction_ai_ry/models/player.dart';
import 'package:piction_ai_ry/services/facades/session_facade.dart';

import '../../helpers/test_data.dart';
import 'session_facade_test.mocks.dart';

@GenerateMocks([ISessionApi, IAuthFacade, TeamManager, RoleManager])
void main() {
  late MockISessionApi mockSessionApi;
  late MockIAuthFacade mockAuthFacade;
  late MockTeamManager mockTeamManager;
  late MockRoleManager mockRoleManager;
  late SessionFacade sessionFacade;
  late StreamController<Player?> playerStreamController;

  setUp(() {
    mockSessionApi = MockISessionApi();
    mockAuthFacade = MockIAuthFacade();
    mockTeamManager = MockTeamManager();
    mockRoleManager = MockRoleManager();
    playerStreamController = StreamController<Player?>.broadcast();

    when(mockAuthFacade.playerStream)
        .thenAnswer((_) => playerStreamController.stream);

    sessionFacade = SessionFacade(
      sessionApi: mockSessionApi,
      authFacade: mockAuthFacade,
      teamManager: mockTeamManager,
      roleManager: mockRoleManager,
    );
  });

  tearDown(() {
    sessionFacade.dispose();
    playerStreamController.close();
  });

  group('SessionFacade', () {
    group('createGameSession', () {
      test('should create session and set hostId to current player', () async {
        final player = TestData.player1Host();
        final session = GameSession(
          id: 'new-session',
          status: 'lobby',
          players: [player],
          createdAt: DateTime.now(),
        );

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionApi.createGameSession())
            .thenAnswer((_) async => session);

        final result = await sessionFacade.createGameSession();

        expect(result.id, equals('new-session'));
        expect(result.hostId, equals(player.id));
        expect(sessionFacade.currentGameSession, isNotNull);
        verify(mockSessionApi.createGameSession()).called(1);
      });

      test('should emit session on gameSessionStream', () async {
        final player = TestData.player1Host();
        final session = TestData.sessionWithHost();

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionApi.createGameSession())
            .thenAnswer((_) async => session);

        final sessionFuture = sessionFacade.gameSessionStream.first;
        await sessionFacade.createGameSession();
        final emittedSession = await sessionFuture;

        expect(emittedSession?.id, equals(session.id));
      });
    });

    group('joinGameSession', () {
      test('should join and refresh session', () async {
        final session = TestData.sessionWith4Players();

        when(mockSessionApi.joinGameSession(any, any))
            .thenAnswer((_) async {});
        when(mockSessionApi.getGameSession(any))
            .thenAnswer((_) async => session);

        await sessionFacade.joinGameSession('test-session', 'red');

        verify(mockSessionApi.joinGameSession('test-session', 'red')).called(1);
        verify(mockSessionApi.getGameSession('test-session')).called(1);
        expect(sessionFacade.currentGameSession?.id, equals(session.id));
      });
    });

    group('joinAvailableTeam', () {
      test('should throw when player not logged in', () async {
        when(mockAuthFacade.currentPlayer).thenReturn(null);

        expect(
          () => sessionFacade.joinAvailableTeam('test-session'),
          throwsException,
        );
      });

      test('should join red team when it has fewer players', () async {
        final session = GameSession(
          id: 'test-session',
          status: 'lobby',
          players: [TestData.player3(color: 'blue')],
          createdAt: DateTime.now(),
        );

        when(mockAuthFacade.currentPlayer).thenReturn(TestData.player1Host());
        when(mockSessionApi.getGameSession(any))
            .thenAnswer((_) async => session);
        when(mockSessionApi.joinGameSession(any, any))
            .thenAnswer((_) async {});

        await sessionFacade.joinAvailableTeam('test-session');

        verify(mockSessionApi.joinGameSession('test-session', 'red')).called(1);
      });

      test('should join blue team when red is full', () async {
        final session = GameSession(
          id: 'test-session',
          status: 'lobby',
          players: [
            TestData.player1Host(color: 'red'),
            TestData.player2(color: 'red'),
          ],
          createdAt: DateTime.now(),
        );

        when(mockAuthFacade.currentPlayer).thenReturn(TestData.player3());
        when(mockSessionApi.getGameSession(any))
            .thenAnswer((_) async => session);
        when(mockSessionApi.joinGameSession(any, any))
            .thenAnswer((_) async {});

        await sessionFacade.joinAvailableTeam('test-session');

        verify(mockSessionApi.joinGameSession('test-session', 'blue')).called(1);
      });
    });

    group('refreshGameSession', () {
      test('should update current session', () async {
        final session = TestData.sessionWith4Players();

        when(mockSessionApi.getGameSession(any))
            .thenAnswer((_) async => session);

        await sessionFacade.refreshGameSession('test-session');

        expect(sessionFacade.currentGameSession, equals(session));
      });

      test('should preserve hostId when backend does not return it', () async {
        final initialSession = GameSession(
          id: 'test-session',
          status: 'lobby',
          players: [TestData.player1Host()],
          createdAt: DateTime.now(),
          hostId: 'player-1-id',
        );
        final refreshedSession = GameSession(
          id: 'test-session',
          status: 'lobby',
          players: [TestData.player1Host()],
          createdAt: DateTime.now(),
          hostId: null, // Backend doesn't return hostId
        );

        when(mockAuthFacade.currentPlayer).thenReturn(TestData.player1Host());
        when(mockSessionApi.createGameSession())
            .thenAnswer((_) async => initialSession);
        when(mockSessionApi.getGameSession(any))
            .thenAnswer((_) async => refreshedSession);

        await sessionFacade.createGameSession();
        await sessionFacade.refreshGameSession('test-session');

        expect(sessionFacade.currentGameSession?.hostId, equals('player-1-id'));
      });
    });

    group('leaveGameSession', () {
      test('should leave and clear current session', () async {
        final session = TestData.sessionWith4Players();

        when(mockSessionApi.getGameSession(any))
            .thenAnswer((_) async => session);
        when(mockSessionApi.leaveGameSession(any)).thenAnswer((_) async {});

        await sessionFacade.refreshGameSession('test-session');
        expect(sessionFacade.currentGameSession, isNotNull);

        await sessionFacade.leaveGameSession();

        expect(sessionFacade.currentGameSession, isNull);
        verify(mockSessionApi.leaveGameSession('session-4-players')).called(1);
      });

      test('should do nothing when no session', () async {
        await sessionFacade.leaveGameSession();

        verifyNever(mockSessionApi.leaveGameSession(any));
      });
    });

    group('startGameSession', () {
      test('should throw when no active session', () async {
        expect(
          () => sessionFacade.startGameSession(),
          throwsException,
        );
      });

      test('should start session successfully', () async {
        final session = TestData.sessionWith4Players();
        final player = TestData.player1Host();

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionApi.createGameSession())
            .thenAnswer((_) async => session);
        when(mockSessionApi.startGameSession(any)).thenAnswer((_) async {});
        when(mockSessionApi.getGameSession(any))
            .thenAnswer((_) async => session.copyWith(status: 'challenge'));
        when(mockRoleManager.allPlayersHaveRoles(any)).thenReturn(true);

        await sessionFacade.createGameSession();
        await sessionFacade.startGameSession();

        verify(mockSessionApi.startGameSession(session.id)).called(1);
      });

      test('should not start if session not in lobby status', () async {
        final session = TestData.sessionWith4Players(status: 'playing');
        final player = TestData.player1Host();

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionApi.createGameSession())
            .thenAnswer((_) async => session);

        await sessionFacade.createGameSession();
        await sessionFacade.startGameSession();

        verifyNever(mockSessionApi.startGameSession(any));
      });

      test('should assign roles if players do not have them', () async {
        final session = TestData.sessionWith4Players();
        final player = TestData.player1Host();

        when(mockAuthFacade.currentPlayer).thenReturn(player);
        when(mockSessionApi.createGameSession())
            .thenAnswer((_) async => session);
        when(mockSessionApi.startGameSession(any)).thenAnswer((_) async {});
        when(mockSessionApi.getGameSession(any))
            .thenAnswer((_) async => session.copyWith(status: 'challenge'));
        when(mockRoleManager.allPlayersHaveRoles(any)).thenReturn(false);
        when(mockRoleManager.assignInitialRoles(any)).thenReturn(session);

        await sessionFacade.createGameSession();
        await sessionFacade.startGameSession();

        verify(mockRoleManager.assignInitialRoles(any)).called(1);
      });
    });

    group('changeTeam', () {
      test('should throw when player not logged in', () async {
        when(mockAuthFacade.currentPlayer).thenReturn(null);

        expect(
          () => sessionFacade.changeTeam('session-id', 'blue'),
          throwsException,
        );
      });

      test('should change team and refresh session', () async {
        final session = TestData.sessionWith4Players();

        when(mockAuthFacade.currentPlayer).thenReturn(TestData.player1Host());
        when(mockTeamManager.changeTeam(any, any)).thenAnswer((_) async {});
        when(mockSessionApi.getGameSession(any))
            .thenAnswer((_) async => session);

        await sessionFacade.changeTeam('test-session', 'blue');

        verify(mockTeamManager.changeTeam('test-session', 'blue')).called(1);
        verify(mockSessionApi.getGameSession('test-session')).called(1);
      });
    });

    group('currentGameSession', () {
      test('should return null initially', () {
        expect(sessionFacade.currentGameSession, isNull);
      });
    });

    group('gameSessionStream', () {
      test('should be a broadcast stream', () {
        final stream = sessionFacade.gameSessionStream;

        // Should not throw - can have multiple listeners
        stream.listen((_) {});
        stream.listen((_) {});
      });
    });
  });
}
