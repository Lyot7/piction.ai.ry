import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piction_ai_ry/models/game_session.dart';
import 'package:piction_ai_ry/models/player.dart';

void main() {
  group('GameSession JSON Parsing Tests', () {
    test('Parse backend format with red_team/blue_team as objects (snake_case)', () {
      final jsonString = '''
      {
        "id": "session123",
        "status": "challenge",
        "red_team": [
          {
            "player_id": "p1",
            "name": "Alice",
            "challenges_sent": 3,
            "role": "drawer"
          },
          {
            "player_id": "p2",
            "name": "Bob",
            "challenges_sent": 0,
            "role": "guesser"
          }
        ],
        "blue_team": [
          {
            "player_id": "p3",
            "name": "Charlie",
            "challenges_sent": 3,
            "role": "drawer"
          },
          {
            "player_id": "p4",
            "name": "Diana",
            "challenges_sent": 2,
            "role": "guesser"
          }
        ]
      }
      ''';

      final json = jsonDecode(jsonString);
      final session = GameSession.fromJson(json);

      debugPrint('📊 Test 1 - Session ID: ${session.id}');
      debugPrint('📊 Test 1 - Status: ${session.status}');
      debugPrint('📊 Test 1 - Players count: ${session.players.length}');

      expect(session.id, 'session123');
      expect(session.status, 'challenge');
      expect(session.players.length, 4);

      // Vérifier les joueurs rouges
      final redPlayers = session.players.where((p) => p.color == 'red').toList();
      expect(redPlayers.length, 2);

      final alice = redPlayers.firstWhere((p) => p.name == 'Alice');
      debugPrint('📊 Test 1 - Alice challengesSent: ${alice.challengesSent}');
      expect(alice.challengesSent, 3);
      expect(alice.role, 'drawer');

      final bob = redPlayers.firstWhere((p) => p.name == 'Bob');
      debugPrint('📊 Test 1 - Bob challengesSent: ${bob.challengesSent}');
      expect(bob.challengesSent, 0);
      expect(bob.role, 'guesser');

      // Vérifier les joueurs bleus
      final bluePlayers = session.players.where((p) => p.color == 'blue').toList();
      expect(bluePlayers.length, 2);

      final charlie = bluePlayers.firstWhere((p) => p.name == 'Charlie');
      debugPrint('📊 Test 1 - Charlie challengesSent: ${charlie.challengesSent}');
      expect(charlie.challengesSent, 3);

      final diana = bluePlayers.firstWhere((p) => p.name == 'Diana');
      debugPrint('📊 Test 1 - Diana challengesSent: ${diana.challengesSent}');
      expect(diana.challengesSent, 2);

      // Compter combien ont envoyé 3 challenges
      final playersReady = session.players.where((p) => p.challengesSent >= 3).length;
      debugPrint('📊 Test 1 - Players with 3+ challenges: $playersReady/4');
      expect(playersReady, 2); // Alice et Charlie
    });

    test('Parse backend format with red_team/blue_team as simple IDs', () {
      final jsonString = '''
      {
        "id": "session456",
        "status": "lobby",
        "red_team": ["p1", "p2"],
        "blue_team": ["p3", "p4"]
      }
      ''';

      final json = jsonDecode(jsonString);
      final session = GameSession.fromJson(json);

      debugPrint('📊 Test 2 - Session ID: ${session.id}');
      debugPrint('📊 Test 2 - Status: ${session.status}');
      debugPrint('📊 Test 2 - Players count: ${session.players.length}');

      expect(session.id, 'session456');
      expect(session.status, 'lobby');
      expect(session.players.length, 4);

      // Les joueurs auront des noms vides (enrichissement requis)
      expect(session.players.every((p) => p.name.isEmpty), true);
      expect(session.players.every((p) => p.challengesSent == 0), true);
    });

    test('Parse backend format with players array (camelCase)', () {
      final jsonString = '''
      {
        "id": "session789",
        "status": "playing",
        "players": [
          {
            "id": "p1",
            "name": "Eve",
            "color": "red",
            "challengesSent": 3,
            "role": "drawer"
          },
          {
            "id": "p2",
            "name": "Frank",
            "color": "red",
            "challengesSent": 3,
            "role": "guesser"
          },
          {
            "id": "p3",
            "name": "Grace",
            "color": "blue",
            "challengesSent": 3,
            "role": "drawer"
          },
          {
            "id": "p4",
            "name": "Hank",
            "color": "blue",
            "challengesSent": 3,
            "role": "guesser"
          }
        ]
      }
      ''';

      final json = jsonDecode(jsonString);
      final session = GameSession.fromJson(json);

      debugPrint('📊 Test 3 - Session ID: ${session.id}');
      debugPrint('📊 Test 3 - Status: ${session.status}');
      debugPrint('📊 Test 3 - Players count: ${session.players.length}');

      expect(session.id, 'session789');
      expect(session.status, 'playing');
      expect(session.players.length, 4);

      // Tous les joueurs ont envoyé 3 challenges
      final playersReady = session.players.where((p) => p.challengesSent >= 3).length;
      debugPrint('📊 Test 3 - Players with 3+ challenges: $playersReady/4');
      expect(playersReady, 4);
    });

    test('Parse mixed format (player_id instead of id)', () {
      final jsonString = '''
      {
        "id": "session999",
        "status": "challenge",
        "red_team": [
          {
            "player_id": "p1",
            "name": "Ivy",
            "challenges_sent": 1
          }
        ],
        "blue_team": [
          {
            "player_id": "p2",
            "name": "Jack",
            "challenges_sent": 2
          }
        ]
      }
      ''';

      final json = jsonDecode(jsonString);
      final session = GameSession.fromJson(json);

      debugPrint('📊 Test 4 - Session ID: ${session.id}');
      debugPrint('📊 Test 4 - Players count: ${session.players.length}');

      expect(session.players.length, 2);

      final ivy = session.players.firstWhere((p) => p.name == 'Ivy');
      debugPrint('📊 Test 4 - Ivy ID: ${ivy.id}, challengesSent: ${ivy.challengesSent}');
      expect(ivy.id, 'p1');
      expect(ivy.challengesSent, 1);

      final jack = session.players.firstWhere((p) => p.name == 'Jack');
      debugPrint('📊 Test 4 - Jack ID: ${jack.id}, challengesSent: ${jack.challengesSent}');
      expect(jack.id, 'p2');
      expect(jack.challengesSent, 2);
    });
  });

  group('Player JSON Parsing Tests', () {
    test('Parse player with snake_case fields', () {
      final jsonString = '''
      {
        "id": "p123",
        "name": "TestPlayer",
        "color": "red",
        "role": "drawer",
        "challenges_sent": 3,
        "is_host": true,
        "has_drawn": false,
        "has_guessed": true
      }
      ''';

      final json = jsonDecode(jsonString);
      final player = Player.fromJson(json);

      debugPrint('📊 Player Test - Name: ${player.name}');
      debugPrint('📊 Player Test - challengesSent: ${player.challengesSent}');
      debugPrint('📊 Player Test - isHost: ${player.isHost}');

      expect(player.id, 'p123');
      expect(player.name, 'TestPlayer');
      expect(player.challengesSent, 3);
      expect(player.isHost, true);
      expect(player.hasDrawn, false);
      expect(player.hasGuessed, true);
    });

    test('Parse player with camelCase fields', () {
      final jsonString = '''
      {
        "id": "p456",
        "name": "TestPlayer2",
        "challengesSent": 2,
        "isHost": false
      }
      ''';

      final json = jsonDecode(jsonString);
      final player = Player.fromJson(json);

      debugPrint('📊 Player Test 2 - Name: ${player.name}');
      debugPrint('📊 Player Test 2 - challengesSent: ${player.challengesSent}');

      expect(player.id, 'p456');
      expect(player.name, 'TestPlayer2');
      expect(player.challengesSent, 2);
      expect(player.isHost, false);
    });
  });
}
