import 'package:flutter_test/flutter_test.dart';
import 'package:piction_ai_ry/services/challenge_state_preserver.dart';
import 'package:piction_ai_ry/models/challenge.dart';
import '../../helpers/test_challenge_factory.dart';

/// Tests TDD pour ChallengeStatePreserver
///
/// Objectif: Garantir que les prompts locaux ne sont JAMAIS écrasés
/// par les données backend lors du refresh
void main() {
  group('ChallengeStatePreserver', () {
    late ChallengeStatePreserver preserver;

    setUp(() {
      preserver = ChallengeStatePreserver();
    });

    group('Preserve Local Prompts', () {
      test('should preserve local prompts when merging with backend data', () {
        // Arrange: Challenges locaux avec prompts de l'utilisateur
        final localChallenges = [
          TestChallengeFactory.create(
            id: '1',
            input1: 'chat',
            input2: 'table',
            prompt: 'Mon prompt local A',
            imageUrl: null,
          ),
          TestChallengeFactory.create(
            id: '2',
            input1: 'chien',
            input2: 'jardin',
            prompt: 'Mon prompt local B',
            imageUrl: null,
          ),
        ];

        // Backend retourne challenges avec prompts des coéquipiers + imageUrls
        final backendChallenges = [
          TestChallengeFactory.create(
            id: '1',
            input1: 'chat',
            input2: 'table',
            prompt: 'Prompt du coéquipier X',  // ❌ À NE PAS garder
            imageUrl: 'https://example.com/image1.png',  // ✅ À garder
          ),
          TestChallengeFactory.create(
            id: '2',
            input1: 'chien',
            input2: 'jardin',
            prompt: 'Prompt du coéquipier Y',  // ❌ À NE PAS garder
            imageUrl: 'https://example.com/image2.png',  // ✅ À garder
          ),
        ];

        // Act: Merge sélectif
        final result = preserver.mergeWithBackend(
          localChallenges: localChallenges,
          backendChallenges: backendChallenges,
        );

        // Assert: Prompts locaux préservés, imageUrls mises à jour
        expect(result.length, 2);
        expect(result[0].prompt, 'Mon prompt local A'); // ✅ Préservé
        expect(result[0].imageUrl, 'https://example.com/image1.png'); // ✅ Mis à jour
        expect(result[1].prompt, 'Mon prompt local B'); // ✅ Préservé
        expect(result[1].imageUrl, 'https://example.com/image2.png'); // ✅ Mis à jour
      });

      test('should handle missing prompts gracefully', () {
        // Arrange: Challenges locaux sans prompts (auto-génération)
        final localChallenges = [
          TestChallengeFactory.create(
            id: '1',
            input1: 'chat',
            input2: 'table',
            prompt: null,
          ),
        ];

        final backendChallenges = [
          TestChallengeFactory.create(
            id: '1',
            input1: 'chat',
            input2: 'table',
            prompt: 'Prompt backend',
            imageUrl: 'https://example.com/image1.png',
          ),
        ];

        // Act
        final result = preserver.mergeWithBackend(
          localChallenges: localChallenges,
          backendChallenges: backendChallenges,
        );

        // Assert: Utilise prompt backend si local est null
        expect(result[0].prompt, 'Prompt backend');
        expect(result[0].imageUrl, 'https://example.com/image1.png');
      });

      test('should preserve all local fields except imageUrl', () {
        // Arrange
        final localChallenges = [
          TestChallengeFactory.create(
            id: '1',
            input1: 'chat',
            input2: 'table',
            prompt: 'Mon prompt',
            imageUrl: null,
          ),
        ];

        final backendChallenges = [
          TestChallengeFactory.create(
            id: '1',
            input1: 'chat',
            input2: 'table',
            prompt: 'Autre prompt',
            imageUrl: 'https://example.com/image.png',
          ),
        ];

        // Act
        final result = preserver.mergeWithBackend(
          localChallenges: localChallenges,
          backendChallenges: backendChallenges,
        );

        // Assert: Tous les champs locaux préservés sauf imageUrl
        expect(result[0].id, '1');
        expect(result[0].input1, 'chat');
        expect(result[0].input2, 'table');
        expect(result[0].prompt, 'Mon prompt'); // ✅ Local préservé
        expect(result[0].imageUrl, 'https://example.com/image.png'); // ✅ Backend appliqué
      });
    });

    group('Handle Mismatched Data', () {
      test('should handle new challenges from backend', () {
        // Arrange: Backend a plus de challenges que local
        final localChallenges = [
          TestChallengeFactory.create(id: '1', input1: 'chat', input2: 'table'),
        ];

        final backendChallenges = [
          TestChallengeFactory.create(id: '1', input1: 'chat', input2: 'table', imageUrl: 'img1.png'),
          TestChallengeFactory.create(id: '2', input1: 'chien', input2: 'jardin', imageUrl: 'img2.png'),
        ];

        // Act
        final result = preserver.mergeWithBackend(
          localChallenges: localChallenges,
          backendChallenges: backendChallenges,
        );

        // Assert: Retourne les challenges du local qui existent, ignore les nouveaux du backend
        expect(result.length, 1);
        expect(result[0].id, '1');
      });

      test('should handle missing backend challenges', () {
        // Arrange: Local a plus de challenges que backend
        final localChallenges = [
          TestChallengeFactory.create(id: '1', input1: 'chat', input2: 'table'),
          TestChallengeFactory.create(id: '2', input1: 'chien', input2: 'jardin'),
        ];

        final backendChallenges = [
          TestChallengeFactory.create(id: '1', input1: 'chat', input2: 'table', imageUrl: 'img1.png'),
        ];

        // Act
        final result = preserver.mergeWithBackend(
          localChallenges: localChallenges,
          backendChallenges: backendChallenges,
        );

        // Assert: Challenge 1 merged, Challenge 2 garde état local
        expect(result.length, 2);
        expect(result[0].imageUrl, 'img1.png'); // Merged
        expect(result[1].imageUrl, null); // Reste local
      });

      test('should handle empty backend response', () {
        // Arrange
        final localChallenges = [
          TestChallengeFactory.create(id: '1', input1: 'chat', input2: 'table'),
        ];
        final backendChallenges = <Challenge>[];

        // Act
        final result = preserver.mergeWithBackend(
          localChallenges: localChallenges,
          backendChallenges: backendChallenges,
        );

        // Assert: Retourne challenges locaux inchangés
        expect(result.length, 1);
        expect(result, localChallenges);
      });

      test('should handle empty local state', () {
        // Arrange
        final localChallenges = <Challenge>[];
        final backendChallenges = [
          TestChallengeFactory.create(id: '1', input1: 'chat', input2: 'table'),
        ];

        // Act
        final result = preserver.mergeWithBackend(
          localChallenges: localChallenges,
          backendChallenges: backendChallenges,
        );

        // Assert: Retourne vide (pas de local à préserver)
        expect(result, isEmpty);
      });
    });

    group('Performance', () {
      test('should merge efficiently with many challenges', () {
        // Arrange: 12 challenges (4 joueurs × 3 challenges)
        final localChallenges = List.generate(
          12,
          (i) => TestChallengeFactory.create(
            id: '$i',
            input1: 'word$i',
            input2: 'word${i + 1}',
            prompt: 'Local prompt $i',
          ),
        );

        final backendChallenges = List.generate(
          12,
          (i) => TestChallengeFactory.create(
            id: '$i',
            input1: 'word$i',
            input2: 'word${i + 1}',
            prompt: 'Backend prompt $i',
            imageUrl: 'https://example.com/img$i.png',
          ),
        );

        // Act: Mesurer performance
        final stopwatch = Stopwatch()..start();
        final result = preserver.mergeWithBackend(
          localChallenges: localChallenges,
          backendChallenges: backendChallenges,
        );
        stopwatch.stop();

        // Assert: Doit être rapide (< 10ms pour 12 challenges)
        expect(stopwatch.elapsedMilliseconds, lessThan(10));
        expect(result.length, 12);

        // Vérifier que tous les prompts locaux sont préservés
        for (var i = 0; i < result.length; i++) {
          expect(result[i].prompt, 'Local prompt $i');
          expect(result[i].imageUrl, 'https://example.com/img$i.png');
        }
      });
    });

    group('State Snapshot', () {
      test('should create deep copy of challenges', () {
        // Arrange
        final original = [
          TestChallengeFactory.create(
            id: '1',
            input1: 'chat',
            input2: 'table',
            prompt: 'Original prompt',
          ),
        ];

        // Act: Create snapshot
        final snapshot = preserver.createSnapshot(original);

        // Assert: Snapshot is a deep copy, not reference
        expect(snapshot.length, original.length);
        expect(snapshot[0].prompt, original[0].prompt);
        expect(identical(snapshot, original), false); // Different objects
      });

      test('should restore from snapshot', () {
        // Arrange
        final original = [
          TestChallengeFactory.create(id: '1', input1: 'chat', input2: 'table', prompt: 'Prompt A'),
        ];
        final snapshot = preserver.createSnapshot(original);

        // Modifier l'original
        original[0] = TestChallengeFactory.create(id: '1', input1: 'chat', input2: 'table', prompt: 'Prompt B');

        // Act: Restore from snapshot
        final restored = preserver.restoreFromSnapshot(snapshot);

        // Assert: Restored equals original before modification
        expect(restored[0].prompt, 'Prompt A');
        expect(original[0].prompt, 'Prompt B');
      });
    });
  });
}
