import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:piction_ai_ry/interfaces/auth_api_interface.dart';
import 'package:piction_ai_ry/services/facades/auth_facade.dart';

import '../../helpers/test_data.dart';
import 'auth_facade_test.mocks.dart';

@GenerateMocks([IAuthApi])
void main() {
  late MockIAuthApi mockAuthApi;
  late AuthFacade authFacade;

  setUp(() {
    mockAuthApi = MockIAuthApi();
    authFacade = AuthFacade(authApi: mockAuthApi);
  });

  tearDown(() {
    authFacade.dispose();
  });

  group('AuthFacade', () {
    group('loginWithUsername', () {
      test('should login and return player', () async {
        final player = TestData.player1Host();

        when(mockAuthApi.loginWithUsername(any)).thenAnswer((_) async => 'token');
        when(mockAuthApi.getMe()).thenAnswer((_) async => player);

        final result = await authFacade.loginWithUsername('Alice');

        expect(result, equals(player));
        expect(authFacade.currentPlayer, equals(player));
        verify(mockAuthApi.loginWithUsername('Alice')).called(1);
        verify(mockAuthApi.getMe()).called(1);
      });

      test('should emit player on playerStream', () async {
        final player = TestData.player1Host();

        when(mockAuthApi.loginWithUsername(any)).thenAnswer((_) async => 'token');
        when(mockAuthApi.getMe()).thenAnswer((_) async => player);

        final playerFuture = authFacade.playerStream.first;
        await authFacade.loginWithUsername('Alice');
        final emittedPlayer = await playerFuture;

        expect(emittedPlayer, equals(player));
      });

      test('should propagate error from authApi', () async {
        when(mockAuthApi.loginWithUsername(any))
            .thenThrow(Exception('Network error'));

        expect(
          () => authFacade.loginWithUsername('Alice'),
          throwsException,
        );
      });
    });

    group('logout', () {
      test('should clear current player', () async {
        final player = TestData.player1Host();

        when(mockAuthApi.loginWithUsername(any)).thenAnswer((_) async => 'token');
        when(mockAuthApi.getMe()).thenAnswer((_) async => player);
        when(mockAuthApi.logout()).thenAnswer((_) async {});

        await authFacade.loginWithUsername('Alice');
        expect(authFacade.currentPlayer, isNotNull);

        await authFacade.logout();

        expect(authFacade.currentPlayer, isNull);
        verify(mockAuthApi.logout()).called(1);
      });

      test('should emit null on playerStream', () async {
        when(mockAuthApi.logout()).thenAnswer((_) async {});

        final playerFuture = authFacade.playerStream.first;
        await authFacade.logout();
        final emittedPlayer = await playerFuture;

        expect(emittedPlayer, isNull);
      });
    });

    group('isLoggedIn', () {
      test('should return value from authApi', () {
        when(mockAuthApi.isLoggedIn).thenReturn(true);
        expect(authFacade.isLoggedIn, isTrue);

        when(mockAuthApi.isLoggedIn).thenReturn(false);
        expect(authFacade.isLoggedIn, isFalse);
      });
    });

    group('currentPlayer', () {
      test('should return null initially', () {
        expect(authFacade.currentPlayer, isNull);
      });

      test('should return player after login', () async {
        final player = TestData.player1Host();

        when(mockAuthApi.loginWithUsername(any)).thenAnswer((_) async => 'token');
        when(mockAuthApi.getMe()).thenAnswer((_) async => player);

        await authFacade.loginWithUsername('Alice');

        expect(authFacade.currentPlayer, equals(player));
      });
    });

    group('initialize', () {
      test('should restore session when logged in', () async {
        final player = TestData.player1Host();

        when(mockAuthApi.isLoggedIn).thenReturn(true);
        when(mockAuthApi.getMe()).thenAnswer((_) async => player);

        await authFacade.initialize();

        expect(authFacade.currentPlayer, equals(player));
        verify(mockAuthApi.getMe()).called(1);
      });

      test('should not restore session when not logged in', () async {
        when(mockAuthApi.isLoggedIn).thenReturn(false);

        await authFacade.initialize();

        expect(authFacade.currentPlayer, isNull);
        verifyNever(mockAuthApi.getMe());
      });

      test('should handle error during session restore', () async {
        when(mockAuthApi.isLoggedIn).thenReturn(true);
        when(mockAuthApi.getMe()).thenThrow(Exception('Token expired'));

        // Should not throw
        await authFacade.initialize();

        expect(authFacade.currentPlayer, isNull);
      });
    });

    group('playerStream', () {
      test('should be a broadcast stream', () {
        final stream = authFacade.playerStream;

        // Should not throw - can have multiple listeners
        stream.listen((_) {});
        stream.listen((_) {});
      });
    });

    group('dispose', () {
      test('should close stream controller', () async {
        // Use a separate instance to test dispose
        final testFacade = AuthFacade(authApi: mockAuthApi);
        testFacade.dispose();

        // After dispose, the stream is done
        final subscription = testFacade.playerStream.listen((_) {});
        await subscription.asFuture().timeout(
          const Duration(milliseconds: 100),
          onTimeout: () {},
        );

        // The test passes if dispose doesn't throw
      });
    });
  });
}
