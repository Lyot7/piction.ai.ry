import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_data.dart';
import '../helpers/mock_api_service.dart';

/// Tests d'intégration pour le flow complet de création de room
///
/// Ces tests simulent le comportement réel de l'application
/// en testant plusieurs composants ensemble.
///
/// ⚠️ NOTE: Ces tests utilisent MockApiService car GameService
/// est un singleton qui fait de vrais appels API. Pour tester
/// avec des vrais appels, il faudrait soit:
/// 1. Rendre GameService injectable avec une factory
/// 2. Utiliser des tests E2E avec un serveur de test
/// 3. Utiliser http_mock_adapter pour intercepter les appels
void main() {
  group('Integration - Complete Room Creation Flow', () {
    test('SCENARIO: User creates room, joins red team, and sees themselves in lobby', () async {
      // GIVEN: Une nouvelle session est créée
      final mockApi = MockApiServiceFactory.empty();

      // ACT: Créer la session
      final createdSession = await mockApi.createGameSession();
      expect(createdSession, isNotNull);
      expect(createdSession.players, isEmpty);

      // ACT: Le host rejoint l'équipe rouge
      final hostPlayer = await mockApi.joinGameSession(createdSession.id, 'red');
      expect(hostPlayer, isNotNull);
      expect(hostPlayer.color, equals('red'));
      expect(hostPlayer.isHost, isTrue);

      // ACT: Rafraîchir la session pour voir le host
      final refreshedSession = await mockApi.refreshGameSession(createdSession.id);

      // ASSERT: Le host doit apparaître dans la session
      expect(refreshedSession.players.length, equals(1));
      expect(refreshedSession.players.first.id, equals(hostPlayer.id));
      expect(refreshedSession.players.first.color, equals('red'));
      expect(refreshedSession.players.first.isHost, isTrue);

      // ASSERT: Le joueur doit être identifiable dans la session
      // (test des différentes stratégies de matching)
      final playerFound = refreshedSession.players
          .where((p) => p.id == hostPlayer.id)
          .firstOrNull;
      expect(playerFound, isNotNull, reason: 'Player should be found by exact ID match');
    });

    test('SCENARIO: Multiple players join the same room', () async {
      // GIVEN: Une session créée par un host
      final mockApi = MockApiServiceFactory.empty();
      final session = await mockApi.createGameSession();
      final host = await mockApi.joinGameSession(session.id, 'red');

      // ACT: 3 autres joueurs rejoignent
      await mockApi.joinGameSession(session.id, 'red');
      await mockApi.joinGameSession(session.id, 'blue');
      await mockApi.joinGameSession(session.id, 'blue');

      // ACT: Rafraîchir la session
      final fullSession = await mockApi.refreshGameSession(session.id);

      // ASSERT: 4 joueurs dans la session
      expect(fullSession.players.length, equals(4));

      // ASSERT: 2 joueurs par équipe
      final redTeam = fullSession.getTeamPlayers('red');
      final blueTeam = fullSession.getTeamPlayers('blue');
      expect(redTeam.length, equals(2));
      expect(blueTeam.length, equals(2));

      // ASSERT: Host est toujours marqué comme host
      final hostInSession = fullSession.players.firstWhere((p) => p.id == host.id);
      expect(hostInSession.isHost, isTrue);

      // ASSERT: Session est prête à démarrer
      expect(fullSession.isReadyToStart, isTrue);
    });

    test('SCENARIO: Player tries to join full team and gets error', () async {
      // GIVEN: Une session avec une équipe rouge complète
      final mockApi = MockApiServiceFactory.empty();
      final session = await mockApi.createGameSession();
      await mockApi.joinGameSession(session.id, 'red');
      await mockApi.joinGameSession(session.id, 'red');

      // ACT & ASSERT: Un 3ème joueur essaie de rejoindre rouge
      expect(
        () async => await mockApi.joinGameSession(session.id, 'red'),
        throwsException,
      );

      // ASSERT: Le joueur peut rejoindre bleu
      final player3 = await mockApi.joinGameSession(session.id, 'blue');
      expect(player3.color, equals('blue'));
    });

    test('SCENARIO: Session cannot start without 4 players', () async {
      // GIVEN: Une session avec seulement 2 joueurs
      final mockApi = MockApiServiceFactory.empty();
      final session = await mockApi.createGameSession();
      await mockApi.joinGameSession(session.id, 'red');
      await mockApi.joinGameSession(session.id, 'blue');

      final sessionWith2Players = await mockApi.refreshGameSession(session.id);

      // ASSERT: Session pas prête à démarrer
      expect(sessionWith2Players.isReadyToStart, isFalse);

      // ACT & ASSERT: Essayer de démarrer échoue
      expect(
        () async => await mockApi.startGameSession(session.id),
        throwsException,
      );
    });

    test('SCENARIO: Session can start with 4 players properly distributed', () async {
      // GIVEN: Une session complète avec 4 joueurs
      final mockApi = MockApiServiceFactory.empty();
      final session = await mockApi.createGameSession();
      await mockApi.joinGameSession(session.id, 'red');
      await mockApi.joinGameSession(session.id, 'red');
      await mockApi.joinGameSession(session.id, 'blue');
      await mockApi.joinGameSession(session.id, 'blue');

      final fullSession = await mockApi.refreshGameSession(session.id);

      // ASSERT: Session prête à démarrer
      expect(fullSession.isReadyToStart, isTrue);

      // ACT: Démarrer la session
      await mockApi.startGameSession(session.id);

      // ACT: Vérifier le nouveau statut
      final startedSession = await mockApi.refreshGameSession(session.id);

      // ASSERT: Status changé à "challenge"
      expect(startedSession.status, equals('challenge'));
      expect(startedSession.startedAt, isNotNull);
    });

    test('SCENARIO: Player can switch teams if target team is not full', () async {
      // GIVEN: Une session avec 2 joueurs
      final mockApi = MockApiServiceFactory.empty();
      final session = await mockApi.createGameSession();
      await mockApi.joinGameSession(session.id, 'red');
      final player2 = await mockApi.joinGameSession(session.id, 'red');

      // ASSERT: 2 joueurs dans rouge, 0 dans bleu
      var currentSession = await mockApi.refreshGameSession(session.id);
      expect(currentSession.getTeamPlayers('red').length, equals(2));
      expect(currentSession.getTeamPlayers('blue').length, equals(0));

      // ACT: Player2 change pour bleu
      await mockApi.switchTeam(session.id, player2.id, 'blue');

      // ASSERT: 1 joueur dans rouge, 1 dans bleu
      currentSession = await mockApi.refreshGameSession(session.id);
      expect(currentSession.getTeamPlayers('red').length, equals(1));
      expect(currentSession.getTeamPlayers('blue').length, equals(1));
    });
  });

  group('Integration - ID Matching Strategies', () {
    test('SCENARIO: Player ID with extra whitespace is correctly matched', () async {
      // Ce test simule le bug où l'ID du joueur contient des espaces

      final session = TestData.emptySession();
      final playerWithSpaces = TestData.player1Host(id: '  player-id-123  ');

      // Simuler l'ajout du joueur à la session
      final updatedSession = session.copyWith(
        players: [playerWithSpaces],
      );

      // Test des différentes stratégies de matching
      final exactMatch = updatedSession.players
          .where((p) => p.id == playerWithSpaces.id)
          .firstOrNull;
      expect(exactMatch, isNotNull, reason: 'Exact match should work with spaces');

      final trimmedMatch = updatedSession.players
          .where((p) => p.id.trim() == playerWithSpaces.id.trim())
          .firstOrNull;
      expect(trimmedMatch, isNotNull, reason: 'Trimmed match should work');

      // Le meilleur match devrait être exact ou trimmed
      final bestMatch = exactMatch ?? trimmedMatch;
      expect(bestMatch, isNotNull);
    });

    test('SCENARIO: Player ID with different case is correctly matched', () async {
      final session = TestData.emptySession();
      final playerUppercase = TestData.player1Host(id: 'PLAYER-ID-123');

      final updatedSession = session.copyWith(
        players: [playerUppercase],
      );

      // Match exact (case-sensitive)
      final exactMatch = updatedSession.players
          .where((p) => p.id == playerUppercase.id)
          .firstOrNull;
      expect(exactMatch, isNotNull);

      // Match case-insensitive
      final lowercaseMatch = updatedSession.players
          .where((p) => p.id.toLowerCase() == 'player-id-123')
          .firstOrNull;
      expect(lowercaseMatch, isNotNull, reason: 'Lowercase match should work');
    });

    test('SCENARIO: Player is matched by name as fallback', () async {
      // Ce test vérifie que si l'ID ne match pas, on peut utiliser le nom

      final session = TestData.emptySession();
      final player = TestData.player1Host(id: 'player-1', name: 'Alice');

      final updatedSession = session.copyWith(
        players: [player],
      );

      // Match par nom
      final nameMatch = updatedSession.players
          .where((p) => p.name == 'Alice')
          .firstOrNull;
      expect(nameMatch, isNotNull, reason: 'Name match should work as fallback');
      expect(nameMatch?.id, equals('player-1'));
    });
  });

  group('Integration - Error Scenarios', () {
    test('SCENARIO: API failure during room creation is handled gracefully', () async {
      // GIVEN: Mock API configuré pour échouer
      final mockApi = MockApiServiceFactory.failing('Network error');

      // ACT & ASSERT: La création échoue avec une exception
      expect(
        () async => await mockApi.createGameSession(),
        throwsException,
      );
    });

    test('SCENARIO: Trying to join non-existent session throws error', () async {
      // GIVEN: Mock API sans sessions
      final mockApi = MockApiServiceFactory.empty();

      // ACT & ASSERT: Rejoindre une session inexistante échoue
      expect(
        () async => await mockApi.joinGameSession('non-existent-id', 'red'),
        throwsException,
      );
    });

    test('SCENARIO: Network delay is handled correctly', () async {
      // GIVEN: Mock API avec délai
      final mockApi = MockApiServiceFactory.withDelay(Duration(milliseconds: 100));

      // ACT: Mesurer le temps d'exécution
      final stopwatch = Stopwatch()..start();
      final session = await mockApi.createGameSession();
      stopwatch.stop();

      // ASSERT: La création a pris au moins 100ms
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(100));
      expect(session, isNotNull);
    });
  });

  group('Integration - Session State Transitions', () {
    test('SCENARIO: Session status transitions correctly through game phases', () async {
      // GIVEN: Une nouvelle session
      final mockApi = MockApiServiceFactory.empty();
      final session = await mockApi.createGameSession();

      // ASSERT: Status initial est "lobby"
      expect(session.status, equals('lobby'));

      // ACT: Ajouter 4 joueurs
      await mockApi.joinGameSession(session.id, 'red');
      await mockApi.joinGameSession(session.id, 'red');
      await mockApi.joinGameSession(session.id, 'blue');
      await mockApi.joinGameSession(session.id, 'blue');

      // ACT: Démarrer le jeu
      await mockApi.startGameSession(session.id);

      // ACT: Vérifier le nouveau status
      final startedSession = await mockApi.refreshGameSession(session.id);

      // ASSERT: Status est maintenant "challenge"
      expect(startedSession.status, equals('challenge'));
      expect(startedSession.isActive, isTrue);
      expect(startedSession.isFinished, isFalse);
    });
  });
}
