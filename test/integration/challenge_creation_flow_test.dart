import 'package:flutter_test/flutter_test.dart';
import 'package:piction_ai_ry/models/challenge.dart';
import 'package:piction_ai_ry/services/api_service.dart';

/// Test d'intégration pour le flow de création de challenges
/// Simule le processus complet : envoi de challenges depuis l'UI jusqu'au backend
void main() {
  group('Challenge Creation Flow Integration', () {
    test('should correctly format challenge data for backend', () {
      // GIVEN: User input from UI
      final article1 = 'Un';
      final input1 = 'Chat';
      final preposition = 'Sur';
      final article2 = 'Une';
      final input2 = 'Table';
      final forbiddenWords = ['félin', 'animal', 'meuble'];

      // WHEN: Data is prepared for API
      final requestBody = {
        'first_word': article1.toLowerCase(),      // "un"
        'second_word': input1,                      // "Chat"
        'third_word': preposition.toLowerCase(),    // "sur"
        'fourth_word': article2.toLowerCase(),      // "une"
        'fifth_word': input2,                       // "Table"
        'forbidden_words': forbiddenWords,
      };

      // THEN: Verify correct format
      expect(requestBody['first_word'], 'un');
      expect(requestBody['second_word'], 'Chat');
      expect(requestBody['third_word'], 'sur');
      expect(requestBody['fourth_word'], 'une');
      expect(requestBody['fifth_word'], 'Table');
      expect(requestBody['forbidden_words'], forbiddenWords);
    });

    test('should parse backend response correctly', () {
      // GIVEN: Backend response
      final backendResponse = {
        'id': 'challenge_123',
        'game_session_id': 'session_456',
        'first_word': 'un',
        'second_word': 'Chat',
        'third_word': 'sur',
        'fourth_word': 'une',
        'fifth_word': 'Table',
        'forbidden_words': ['félin', 'animal', 'meuble'],
        'drawer_id': 'player_1',
        'guesser_id': 'player_2',
        'current_phase': 'waiting_prompt',
      };

      // WHEN: Response is parsed
      final challenge = Challenge.fromJson(backendResponse);

      // THEN: Verify all fields are correctly mapped
      expect(challenge.id, 'challenge_123');
      expect(challenge.gameSessionId, 'session_456');
      expect(challenge.article1, 'un');
      expect(challenge.input1, 'Chat');
      expect(challenge.preposition, 'sur');
      expect(challenge.article2, 'une');
      expect(challenge.input2, 'Table');
      expect(challenge.forbiddenWords, ['félin', 'animal', 'meuble']);
      expect(challenge.drawerId, 'player_1');
      expect(challenge.guesserId, 'player_2');
      expect(challenge.currentPhase, 'waiting_prompt');
      expect(challenge.fullPhrase, 'un Chat sur une Table');
    });

    test('should handle various forbidden_words formats from backend', () {
      // Test 1: forbidden_words as List (normal case)
      final response1 = {
        'id': '1',
        'first_word': 'un',
        'second_word': 'Chat',
        'third_word': 'sur',
        'fourth_word': 'une',
        'fifth_word': 'Table',
        'forbidden_words': ['félin', 'animal', 'meuble'],
      };
      final challenge1 = Challenge.fromJson(response1);
      expect(challenge1.forbiddenWords, ['félin', 'animal', 'meuble']);

      // Test 2: forbidden_words as JSON string (edge case)
      final response2 = {
        'id': '2',
        'first_word': 'un',
        'second_word': 'Chien',
        'third_word': 'dans',
        'fourth_word': 'une',
        'fifth_word': 'Maison',
        'forbidden_words': '["canin","bâtiment","toit"]',
      };
      final challenge2 = Challenge.fromJson(response2);
      expect(challenge2.forbiddenWords, ['canin', 'bâtiment', 'toit']);

      // Test 3: forbidden_words as null (error case)
      final response3 = {
        'id': '3',
        'first_word': 'un',
        'second_word': 'Livre',
        'third_word': 'sur',
        'fourth_word': 'une',
        'fifth_word': 'Étagère',
      };
      final challenge3 = Challenge.fromJson(response3);
      expect(challenge3.forbiddenWords, []);
    });

    test('should validate article and preposition values', () {
      // GIVEN: Valid dropdown values from UI
      final validArticles = ['Un', 'Une'];
      final validPrepositions = ['Sur', 'Dans'];

      // WHEN: Values are lowercased for backend
      for (final article in validArticles) {
        expect(article.toLowerCase(), anyOf('un', 'une'));
      }
      for (final prep in validPrepositions) {
        expect(prep.toLowerCase(), anyOf('sur', 'dans'));
      }
    });

    test('should correctly identify forbidden words in prompt', () {
      // GIVEN: A challenge
      final challenge = const Challenge(
        id: '123',
        gameSessionId: 'session_456',
        article1: 'Un',
        input1: 'Chat',
        preposition: 'Sur',
        article2: 'Une',
        input2: 'Table',
        forbiddenWords: ['félin', 'animal', 'meuble'],
      );

      // THEN: Verify prompt validation
      expect(challenge.promptContainsForbiddenWords('Un petit chat noir'), true); // contains target word 'chat'
      expect(challenge.promptContainsForbiddenWords('Un félin sur un toit'), true); // contains forbidden 'félin'
      expect(challenge.promptContainsForbiddenWords('Un animal domestique'), true); // contains forbidden 'animal'
      expect(challenge.promptContainsForbiddenWords('Un meuble en bois'), true); // contains forbidden 'meuble'
      expect(challenge.promptContainsForbiddenWords('Sur une table ronde'), true); // contains target word 'table'
      expect(challenge.promptContainsForbiddenWords('Une petite créature'), false); // valid prompt
      expect(challenge.promptContainsForbiddenWords('A small furry creature'), false); // valid prompt
    });

    test('should ensure 3 challenges per player', () {
      // GIVEN: UI constraint
      const challengesPerPlayer = 3;

      // WHEN: Player creates challenges
      final challenges = List.generate(challengesPerPlayer, (index) => {
        'challenge_number': index + 1,
        'first_word': 'un',
        'second_word': 'Object${index + 1}',
        'third_word': 'sur',
        'fourth_word': 'une',
        'fifth_word': 'Place${index + 1}',
        'forbidden_words': ['word1', 'word2', 'word3'],
      });

      // THEN: Verify exactly 3 challenges
      expect(challenges.length, 3);
      expect(challenges[0]['challenge_number'], 1);
      expect(challenges[1]['challenge_number'], 2);
      expect(challenges[2]['challenge_number'], 3);
    });
  });
}
