import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piction_ai_ry/services/score_manager.dart';

/// Tests d'intégration pour le système de score du jeu
///
/// Vérifie que le scoring correspond aux règles documentées:
/// - Score initial: 100 points par équipe
/// - +25 points par mot trouvé
/// - -1 point par mauvaise réponse
/// - -10 points par régénération d'image
void main() {
  group('Game Scoring Flow Integration Tests', () {
    late ScoreManager scoreManager;

    setUp(() {
      scoreManager = ScoreManager();
    });

    test('SCENARIO: Complete game with correct scoring rules', () {
      debugPrint('\n=== TEST: Scénario de jeu complet ===');

      // Vérifier score initial
      expect(scoreManager.redScore, 100, reason: 'Red team should start at 100');
      expect(scoreManager.blueScore, 100, reason: 'Blue team should start at 100');
      debugPrint('Initial scores: Red=100, Blue=100');

      // Red team trouve un mot (+25)
      scoreManager.wordFound(Team.red, 'chat');
      expect(scoreManager.redScore, 125);
      debugPrint('Red finds "chat": 100 + 25 = 125');

      // Red team fait une mauvaise réponse (-1)
      scoreManager.wrongGuess(Team.red);
      expect(scoreManager.redScore, 124);
      debugPrint('Red wrong guess: 125 - 1 = 124');

      // Red team régénère une image (-10)
      scoreManager.imageRegenerated(Team.red);
      expect(scoreManager.redScore, 114);
      debugPrint('Red regenerates: 124 - 10 = 114');

      // Blue team trouve deux mots (+50)
      scoreManager.wordFound(Team.blue, 'chien');
      scoreManager.wordFound(Team.blue, 'table');
      expect(scoreManager.blueScore, 150);
      debugPrint('Blue finds 2 words: 100 + 50 = 150');

      // Vérifier le gagnant
      expect(scoreManager.getWinner(), Team.blue);
      debugPrint('Winner: Blue (150 > 114)');

      debugPrint('=== TEST PASSED ===\n');
    });

    test('SCENARIO: Score cannot go below zero', () {
      debugPrint('\n=== TEST: Score ne peut pas être négatif ===');

      // Retirer plus de points que disponible
      for (int i = 0; i < 150; i++) {
        scoreManager.wrongGuess(Team.red);
      }

      expect(scoreManager.redScore, 0, reason: 'Score should clamp at 0');
      expect(scoreManager.hasNegativeScore(), false); // Score clamped at 0, not negative
      debugPrint('After 150 wrong guesses: Red score = 0 (clamped)');

      debugPrint('=== TEST PASSED ===\n');
    });

    test('SCENARIO: Real game simulation - Drawing phase', () {
      debugPrint('\n=== TEST: Simulation phase de dessin ===');

      // Équipe Rouge - Drawer dessine 3 challenges
      debugPrint('Red Drawer generating images:');

      // Challenge 1: généré du premier coup
      debugPrint('  Challenge 1: OK (no regen)');

      // Challenge 2: régénéré 1 fois
      scoreManager.imageRegenerated(Team.red);
      expect(scoreManager.redScore, 90);
      debugPrint('  Challenge 2: 1 regen (-10) → Score: 90');

      // Challenge 3: régénéré 2 fois (max)
      scoreManager.imageRegenerated(Team.red);
      scoreManager.imageRegenerated(Team.red);
      expect(scoreManager.redScore, 70);
      debugPrint('  Challenge 3: 2 regens (-20) → Score: 70');

      // Équipe Bleue - pas de régénération
      debugPrint('Blue Drawer generating images: No regenerations');
      expect(scoreManager.blueScore, 100);

      debugPrint('After drawing phase: Red=70, Blue=100');
      debugPrint('=== TEST PASSED ===\n');
    });

    test('SCENARIO: Real game simulation - Guessing phase', () {
      debugPrint('\n=== TEST: Simulation phase de devinette ===');

      // Reset scores pour ce test
      scoreManager.reset();

      // Red team guesses:
      // Challenge 1: trouve au 3ème essai
      scoreManager.wrongGuess(Team.red);
      scoreManager.wrongGuess(Team.red);
      scoreManager.wordFound(Team.red, 'chat');
      scoreManager.wordFound(Team.red, 'table');
      expect(scoreManager.redScore, 148); // 100 - 2 + 50
      debugPrint('Red: 2 wrong (-2), 2 words (+50) → Score: 148');

      // Challenge 2: trouve au 1er essai
      scoreManager.wordFound(Team.red, 'chien');
      scoreManager.wordFound(Team.red, 'arbre');
      expect(scoreManager.redScore, 198);
      debugPrint('Red: 2 more words (+50) → Score: 198');

      // Blue team guesses:
      // Struggles with first challenge
      for (int i = 0; i < 5; i++) {
        scoreManager.wrongGuess(Team.blue);
      }
      scoreManager.wordFound(Team.blue, 'maison');
      scoreManager.wordFound(Team.blue, 'voiture');
      expect(scoreManager.blueScore, 145); // 100 - 5 + 50
      debugPrint('Blue: 5 wrong (-5), 2 words (+50) → Score: 145');

      // Vérifier le gagnant final
      expect(scoreManager.getWinner(), Team.red);
      debugPrint('Final: Red=198 wins vs Blue=145');

      debugPrint('=== TEST PASSED ===\n');
    });

    test('SCENARIO: Score history tracking', () {
      debugPrint('\n=== TEST: Historique des scores ===');

      scoreManager.wordFound(Team.red, 'test1');
      scoreManager.wrongGuess(Team.blue);
      scoreManager.imageRegenerated(Team.red);

      final history = scoreManager.history;
      expect(history.length, 3);

      // Vérifier l'ordre chronologique
      expect(history[0].team, Team.red);
      expect(history[0].delta, 25);
      expect(history[1].team, Team.blue);
      expect(history[1].delta, -1);
      expect(history[2].team, Team.red);
      expect(history[2].delta, -10);

      debugPrint('History tracked: 3 events in correct order');
      debugPrint('=== TEST PASSED ===\n');
    });

    test('SCENARIO: Tie game detection', () {
      debugPrint('\n=== TEST: Égalité de score ===');

      // Les deux équipes font les mêmes actions
      scoreManager.wordFound(Team.red, 'mot1');
      scoreManager.wordFound(Team.blue, 'mot2');

      expect(scoreManager.redScore, 125);
      expect(scoreManager.blueScore, 125);
      expect(scoreManager.getWinner(), isNull, reason: 'Should be null on tie');

      debugPrint('Tie game: Red=125, Blue=125, Winner=null');
      debugPrint('=== TEST PASSED ===\n');
    });

    test('SCENARIO: API sync simulation', () {
      debugPrint('\n=== TEST: Synchronisation API ===');

      // Simuler des scores locaux
      scoreManager.wordFound(Team.red, 'local');
      expect(scoreManager.redScore, 125);

      // Simuler une sync depuis le backend avec des scores différents
      scoreManager.syncFromApi({'red': 150, 'blue': 80});

      expect(scoreManager.redScore, 150);
      expect(scoreManager.blueScore, 80);

      debugPrint('After API sync: Red=150, Blue=80');
      debugPrint('=== TEST PASSED ===\n');
    });

    test('VERIFICATION: Scoring values match documented rules', () {
      debugPrint('\n=== VERIFICATION: Valeurs de scoring ===');

      final initialRed = scoreManager.redScore;

      // +25 for correct word
      scoreManager.wordFound(Team.red, 'test');
      expect(scoreManager.redScore - initialRed, 25, reason: '+25 for word found');
      debugPrint('Word found: +25 points');

      final afterWord = scoreManager.redScore;

      // -1 for wrong guess
      scoreManager.wrongGuess(Team.red);
      expect(afterWord - scoreManager.redScore, 1, reason: '-1 for wrong guess');
      debugPrint('Wrong guess: -1 point');

      final afterWrong = scoreManager.redScore;

      // -10 for regeneration
      scoreManager.imageRegenerated(Team.red);
      expect(afterWrong - scoreManager.redScore, 10, reason: '-10 for regen');
      debugPrint('Image regen: -10 points');

      debugPrint('=== ALL VALUES VERIFIED ===\n');
    });
  });
}
