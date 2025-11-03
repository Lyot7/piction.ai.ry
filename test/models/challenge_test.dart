import 'package:flutter_test/flutter_test.dart';
import 'package:piction_ai_ry/models/challenge.dart';

void main() {
  group('Challenge.fromJson', () {
    test('should parse challenge with first_word format (backend response)', () {
      final json = {
        'id': '123',
        'game_session_id': 'session_456',
        'first_word': 'un',
        'second_word': 'Chat',
        'third_word': 'sur',
        'fourth_word': 'une',
        'fifth_word': 'Table',
        'forbidden_words': ['félin', 'animal', 'meuble'],
      };

      final challenge = Challenge.fromJson(json);

      expect(challenge.id, '123');
      expect(challenge.gameSessionId, 'session_456');
      expect(challenge.article1, 'un');
      expect(challenge.input1, 'Chat');
      expect(challenge.preposition, 'sur');
      expect(challenge.article2, 'une');
      expect(challenge.input2, 'Table');
      expect(challenge.forbiddenWords, ['félin', 'animal', 'meuble']);
    });

    test('should parse challenge with legacy article1/input1 format', () {
      final json = {
        'id': '123',
        'gameSessionId': 'session_456',
        'article1': 'Un',
        'input1': 'Chien',
        'preposition': 'Dans',
        'article2': 'Une',
        'input2': 'Maison',
        'forbidden_words': ['canin', 'bâtiment', 'toit'],
      };

      final challenge = Challenge.fromJson(json);

      expect(challenge.article1, 'Un');
      expect(challenge.input1, 'Chien');
      expect(challenge.preposition, 'Dans');
      expect(challenge.article2, 'Une');
      expect(challenge.input2, 'Maison');
      expect(challenge.forbiddenWords, ['canin', 'bâtiment', 'toit']);
    });

    test('should handle forbidden_words as JSON string', () {
      final json = {
        'id': '123',
        'first_word': 'un',
        'second_word': 'Chat',
        'third_word': 'sur',
        'fourth_word': 'une',
        'fifth_word': 'Table',
        'forbidden_words': '["félin","animal","meuble"]',
      };

      final challenge = Challenge.fromJson(json);

      expect(challenge.forbiddenWords, ['félin', 'animal', 'meuble']);
    });

    test('should handle forbidden_words as single string', () {
      final json = {
        'id': '123',
        'first_word': 'un',
        'second_word': 'Chat',
        'third_word': 'sur',
        'fourth_word': 'une',
        'fifth_word': 'Table',
        'forbidden_words': 'félin',
      };

      final challenge = Challenge.fromJson(json);

      expect(challenge.forbiddenWords, ['félin']);
    });

    test('should handle null forbidden_words', () {
      final json = {
        'id': '123',
        'first_word': 'un',
        'second_word': 'Chat',
        'third_word': 'sur',
        'fourth_word': 'une',
        'fifth_word': 'Table',
      };

      final challenge = Challenge.fromJson(json);

      expect(challenge.forbiddenWords, []);
    });

    test('should use default values for missing fields', () {
      final json = {
        'id': '123',
      };

      final challenge = Challenge.fromJson(json);

      expect(challenge.id, '123');
      expect(challenge.gameSessionId, '');
      expect(challenge.article1, 'Un');
      expect(challenge.input1, '');
      expect(challenge.preposition, 'Sur');
      expect(challenge.article2, 'Une');
      expect(challenge.input2, '');
      expect(challenge.forbiddenWords, []);
    });
  });

  group('Challenge methods', () {
    late Challenge challenge;

    setUp(() {
      challenge = const Challenge(
        id: '123',
        gameSessionId: 'session_456',
        article1: 'Un',
        input1: 'Chat',
        preposition: 'Sur',
        article2: 'Une',
        input2: 'Table',
        forbiddenWords: ['félin', 'animal', 'meuble'],
      );
    });

    test('fullPhrase should return complete challenge sentence', () {
      expect(challenge.fullPhrase, 'Un Chat Sur Une Table');
    });

    test('targetWords should return input1 and input2', () {
      expect(challenge.targetWords, ['Chat', 'Table']);
    });

    test('allForbiddenWords should return targets + forbidden', () {
      expect(
        challenge.allForbiddenWords,
        ['Chat', 'Table', 'félin', 'animal', 'meuble'],
      );
    });

    test('promptContainsForbiddenWords should detect forbidden words', () {
      expect(challenge.promptContainsForbiddenWords('Un félin assis'), true);
      expect(challenge.promptContainsForbiddenWords('Un chat noir'), true); // 'chat' is target word
      expect(challenge.promptContainsForbiddenWords('Une petite créature'), false);
      expect(challenge.promptContainsForbiddenWords('Animal domestique'), true);
    });

    test('promptContainsForbiddenWords should be case insensitive', () {
      expect(challenge.promptContainsForbiddenWords('Un FÉLIN assis'), true);
      expect(challenge.promptContainsForbiddenWords('un CHAT noir'), true);
    });
  });

  group('Challenge.toJson', () {
    test('should convert challenge to JSON', () {
      final challenge = const Challenge(
        id: '123',
        gameSessionId: 'session_456',
        article1: 'Un',
        input1: 'Chat',
        preposition: 'Sur',
        article2: 'Une',
        input2: 'Table',
        forbiddenWords: ['félin', 'animal', 'meuble'],
        prompt: 'A small creature',
        isResolved: true,
      );

      final json = challenge.toJson();

      expect(json['id'], '123');
      expect(json['gameSessionId'], 'session_456');
      expect(json['article1'], 'Un');
      expect(json['input1'], 'Chat');
      expect(json['preposition'], 'Sur');
      expect(json['article2'], 'Une');
      expect(json['input2'], 'Table');
      expect(json['forbidden_words'], ['félin', 'animal', 'meuble']);
      expect(json['prompt'], 'A small creature');
      expect(json['is_resolved'], true);
    });
  });
}
