import 'package:flutter_test/flutter_test.dart';
import 'package:piction_ai_ry/models/challenge.dart';
import 'package:piction_ai_ry/services/challenge_state_manager.dart';
import 'package:piction_ai_ry/interfaces/facades/challenge_facade_interface.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'challenge_state_manager_test.mocks.dart';
import '../../helpers/test_challenge_factory.dart';

@GenerateMocks([IChallengeFacade])
void main() {
  group('ChallengeStateManager', () {
    late MockIChallengeFacade mockChallengeFacade;
    late ChallengeStateManager manager;
    late List<Challenge> testChallenges;

    setUp(() {
      mockChallengeFacade = MockIChallengeFacade();
      manager = ChallengeStateManager(mockChallengeFacade);

      testChallenges = [
        TestChallengeFactory.create(
          id: '1',
          input1: 'chat',
          input2: 'table',
          forbiddenWords: const ['minou'],
        ),
        TestChallengeFactory.create(
          id: '2',
          input1: 'chien',
          input2: 'jardin',
          forbiddenWords: const ['toutou'],
        ),
      ];
    });

    tearDown(() {
      manager.dispose();
    });

    group('Initial State', () {
      test('should have empty initial state', () {
        expect(manager.state.challenges, isEmpty);
        expect(manager.state.resolvedIds, isEmpty);
        expect(manager.state.isLoading, false);
        expect(manager.state.errorMessage, null);
      });

      test('should have correct computed properties', () {
        expect(manager.state.challengesWithImages, 0);
        expect(manager.state.allImagesReady, false);
        expect(manager.state.allChallengesResolved, false);
      });
    });

    group('loadDrawingChallenges', () {
      test('should load drawing challenges successfully', () async {
        // Arrange
        when(mockChallengeFacade.refreshMyChallenges())
            .thenAnswer((_) async => Future.value());
        when(mockChallengeFacade.myChallenges).thenReturn(testChallenges);

        // Act
        await manager.loadDrawingChallenges();

        // Assert
        expect(manager.state.challenges.length, 2);
        expect(manager.state.isLoading, false);
        expect(manager.state.errorMessage, null);
        verify(mockChallengeFacade.refreshMyChallenges()).called(1);
      });

      test('should set loading state while loading', () async {
        // Arrange
        when(mockChallengeFacade.refreshMyChallenges())
            .thenAnswer((_) async => Future.delayed(const Duration(milliseconds: 100)));
        when(mockChallengeFacade.myChallenges).thenReturn(testChallenges);

        // Act
        final future = manager.loadDrawingChallenges();

        // Assert - loading should be true during the operation
        expect(manager.state.isLoading, true);

        await future;
        expect(manager.state.isLoading, false);
      });

      test('should handle errors gracefully', () async {
        // Arrange
        when(mockChallengeFacade.refreshMyChallenges())
            .thenThrow(Exception('Network error'));

        // Act
        await manager.loadDrawingChallenges();

        // Assert
        expect(manager.state.isLoading, false);
        expect(manager.state.errorMessage, isNotNull);
        expect(manager.state.errorMessage, contains('Network error'));
      });
    });

    group('loadGuessingChallenges', () {
      test('should load guessing challenges successfully', () async {
        // Arrange
        when(mockChallengeFacade.refreshChallengesToGuess())
            .thenAnswer((_) async => Future.value());
        when(mockChallengeFacade.challengesToGuess).thenReturn(testChallenges);

        // Act
        await manager.loadGuessingChallenges();

        // Assert
        expect(manager.state.challenges.length, 2);
        expect(manager.state.isLoading, false);
        verify(mockChallengeFacade.refreshChallengesToGuess()).called(1);
      });

      test('should handle errors gracefully', () async {
        // Arrange
        when(mockChallengeFacade.refreshChallengesToGuess())
            .thenThrow(Exception('API error'));

        // Act
        await manager.loadGuessingChallenges();

        // Assert
        expect(manager.state.isLoading, false);
        expect(manager.state.errorMessage, contains('API error'));
      });
    });

    group('refreshChallenges', () {
      test('should refresh challenges and return true on success', () async {
        // Arrange
        when(mockChallengeFacade.refreshMyChallenges())
            .thenAnswer((_) async => Future.value());
        when(mockChallengeFacade.myChallenges).thenReturn(testChallenges);

        // Act
        final success = await manager.refreshChallenges();

        // Assert
        expect(success, true);
        expect(manager.state.challenges.length, 2);
        expect(manager.state.errorMessage, null);
      });

      test('should return false on error and keep existing challenges', () async {
        // Arrange - Set initial challenges
        when(mockChallengeFacade.refreshMyChallenges())
            .thenAnswer((_) async => Future.value());
        when(mockChallengeFacade.myChallenges).thenReturn(testChallenges);
        await manager.loadDrawingChallenges();

        // Arrange - Make refresh fail
        when(mockChallengeFacade.refreshMyChallenges())
            .thenThrow(Exception('Refresh error'));

        // Act
        final success = await manager.refreshChallenges();

        // Assert
        expect(success, false);
        expect(manager.state.challenges.length, 2); // Challenges still there
        expect(manager.state.errorMessage, isNotNull);
      });
    });

    group('markChallengeAsResolved', () {
      test('should mark challenge as resolved', () {
        // Arrange - Load some challenges first
        when(mockChallengeFacade.refreshMyChallenges())
            .thenAnswer((_) async => Future.value());
        when(mockChallengeFacade.myChallenges).thenReturn(testChallenges);

        // Act
        manager.markChallengeAsResolved('1');

        // Assert
        expect(manager.state.resolvedIds, contains('1'));
        expect(manager.state.isChallengeResolved('1'), true);
        expect(manager.state.isChallengeResolved('2'), false);
      });

      test('should handle multiple resolved challenges', () {
        // Act
        manager.markChallengeAsResolved('1');
        manager.markChallengeAsResolved('2');

        // Assert
        expect(manager.state.resolvedIds.length, 2);
        expect(manager.state.isChallengeResolved('1'), true);
        expect(manager.state.isChallengeResolved('2'), true);
      });
    });

    group('updateImageUrl', () {
      test('should update image URL for challenge', () {
        // Arrange - Load challenges first
        when(mockChallengeFacade.refreshMyChallenges())
            .thenAnswer((_) async => Future.value());
        when(mockChallengeFacade.myChallenges).thenReturn(testChallenges);

        // Act
        manager.updateImageUrl('1', 'https://example.com/image1.png');

        // Assert
        expect(manager.state.imageUrls['1'], 'https://example.com/image1.png');
      });

      test('should update challenge in list when image URL is set', () async {
        // Arrange
        when(mockChallengeFacade.refreshMyChallenges())
            .thenAnswer((_) async => Future.value());
        when(mockChallengeFacade.myChallenges).thenReturn(testChallenges);
        await manager.loadDrawingChallenges();

        // Act
        manager.updateImageUrl('1', 'https://example.com/image1.png');

        // Assert
        final challenge = manager.state.getChallengeById('1');
        expect(challenge?.imageUrl, 'https://example.com/image1.png');
      });
    });

    group('Computed Properties', () {
      test('challengesWithImages should count challenges with images', () async {
        // Arrange
        final challengesWithImages = [
          TestChallengeFactory.create(
            id: '1',
            input1: 'chat',
            input2: 'table',
            forbiddenWords: const [],
            imageUrl: 'https://example.com/1.png',
          ),
          TestChallengeFactory.create(
            id: '2',
            input1: 'chien',
            input2: 'jardin',
            forbiddenWords: const [],
          ),
        ];

        when(mockChallengeFacade.refreshMyChallenges())
            .thenAnswer((_) async => Future.value());
        when(mockChallengeFacade.myChallenges).thenReturn(challengesWithImages);
        await manager.loadDrawingChallenges();

        // Assert
        expect(manager.state.challengesWithImages, 1);
      });

      test('allImagesReady should be true when all have images', () async {
        // Arrange
        final challengesWithImages = [
          TestChallengeFactory.create(
            id: '1',
            input1: 'chat',
            input2: 'table',
            forbiddenWords: const [],
            imageUrl: 'https://example.com/1.png',
          ),
          TestChallengeFactory.create(
            id: '2',
            input1: 'chien',
            input2: 'jardin',
            forbiddenWords: const [],
            imageUrl: 'https://example.com/2.png',
          ),
        ];

        when(mockChallengeFacade.refreshMyChallenges())
            .thenAnswer((_) async => Future.value());
        when(mockChallengeFacade.myChallenges).thenReturn(challengesWithImages);
        await manager.loadDrawingChallenges();

        // Assert
        expect(manager.state.allImagesReady, true);
      });

      test('allChallengesResolved should be true when all resolved', () async {
        // Arrange
        when(mockChallengeFacade.refreshMyChallenges())
            .thenAnswer((_) async => Future.value());
        when(mockChallengeFacade.myChallenges).thenReturn(testChallenges);
        await manager.loadDrawingChallenges();

        // Act
        manager.markChallengeAsResolved('1');
        manager.markChallengeAsResolved('2');

        // Assert
        expect(manager.state.allChallengesResolved, true);
      });
    });

    group('reset', () {
      test('should reset state to initial', () async {
        // Arrange - Load some data
        when(mockChallengeFacade.refreshMyChallenges())
            .thenAnswer((_) async => Future.value());
        when(mockChallengeFacade.myChallenges).thenReturn(testChallenges);
        await manager.loadDrawingChallenges();
        manager.markChallengeAsResolved('1');

        // Act
        manager.reset();

        // Assert
        expect(manager.state.challenges, isEmpty);
        expect(manager.state.resolvedIds, isEmpty);
        expect(manager.state.imageUrls, isEmpty);
      });
    });

    group('ChangeNotifier', () {
      test('should notify listeners when state changes', () async {
        // Arrange
        int notificationCount = 0;
        manager.addListener(() => notificationCount++);

        when(mockChallengeFacade.refreshMyChallenges())
            .thenAnswer((_) async => Future.value());
        when(mockChallengeFacade.myChallenges).thenReturn(testChallenges);

        // Act
        await manager.loadDrawingChallenges();

        // Assert
        expect(notificationCount, greaterThan(0));
      });
    });
  });
}
