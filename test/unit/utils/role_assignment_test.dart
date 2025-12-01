import 'package:flutter_test/flutter_test.dart';
import 'package:piction_ai_ry/utils/role_assignment.dart';
import 'package:piction_ai_ry/models/game_session.dart';
import 'package:piction_ai_ry/models/player.dart';

void main() {
  group('RoleAssignment', () {
    test('should assign drawer to first player and guesser to second player in each team', () {
      // Créer une session avec 4 joueurs sans rôles
      final session = GameSession(
        id: 'test-session',
        status: 'lobby',
        players: [
          const Player(id: 'red1', name: 'Red Player 1', color: 'red'),
          const Player(id: 'red2', name: 'Red Player 2', color: 'red'),
          const Player(id: 'blue1', name: 'Blue Player 1', color: 'blue'),
          const Player(id: 'blue2', name: 'Blue Player 2', color: 'blue'),
        ],
      );

      // Assigner les rôles
      final sessionWithRoles = RoleAssignment.assignInitialRoles(session);

      // Vérifier que les rôles sont assignés
      expect(sessionWithRoles.players.length, equals(4));

      // Équipe rouge
      final redPlayers = sessionWithRoles.players.where((p) => p.color == 'red').toList();
      expect(redPlayers[0].role, equals('drawer'));
      expect(redPlayers[1].role, equals('guesser'));

      // Équipe bleue
      final bluePlayers = sessionWithRoles.players.where((p) => p.color == 'blue').toList();
      expect(bluePlayers[0].role, equals('drawer'));
      expect(bluePlayers[1].role, equals('guesser'));
    });

    test('should detect when all players have roles', () {
      final sessionWithRoles = GameSession(
        id: 'test-session',
        status: 'lobby',
        players: [
          const Player(id: 'red1', name: 'Red Player 1', color: 'red', role: 'drawer'),
          const Player(id: 'red2', name: 'Red Player 2', color: 'red', role: 'guesser'),
          const Player(id: 'blue1', name: 'Blue Player 1', color: 'blue', role: 'drawer'),
          const Player(id: 'blue2', name: 'Blue Player 2', color: 'blue', role: 'guesser'),
        ],
      );

      final sessionWithoutRoles = GameSession(
        id: 'test-session',
        status: 'lobby',
        players: [
          const Player(id: 'red1', name: 'Red Player 1', color: 'red'),
          const Player(id: 'red2', name: 'Red Player 2', color: 'red'),
          const Player(id: 'blue1', name: 'Blue Player 1', color: 'blue'),
          const Player(id: 'blue2', name: 'Blue Player 2', color: 'blue'),
        ],
      );

      expect(RoleAssignment.allPlayersHaveRoles(sessionWithRoles), isTrue);
      expect(RoleAssignment.allPlayersHaveRoles(sessionWithoutRoles), isFalse);
    });

    test('should validate roles correctly', () {
      final validSession = GameSession(
        id: 'test-session',
        status: 'lobby',
        players: [
          const Player(id: 'red1', name: 'Red Player 1', color: 'red', role: 'drawer'),
          const Player(id: 'red2', name: 'Red Player 2', color: 'red', role: 'guesser'),
          const Player(id: 'blue1', name: 'Blue Player 1', color: 'blue', role: 'drawer'),
          const Player(id: 'blue2', name: 'Blue Player 2', color: 'blue', role: 'guesser'),
        ],
      );

      final invalidSession = GameSession(
        id: 'test-session',
        status: 'lobby',
        players: [
          const Player(id: 'red1', name: 'Red Player 1', color: 'red', role: 'drawer'),
          const Player(id: 'red2', name: 'Red Player 2', color: 'red', role: 'drawer'), // Deux drawers!
          const Player(id: 'blue1', name: 'Blue Player 1', color: 'blue', role: 'drawer'),
          const Player(id: 'blue2', name: 'Blue Player 2', color: 'blue', role: 'guesser'),
        ],
      );

      expect(RoleAssignment.areRolesValid(validSession), isTrue);
      expect(RoleAssignment.areRolesValid(invalidSession), isFalse);
    });

    // NOTE: Test 'should switch all roles correctly' supprimé
    // Le flow simplifié n'utilise plus l'inversion des rôles (switchAllRoles)

    test('should not assign roles to incomplete teams', () {
      final incompleteSession = GameSession(
        id: 'test-session',
        status: 'lobby',
        players: [
          const Player(id: 'red1', name: 'Red Player 1', color: 'red'),
          const Player(id: 'blue1', name: 'Blue Player 1', color: 'blue'),
        ],
      );

      final result = RoleAssignment.assignInitialRoles(incompleteSession);

      // Les rôles ne doivent pas être assignés
      expect(result.players.every((p) => p.role == null), isTrue);
    });

    test('should handle mixed scenarios with partial roles', () {
      final partialSession = GameSession(
        id: 'test-session',
        status: 'lobby',
        players: [
          const Player(id: 'red1', name: 'Red Player 1', color: 'red', role: 'drawer'),
          const Player(id: 'red2', name: 'Red Player 2', color: 'red'), // Pas de rôle
          const Player(id: 'blue1', name: 'Blue Player 1', color: 'blue'),
          const Player(id: 'blue2', name: 'Blue Player 2', color: 'blue'),
        ],
      );

      // Ne devrait pas être considéré comme ayant tous les rôles
      expect(RoleAssignment.allPlayersHaveRoles(partialSession), isFalse);

      // Ne devrait pas être considéré comme valide
      expect(RoleAssignment.areRolesValid(partialSession), isFalse);
    });
  });
}
