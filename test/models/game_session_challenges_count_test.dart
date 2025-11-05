import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:piction_ai_ry/models/game_session.dart';

void main() {
  group('GameSession Challenge Count Calculation', () {
    test('Calculate challengesSent from backend challenges array', () {
      // Format RÉEL du backend
      final jsonString = '''
      {
        "id": 2295,
        "status": "drawing",
        "red_team": [602, 369],
        "blue_team": [370, 372],
        "challenges": [
          {"id": 1, "challenger_id": 602, "challenged_id": 372},
          {"id": 2, "challenger_id": 602, "challenged_id": 370},
          {"id": 3, "challenger_id": 602, "challenged_id": 369},
          {"id": 4, "challenger_id": 369, "challenged_id": 602},
          {"id": 5, "challenger_id": 369, "challenged_id": 370},
          {"id": 6, "challenger_id": 369, "challenged_id": 372},
          {"id": 7, "challenger_id": 370, "challenged_id": 602},
          {"id": 8, "challenger_id": 370, "challenged_id": 369},
          {"id": 9, "challenger_id": 372, "challenged_id": 602}
        ]
      }
      ''';

      final json = jsonDecode(jsonString);
      final session = GameSession.fromJson(json);

      print('📊 Session status: ${session.status}');
      print('📊 Players count: ${session.players.length}');

      expect(session.status, 'drawing');
      expect(session.players.length, 4);

      // Vérifier le compte des challenges
      final player602 = session.players.firstWhere((p) => p.id == '602');
      final player369 = session.players.firstWhere((p) => p.id == '369');
      final player370 = session.players.firstWhere((p) => p.id == '370');
      final player372 = session.players.firstWhere((p) => p.id == '372');

      print('📊 Player 602 challengesSent: ${player602.challengesSent}');
      print('📊 Player 369 challengesSent: ${player369.challengesSent}');
      print('📊 Player 370 challengesSent: ${player370.challengesSent}');
      print('📊 Player 372 challengesSent: ${player372.challengesSent}');

      expect(player602.challengesSent, 3); // A envoyé 3 challenges
      expect(player369.challengesSent, 3); // A envoyé 3 challenges
      expect(player370.challengesSent, 2); // A envoyé 2 challenges
      expect(player372.challengesSent, 1); // A envoyé 1 challenge

      // Compter combien ont envoyé 3+ challenges
      final playersReady = session.players.where((p) => p.challengesSent >= 3).length;
      print('📊 Players with 3+ challenges: $playersReady/4');
      expect(playersReady, 2); // 602 et 369
    });

    test('Handle case with no challenges yet', () {
      final jsonString = '''
      {
        "id": 2295,
        "status": "challenge",
        "red_team": [602, 369],
        "blue_team": [370, 372],
        "challenges": []
      }
      ''';

      final json = jsonDecode(jsonString);
      final session = GameSession.fromJson(json);

      print('📊 Session status: ${session.status}');
      expect(session.status, 'challenge');

      // Tous les joueurs devraient avoir 0 challenges
      for (final player in session.players) {
        print('📊 Player ${player.id} challengesSent: ${player.challengesSent}');
        expect(player.challengesSent, 0);
      }
    });

    test('Calculate when all 4 players have sent 3 challenges', () {
      final jsonString = '''
      {
        "id": 2295,
        "status": "drawing",
        "red_team": [602, 369],
        "blue_team": [370, 372],
        "challenges": [
          {"id": 1, "challenger_id": 602, "challenged_id": 372},
          {"id": 2, "challenger_id": 602, "challenged_id": 370},
          {"id": 3, "challenger_id": 602, "challenged_id": 369},
          {"id": 4, "challenger_id": 369, "challenged_id": 602},
          {"id": 5, "challenger_id": 369, "challenged_id": 370},
          {"id": 6, "challenger_id": 369, "challenged_id": 372},
          {"id": 7, "challenger_id": 370, "challenged_id": 602},
          {"id": 8, "challenger_id": 370, "challenged_id": 369},
          {"id": 9, "challenger_id": 370, "challenged_id": 372},
          {"id": 10, "challenger_id": 372, "challenged_id": 602},
          {"id": 11, "challenger_id": 372, "challenged_id": 369},
          {"id": 12, "challenger_id": 372, "challenged_id": 370}
        ]
      }
      ''';

      final json = jsonDecode(jsonString);
      final session = GameSession.fromJson(json);

      // Tous devraient avoir 3 challenges
      for (final player in session.players) {
        print('📊 Player ${player.id} challengesSent: ${player.challengesSent}');
        expect(player.challengesSent, 3);
      }

      final playersReady = session.players.where((p) => p.challengesSent >= 3).length;
      print('📊 ALL READY! Players with 3+ challenges: $playersReady/4');
      expect(playersReady, 4);
    });
  });
}
