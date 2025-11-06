import 'package:flutter_test/flutter_test.dart';
import 'package:piction_ai_ry/models/challenge.dart';
import 'package:piction_ai_ry/services/image_generation_service.dart';
import '../../helpers/test_challenge_factory.dart';

void main() {
  group('ImageGenerationService', () {
    late ImageGenerationService service;
    late bool phaseValid;
    late List<int> progressCalls;
    late List<Map<String, String>> generatedImages; // Track generated images

    setUp(() {
      phaseValid = true;
      progressCalls = [];
      generatedImages = [];

      // Mock image generator qui simule une génération réussie
      Future<String> mockImageGenerator(String prompt, String gameSessionId, String challengeId) async {
        generatedImages.add({
          'prompt': prompt,
          'gameSessionId': gameSessionId,
          'challengeId': challengeId,
        });
        // Simule un délai réaliste
        await Future.delayed(const Duration(milliseconds: 10));
        // ✅ Retourner une URL mockée
        return 'https://example.com/image_$challengeId.png';
      }

      service = ImageGenerationService(
        isPhaseValid: () async => phaseValid,
        onProgress: (current, total) {
          progressCalls.add(current);
        },
        imageGenerator: mockImageGenerator,
      );
    });

    group('generateImagesForChallenges', () {
      test('should generate images for all challenges successfully', () async {
        // Arrange
        final challenges = [
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

        // Act
        final result = await service.generateImagesForChallenges(
          challenges: challenges,
          gameSessionId: 'game123',
        );

        // Assert
        expect(result.successCount, 2);
        expect(result.totalCount, 2);
        expect(result.isComplete, true);
        expect(result.phaseClosed, false);
        expect(result.generatedChallengeIds, ['1', '2']);
        expect(progressCalls, [1, 2]);
      });

      test('should skip challenges that already have images', () async {
        // Arrange
        final challenges = [
          TestChallengeFactory.withImage(
            id: '1',
            imageUrl: 'https://example.com/image1.png',
          ),
          TestChallengeFactory.create(
            id: '2',
            input1: 'chien',
            input2: 'jardin',
          ),
        ];

        // Act
        final result = await service.generateImagesForChallenges(
          challenges: challenges,
          gameSessionId: 'game123',
        );

        // Assert
        expect(result.successCount, 2);
        expect(result.generatedChallengeIds.length, 2);
        expect(progressCalls, [1, 2]);
      });

      test('should stop generation when phase becomes invalid', () async {
        // Arrange
        final challenges = TestChallengeFactory.createList(3);
        final localGeneratedImages = <Map<String, String>>[];

        // Change phase after first generation
        int generationCount = 0;

        // Mock generator for this test
        Future<String> mockGenerator(String prompt, String gameSessionId, String challengeId) async {
          localGeneratedImages.add({
            'prompt': prompt,
            'gameSessionId': gameSessionId,
            'challengeId': challengeId,
          });
          await Future.delayed(const Duration(milliseconds: 10));
          return 'https://example.com/image_$challengeId.png';
        }

        service = ImageGenerationService(
          isPhaseValid: () async {
            generationCount++;
            return generationCount <= 1; // Invalid après le premier
          },
          onProgress: (current, total) {
            progressCalls.add(current);
          },
          imageGenerator: mockGenerator,
        );

        // Act
        final result = await service.generateImagesForChallenges(
          challenges: challenges,
          gameSessionId: 'game123',
        );

        // Assert
        expect(result.successCount, 1);
        expect(result.totalCount, 3);
        expect(result.phaseClosed, true);
        expect(result.isComplete, false);
        expect(result.hasPartialSuccess, true);
        expect(localGeneratedImages.length, 1); // Only one image was generated
      });

      test('should use custom prompt generator when provided', () async {
        // Arrange
        final challenges = [TestChallengeFactory.create(id: '1')];

        String? usedPrompt;
        String customPromptGenerator(Challenge c) {
          usedPrompt = 'Custom prompt for ${c.input1}';
          return usedPrompt!;
        }

        // Act
        final result = await service.generateImagesForChallenges(
          challenges: challenges,
          gameSessionId: 'game123',
          promptGenerator: customPromptGenerator,
        );

        // Assert
        expect(result.successCount, 1);
        expect(usedPrompt, 'Custom prompt for chat');
      });

      test('should handle empty challenge list', () async {
        // Act
        final result = await service.generateImagesForChallenges(
          challenges: [],
          gameSessionId: 'game123',
        );

        // Assert
        expect(result.successCount, 0);
        expect(result.totalCount, 0);
        expect(result.isComplete, true);
        expect(progressCalls, isEmpty);
      });

      test('should report progress correctly', () async {
        // Arrange
        final challenges = TestChallengeFactory.createList(5);

        // Act
        final result = await service.generateImagesForChallenges(
          challenges: challenges,
          gameSessionId: 'game123',
        );

        // Assert
        expect(result.successCount, 5);
        expect(progressCalls, [1, 2, 3, 4, 5]);
      });
    });

    group('generateImageForChallenge', () {
      test('should generate image for single challenge successfully', () async {
        // Arrange
        final challenge = TestChallengeFactory.create(id: '1');

        // Act
        final success = await service.generateImageForChallenge(
          challenge: challenge,
          gameSessionId: 'game123',
          prompt: 'A cat on a table',
        );

        // Assert
        expect(success, true);
      });

      test('should return false when phase is invalid', () async {
        // Arrange
        phaseValid = false;
        final challenge = TestChallengeFactory.create(id: '1');

        // Act
        final success = await service.generateImageForChallenge(
          challenge: challenge,
          gameSessionId: 'game123',
          prompt: 'A cat on a table',
        );

        // Assert
        expect(success, false);
      });
    });

    group('ImageGenerationResult', () {
      test('should correctly identify complete generation', () {
        final result = ImageGenerationResult(
          successCount: 3,
          totalCount: 3,
          phaseClosed: false,
        );

        expect(result.isComplete, true);
        expect(result.hasPartialSuccess, false);
        expect(result.hasErrors, false);
      });

      test('should correctly identify partial success', () {
        final result = ImageGenerationResult(
          successCount: 2,
          totalCount: 3,
          phaseClosed: true,
        );

        expect(result.isComplete, false);
        expect(result.hasPartialSuccess, true);
      });

      test('should correctly identify errors', () {
        final result = ImageGenerationResult(
          successCount: 1,
          totalCount: 3,
          phaseClosed: false,
          errorMessage: 'Test error',
        );

        expect(result.hasErrors, true);
      });
    });
  });
}
