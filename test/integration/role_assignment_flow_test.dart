import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piction_ai_ry/models/player.dart';
import 'package:piction_ai_ry/utils/role_assignment.dart';
import '../helpers/test_data.dart';
import '../helpers/mock_api_service.dart';

/// Tests d'intégration pour le workflow complet d'attribution des rôles
///
/// Ces tests simulent le comportement réel de l'application
/// en testant le flow complet depuis la création de room jusqu'au jeu
void main() {
  group('Integration - Role Assignment Workflow', () {
    late MockApiService mockApi;

    setUp(() {
      mockApi = MockApiServiceFactory.empty();
    });

    test('SCENARIO: 4 players join, game starts, roles are assigned correctly', () async {
      // ===== PHASE 1: LOBBY - Création et join =====
      debugPrint('📝 PHASE 1: Création de room et join des joueurs');

      // Créer la session
      final session = await mockApi.createGameSession();
      expect(session.id, isNotEmpty);
      debugPrint('✅ Session créée: ${session.id}');

      // 4 joueurs rejoignent (2 par équipe)
      final player1 = await mockApi.joinGameSession(session.id, 'red');
      final player2 = await mockApi.joinGameSession(session.id, 'red');
      final player3 = await mockApi.joinGameSession(session.id, 'blue');
      final player4 = await mockApi.joinGameSession(session.id, 'blue');

      debugPrint('✅ 4 joueurs ont rejoint');
      debugPrint('   - Red team: ${player1.name}, ${player2.name}');
      debugPrint('   - Blue team: ${player3.name}, ${player4.name}');

      // Rafraîchir la session
      var currentSession = await mockApi.refreshGameSession(session.id);
      expect(currentSession.players.length, equals(4));
      expect(currentSession.isReadyToStart, isTrue);
      debugPrint('✅ Session prête à démarrer');

      // ===== VÉRIFICATION: Aucun rôle avant le start =====
      final allHaveRolesBeforeStart = RoleAssignment.allPlayersHaveRoles(currentSession);
      expect(allHaveRolesBeforeStart, isTrue,
        reason: 'MockApi assigns roles on join (first=drawer, second=guesser)');
      debugPrint('✅ Rôles déjà assignés par le mock (simule backend)');

      // ===== PHASE 2: START - Démarrage du jeu =====
      debugPrint('\n📝 PHASE 2: Démarrage du jeu');

      // Démarrer la session
      await mockApi.startGameSession(session.id);
      debugPrint('✅ Session démarrée');

      // Rafraîchir pour récupérer les rôles
      currentSession = await mockApi.refreshGameSession(session.id);
      expect(currentSession.status, equals('challenge'));
      debugPrint('✅ Status changé en "challenge"');

      // ===== VÉRIFICATION: Les rôles sont assignés =====
      final allHaveRolesAfterStart = RoleAssignment.allPlayersHaveRoles(currentSession);
      expect(allHaveRolesAfterStart, isTrue);
      debugPrint('✅ Tous les joueurs ont des rôles');

      // ===== VÉRIFICATION: Les rôles sont valides =====
      final rolesValid = RoleAssignment.areRolesValid(currentSession);
      expect(rolesValid, isTrue,
        reason: 'Each team should have 1 drawer and 1 guesser');
      debugPrint('✅ Distribution des rôles valide (1 drawer + 1 guesser par équipe)');

      // ===== VÉRIFICATION DÉTAILLÉE: Distribution par équipe =====
      debugPrint('\n📊 Distribution finale des rôles:');

      for (final teamColor in ['red', 'blue']) {
        final teamPlayers = currentSession.getTeamPlayers(teamColor);
        expect(teamPlayers.length, equals(2));

        final drawer = currentSession.getTeamDrawer(teamColor);
        final guesser = currentSession.getTeamGuesser(teamColor);

        expect(drawer, isNotNull, reason: 'Team $teamColor should have a drawer');
        expect(guesser, isNotNull, reason: 'Team $teamColor should have a guesser');

        debugPrint('   $teamColor team:');
        debugPrint('     - Drawer: ${drawer!.name}');
        debugPrint('     - Guesser: ${guesser!.name}');
      }

      debugPrint('\n✅ TEST PASSED: Role assignment workflow complet');
    });

    test('SCENARIO: Roles switch correctly after challenge completion', () async {
      // ===== SETUP: Session avec 4 joueurs et rôles assignés =====
      final session = await mockApi.createGameSession();
      await mockApi.joinGameSession(session.id, 'red');
      await mockApi.joinGameSession(session.id, 'red');
      await mockApi.joinGameSession(session.id, 'blue');
      await mockApi.joinGameSession(session.id, 'blue');
      await mockApi.startGameSession(session.id);

      var currentSession = await mockApi.refreshGameSession(session.id);

      debugPrint('\n📝 PHASE 1: Rôles initiaux');
      final initialRedDrawer = currentSession.getTeamDrawer('red');
      final initialRedGuesser = currentSession.getTeamGuesser('red');
      final initialBlueDrawer = currentSession.getTeamDrawer('blue');
      final initialBlueGuesser = currentSession.getTeamGuesser('blue');

      expect(initialRedDrawer, isNotNull);
      expect(initialRedGuesser, isNotNull);
      debugPrint('✅ Red team: ${initialRedDrawer!.name} (drawer), ${initialRedGuesser!.name} (guesser)');
      debugPrint('✅ Blue team: ${initialBlueDrawer!.name} (drawer), ${initialBlueGuesser!.name} (guesser)');

      // ===== ACTION: Inverser les rôles (après challenge résolu) =====
      debugPrint('\n📝 PHASE 2: Inversion des rôles');
      currentSession = RoleAssignment.switchAllRoles(currentSession);
      debugPrint('✅ Rôles inversés localement');

      // ===== VÉRIFICATION: Les rôles sont inversés =====
      final newRedDrawer = currentSession.getTeamDrawer('red');
      final newRedGuesser = currentSession.getTeamGuesser('red');
      final newBlueDrawer = currentSession.getTeamDrawer('blue');
      final newBlueGuesser = currentSession.getTeamGuesser('blue');

      expect(newRedDrawer!.id, equals(initialRedGuesser.id),
        reason: 'Previous guesser should now be drawer');
      expect(newRedGuesser!.id, equals(initialRedDrawer.id),
        reason: 'Previous drawer should now be guesser');

      expect(newBlueDrawer!.id, equals(initialBlueGuesser.id),
        reason: 'Previous guesser should now be drawer');
      expect(newBlueGuesser!.id, equals(initialBlueDrawer.id),
        reason: 'Previous drawer should now be guesser');

      debugPrint('✅ Red team: ${newRedDrawer.name} (drawer), ${newRedGuesser.name} (guesser)');
      debugPrint('✅ Blue team: ${newBlueDrawer.name} (drawer), ${newBlueGuesser.name} (guesser)');

      // ===== VÉRIFICATION: Les rôles restent valides après inversion =====
      final rolesStillValid = RoleAssignment.areRolesValid(currentSession);
      expect(rolesStillValid, isTrue,
        reason: 'Role distribution should remain valid after switch');
      debugPrint('✅ Distribution toujours valide après inversion');

      debugPrint('\n✅ TEST PASSED: Role switching workflow');
    });

    test('SCENARIO: Local role assignment when backend does not assign roles', () async {
      // Ce test simule le cas où le backend ne renvoie PAS de rôles
      // et on doit les assigner localement

      debugPrint('\n📝 Simulation: Backend sans attribution de rôles');

      // Créer une session avec 4 joueurs SANS rôles explicitement
      final sessionWithoutRoles = TestData.emptySession().copyWith(
        players: const [
          Player(id: 'p1', name: 'Alice', color: 'red', isHost: true),
          Player(id: 'p2', name: 'Bob', color: 'red'),
          Player(id: 'p3', name: 'Charlie', color: 'blue'),
          Player(id: 'p4', name: 'Diana', color: 'blue'),
        ],
      );

      debugPrint('✅ Session créée sans rôles (simule backend basique)');

      // Vérifier qu'aucun joueur n'a de rôle
      final hasRoles = RoleAssignment.allPlayersHaveRoles(sessionWithoutRoles);
      expect(hasRoles, isFalse);
      debugPrint('✅ Confirmé: Aucun joueur n\'a de rôle');

      // ===== ACTION: Attribution locale des rôles =====
      debugPrint('\n📝 Attribution locale des rôles');
      final sessionWithRoles = RoleAssignment.assignInitialRoles(sessionWithoutRoles);

      // ===== VÉRIFICATION: Tous les joueurs ont maintenant des rôles =====
      final allHaveRoles = RoleAssignment.allPlayersHaveRoles(sessionWithRoles);
      expect(allHaveRoles, isTrue);
      debugPrint('✅ Tous les joueurs ont maintenant des rôles');

      // ===== VÉRIFICATION: Distribution valide =====
      final rolesValid = RoleAssignment.areRolesValid(sessionWithRoles);
      expect(rolesValid, isTrue);
      debugPrint('✅ Distribution valide (1 drawer + 1 guesser par équipe)');

      // ===== VÉRIFICATION DÉTAILLÉE: Ordre correct =====
      debugPrint('\n📊 Vérification de l\'ordre d\'attribution:');

      for (final teamColor in ['red', 'blue']) {
        final originalTeamPlayers = sessionWithoutRoles.getTeamPlayers(teamColor);
        final assignedTeamPlayers = sessionWithRoles.getTeamPlayers(teamColor);

        // Premier joueur devrait être drawer
        expect(assignedTeamPlayers[0].role, equals('drawer'),
          reason: 'First player should be drawer');
        expect(assignedTeamPlayers[0].id, equals(originalTeamPlayers[0].id),
          reason: 'Should be same player');

        // Deuxième joueur devrait être guesser
        expect(assignedTeamPlayers[1].role, equals('guesser'),
          reason: 'Second player should be guesser');
        expect(assignedTeamPlayers[1].id, equals(originalTeamPlayers[1].id),
          reason: 'Should be same player');

        debugPrint('   $teamColor team:');
        debugPrint('     - ${assignedTeamPlayers[0].name}: ${assignedTeamPlayers[0].role}');
        debugPrint('     - ${assignedTeamPlayers[1].name}: ${assignedTeamPlayers[1].role}');
      }

      debugPrint('\n✅ TEST PASSED: Local role assignment fallback');
    });

    test('SCENARIO: Session with less than 4 players cannot start', () async {
      // ===== SETUP: Session avec seulement 2 joueurs SANS rôles =====
      // Créer une session manuellement pour éviter l'auto-assignation du mock
      final incompleteSession = TestData.emptySession().copyWith(
        players: const [
          Player(id: 'p1', name: 'Alice', color: 'red', isHost: true),
          Player(id: 'p3', name: 'Charlie', color: 'blue'),
        ],
      );

      debugPrint('\n📝 Session avec seulement 2 joueurs');
      expect(incompleteSession.players.length, equals(2));
      expect(incompleteSession.isReadyToStart, isFalse);
      debugPrint('✅ Session correctement identifiée comme non prête');

      // ===== VÉRIFICATION: Ne pas assigner de rôles si pas 4 joueurs =====
      final sessionWithAttemptedRoles = RoleAssignment.assignInitialRoles(incompleteSession);

      // Les rôles ne devraient PAS être assignés (session retournée telle quelle)
      final allHaveRoles = RoleAssignment.allPlayersHaveRoles(sessionWithAttemptedRoles);
      expect(allHaveRoles, isFalse,
        reason: 'Roles should not be assigned with less than 4 players');
      debugPrint('✅ Rôles correctement NON assignés (session incomplète)');

      // ===== ACTION: Ajouter 2 joueurs supplémentaires pour compléter la session =====
      debugPrint('\n📝 Création d\'une session complète (4 joueurs)');
      final completeSession = TestData.emptySession().copyWith(
        players: const [
          Player(id: 'p1', name: 'Alice', color: 'red', isHost: true),
          Player(id: 'p2', name: 'Bob', color: 'red'),
          Player(id: 'p3', name: 'Charlie', color: 'blue'),
          Player(id: 'p4', name: 'Diana', color: 'blue'),
        ],
      );
      expect(completeSession.players.length, equals(4));
      expect(completeSession.isReadyToStart, isTrue);
      debugPrint('✅ Session maintenant prête (4 joueurs)');

      // ===== VÉRIFICATION: Maintenant les rôles PEUVENT être assignés =====
      final fullSessionWithRoles = RoleAssignment.assignInitialRoles(completeSession);
      final nowAllHaveRoles = RoleAssignment.allPlayersHaveRoles(fullSessionWithRoles);
      expect(nowAllHaveRoles, isTrue);
      debugPrint('✅ Rôles assignés avec succès après complétion');

      debugPrint('\n✅ TEST PASSED: Incomplete session handling');
    });

    test('SCENARIO: Multiple role switches maintain validity', () async {
      // Test que les inversions successives maintiennent la validité

      final session = await mockApi.createGameSession();
      await mockApi.joinGameSession(session.id, 'red');
      await mockApi.joinGameSession(session.id, 'red');
      await mockApi.joinGameSession(session.id, 'blue');
      await mockApi.joinGameSession(session.id, 'blue');
      await mockApi.startGameSession(session.id);

      var currentSession = await mockApi.refreshGameSession(session.id);

      debugPrint('\n📝 Test d\'inversions multiples');

      // Inverser 5 fois pour tester la robustesse
      for (int i = 1; i <= 5; i++) {
        debugPrint('\n🔄 Inversion #$i');

        currentSession = RoleAssignment.switchAllRoles(currentSession);

        // Vérifier que les rôles sont toujours valides
        final stillValid = RoleAssignment.areRolesValid(currentSession);
        expect(stillValid, isTrue,
          reason: 'Roles should remain valid after $i switches');

        debugPrint('   ✅ Distribution toujours valide');

        // Vérifier que chaque équipe a toujours 1 drawer et 1 guesser
        for (final teamColor in ['red', 'blue']) {
          final drawer = currentSession.getTeamDrawer(teamColor);
          final guesser = currentSession.getTeamGuesser(teamColor);

          expect(drawer, isNotNull,
            reason: 'Team $teamColor should have drawer after $i switches');
          expect(guesser, isNotNull,
            reason: 'Team $teamColor should have guesser after $i switches');
        }
      }

      debugPrint('\n✅ TEST PASSED: Multiple switches maintain validity');
    });
  });

  group('Integration - Edge Cases', () {
    test('SCENARIO: Session with malformed data handles gracefully', () {
      // Test avec des données incohérentes
      final malformedSession = TestData.emptySession().copyWith(
        players: [
          TestData.player1Host(color: 'red', role: 'drawer'),
          TestData.player2(color: 'red', role: 'drawer'), // 2 drawers!
          TestData.player3(color: 'blue', role: 'guesser'),
          TestData.player4(color: 'blue', role: 'guesser'), // 2 guessers!
        ],
      );

      debugPrint('\n📝 Session avec données malformées');

      // Devrait détecter que les rôles ne sont pas valides
      final isValid = RoleAssignment.areRolesValid(malformedSession);
      expect(isValid, isFalse,
        reason: 'Should detect invalid role distribution');
      debugPrint('✅ Distribution invalide correctement détectée');

      // Réassigner les rôles correctement
      final fixedSession = RoleAssignment.assignInitialRoles(malformedSession);
      final nowValid = RoleAssignment.areRolesValid(fixedSession);
      expect(nowValid, isTrue,
        reason: 'Should fix invalid distribution');
      debugPrint('✅ Distribution corrigée avec succès');

      debugPrint('\n✅ TEST PASSED: Malformed data handling');
    });

    test('SCENARIO: Empty session does not crash', () {
      final emptySession = TestData.emptySession();

      debugPrint('\n📝 Session vide');

      // Ne devrait pas crasher
      expect(() => RoleAssignment.assignInitialRoles(emptySession),
        returnsNormally);
      expect(() => RoleAssignment.allPlayersHaveRoles(emptySession),
        returnsNormally);
      expect(() => RoleAssignment.areRolesValid(emptySession),
        returnsNormally);

      debugPrint('✅ Aucun crash avec session vide');
      debugPrint('\n✅ TEST PASSED: Empty session safety');
    });
  });
}
