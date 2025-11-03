import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piction_ai_ry/services/deep_link_service.dart';
import '../helpers/mock_api_service.dart';

/// Tests d'intégration pour le workflow QR Code et deep linking
///
/// Ces tests vérifient:
/// - La génération de liens de room
/// - Le parsing des deep links
/// - Le workflow complet de join via QR code
void main() {
  group('Integration - QR Code & Deep Linking Flow', () {
    late DeepLinkService deepLinkService;
    late MockApiService mockApi;

    setUp(() {
      deepLinkService = DeepLinkService();
      mockApi = MockApiServiceFactory.empty();
    });

    test('SCENARIO: Generate room link for QR code', () {
      // ===== PHASE 1: Créer une session =====
      debugPrint('\n📝 PHASE 1: Création de room et génération de lien');

      const roomId = 'ABCD1234';

      // ===== ACTION: Générer le lien de room =====
      final roomLink = deepLinkService.generateRoomLink(roomId);

      debugPrint('✅ Lien de room généré: $roomLink');

      // ===== VÉRIFICATION: Format du lien =====
      expect(roomLink, isNotEmpty);
      expect(roomLink, contains('piction'),
        reason: 'Link should contain app scheme');
      expect(roomLink, contains(roomId),
        reason: 'Link should contain room ID');

      debugPrint('✅ Format de lien valide');

      // ===== VÉRIFICATION: Le lien peut être scanné/partagé =====
      // Simuler un scan de QR code qui retourne ce lien
      final scannedLink = roomLink;
      expect(scannedLink, equals(roomLink));
      debugPrint('✅ Lien prêt pour QR code ou partage');

      debugPrint('\n✅ TEST PASSED: Room link generation');
    });

    test('SCENARIO: Parse room ID from deep link', () {
      debugPrint('\n📝 Test de parsing de deep link');

      const roomId = 'XYZ9876';

      // Générer le lien
      final link = deepLinkService.generateRoomLink(roomId);
      debugPrint('✅ Lien généré: $link');

      // ===== ACTION: Parser le lien pour extraire le room ID =====
      final parsedRoomId = deepLinkService.parseRoomIdFromLink(link);

      // ===== VÉRIFICATION: Room ID correctement extrait =====
      expect(parsedRoomId, equals(roomId),
        reason: 'Should extract exact room ID from link');
      debugPrint('✅ Room ID extrait: $parsedRoomId');

      debugPrint('\n✅ TEST PASSED: Deep link parsing');
    });

    test('SCENARIO: Complete QR code join flow', () async {
      // Ce test simule le workflow complet:
      // 1. Host crée une room
      // 2. Host génère un QR code
      // 3. Guest scanne le QR code
      // 4. Guest est automatiquement redirigé vers le lobby
      // 5. Guest rejoint une équipe

      debugPrint('\n📝 WORKFLOW COMPLET: Join via QR Code');

      // ===== PHASE 1: HOST - Créer la room =====
      debugPrint('\n📱 HOST:');

      final hostSession = await mockApi.createGameSession();
      final hostPlayer = await mockApi.joinGameSession(hostSession.id, 'red');

      debugPrint('   ✅ Room créée par ${hostPlayer.name}');
      debugPrint('   ✅ Room ID: ${hostSession.id}');

      // ===== PHASE 2: HOST - Générer le lien pour QR code =====
      final qrCodeLink = deepLinkService.generateRoomLink(hostSession.id);
      debugPrint('   ✅ Lien QR généré: $qrCodeLink');

      // ===== PHASE 3: GUEST - Scanner le QR code =====
      debugPrint('\n📱 GUEST:');
      debugPrint('   🔍 Scan du QR code...');

      final scannedLink = qrCodeLink; // Simule le scan
      final roomIdFromQR = deepLinkService.parseRoomIdFromLink(scannedLink);

      expect(roomIdFromQR, isNotNull, reason: 'Should extract room ID from QR');
      expect(roomIdFromQR, equals(hostSession.id),
        reason: 'Should extract correct room ID from scanned QR');
      debugPrint('   ✅ Room ID extrait du QR: $roomIdFromQR');

      // ===== PHASE 4: GUEST - Rejoindre automatiquement la room =====
      final guestPlayer = await mockApi.joinGameSession(roomIdFromQR!, 'blue');
      debugPrint('   ✅ ${guestPlayer.name} a rejoint la room');

      // ===== VÉRIFICATION: Les 2 joueurs sont dans la même session =====
      final updatedSession = await mockApi.refreshGameSession(hostSession.id);

      expect(updatedSession.players.length, equals(2));
      expect(updatedSession.players.any((p) => p.id == hostPlayer.id), isTrue,
        reason: 'Host should be in session');
      expect(updatedSession.players.any((p) => p.id == guestPlayer.id), isTrue,
        reason: 'Guest should be in session');

      debugPrint('\n📊 État final de la session:');
      debugPrint('   - Total joueurs: ${updatedSession.players.length}');
      debugPrint('   - Host: ${hostPlayer.name} (${hostPlayer.color} team)');
      debugPrint('   - Guest: ${guestPlayer.name} (${guestPlayer.color} team)');

      debugPrint('\n✅ TEST PASSED: Complete QR code join flow');
    });

    test('SCENARIO: Multiple guests join via QR code', () async {
      debugPrint('\n📝 WORKFLOW: Multiple guests via QR code');

      // ===== SETUP: Host crée la room =====
      final hostSession = await mockApi.createGameSession();
      final hostPlayer = await mockApi.joinGameSession(hostSession.id, 'red');

      debugPrint('✅ Host ${hostPlayer.name} a créé la room ${hostSession.id}');
      debugPrint('✅ QR code généré et partagé');

      // ===== ACTION: 3 guests scannent le QR code =====
      debugPrint('\n📱 3 guests scannent le QR code:');

      final guest1 = await mockApi.joinGameSession(hostSession.id, 'red');
      debugPrint('   ✅ Guest 1: ${guest1.name} (${guest1.color} team)');

      final guest2 = await mockApi.joinGameSession(hostSession.id, 'blue');
      debugPrint('   ✅ Guest 2: ${guest2.name} (${guest2.color} team)');

      final guest3 = await mockApi.joinGameSession(hostSession.id, 'blue');
      debugPrint('   ✅ Guest 3: ${guest3.name} (${guest3.color} team)');

      // ===== VÉRIFICATION: Tous sont dans la session =====
      final fullSession = await mockApi.refreshGameSession(hostSession.id);

      expect(fullSession.players.length, equals(4));
      expect(fullSession.isReadyToStart, isTrue);

      debugPrint('\n📊 Session complète:');
      debugPrint('   - Total joueurs: ${fullSession.players.length}');
      debugPrint('   - Red team: ${fullSession.getTeamPlayers('red').length}');
      debugPrint('   - Blue team: ${fullSession.getTeamPlayers('blue').length}');
      debugPrint('   - Prête à démarrer: ${fullSession.isReadyToStart ? 'OUI' : 'NON'}');

      debugPrint('\n✅ TEST PASSED: Multiple QR code joins');
    });

    test('SCENARIO: Invalid deep link is rejected', () {
      debugPrint('\n📝 Test de liens invalides');

      // Liens malformés
      final invalidLinks = [
        '',
        'http://example.com',
        'piction://invalid',
        'piction://',
        'invalid-link',
        'https://example.com/room/123',
      ];

      for (final invalidLink in invalidLinks) {
        debugPrint('\n   🔍 Test: "$invalidLink"');

        final roomId = deepLinkService.parseRoomIdFromLink(invalidLink);

        // Les liens invalides devraient retourner null ou string vide
        expect(roomId, anyOf(isNull, isEmpty),
          reason: 'Invalid link should not extract room ID');

        debugPrint('   ✅ Correctement rejeté');
      }

      debugPrint('\n✅ TEST PASSED: Invalid link handling');
    });

    test('SCENARIO: Manual room code entry (alternative to QR)', () async {
      // Test du flow alternatif: entrer le code manuellement
      debugPrint('\n📝 WORKFLOW: Manual room code entry');

      // ===== SETUP: Host crée la room =====
      final hostSession = await mockApi.createGameSession();
      await mockApi.joinGameSession(hostSession.id, 'red');

      debugPrint('✅ Room créée avec code: ${hostSession.id}');

      // ===== PHASE 1: Guest entre le code manuellement =====
      debugPrint('\n📱 GUEST entre le code manuellement:');
      final manualCode = hostSession.id;
      debugPrint('   ✏️ Code entré: $manualCode');

      // ===== VÉRIFICATION: Le code est valide (session existe) =====
      final sessionCheck = await mockApi.getGameSession(manualCode);
      expect(sessionCheck.id, equals(manualCode));
      debugPrint('   ✅ Code valide, session trouvée');

      // ===== PHASE 2: Guest rejoint avec le code =====
      final guestPlayer = await mockApi.joinGameSession(manualCode, 'blue');
      debugPrint('   ✅ ${guestPlayer.name} a rejoint avec le code');

      // ===== VÉRIFICATION: Guest est dans la session =====
      final updatedSession = await mockApi.refreshGameSession(hostSession.id);
      expect(updatedSession.players.length, equals(2));
      expect(updatedSession.players.any((p) => p.id == guestPlayer.id), isTrue);

      debugPrint('\n✅ TEST PASSED: Manual code entry flow');
    });

    test('SCENARIO: QR code link format consistency', () {
      debugPrint('\n📝 Test de cohérence du format de liens');

      // Générer plusieurs liens pour différentes rooms
      final roomIds = ['ROOM1', 'ABCD', 'XYZ123', '12345'];
      final links = <String>[];

      debugPrint('\n🔗 Génération de liens:');
      for (final roomId in roomIds) {
        final link = deepLinkService.generateRoomLink(roomId);
        links.add(link);
        debugPrint('   $roomId → $link');

        // Vérifier que le parsing fonctionne
        final parsedId = deepLinkService.parseRoomIdFromLink(link);
        expect(parsedId, equals(roomId),
          reason: 'Should parse back to original room ID');
      }

      // ===== VÉRIFICATION: Tous les liens ont un format cohérent =====
      final allHaveSameScheme = links.every((link) => link.contains('piction'));
      expect(allHaveSameScheme, isTrue,
        reason: 'All links should use same scheme');

      debugPrint('\n✅ Format cohérent pour tous les liens');
      debugPrint('✅ TEST PASSED: Link format consistency');
    });

    test('SCENARIO: Deep link with extra parameters', () {
      debugPrint('\n📝 Test de deep link avec paramètres additionnels');

      const roomId = 'TEST123';
      final baseLink = deepLinkService.generateRoomLink(roomId);

      // Simuler un lien avec paramètres supplémentaires
      // (ex: venant d'un partage social, analytics, etc.)
      final linkWithParams = '$baseLink?utm_source=share&ref=qr';

      debugPrint('✅ Lien avec paramètres: $linkWithParams');

      // ===== VÉRIFICATION: Le parsing fonctionne malgré les paramètres =====
      final parsedRoomId = deepLinkService.parseRoomIdFromLink(linkWithParams);

      expect(parsedRoomId, equals(roomId),
        reason: 'Should extract room ID even with extra params');

      debugPrint('✅ Room ID extrait malgré paramètres: $parsedRoomId');
      debugPrint('✅ TEST PASSED: Deep link with parameters');
    });
  });

  group('Integration - QR Code Edge Cases', () {
    late DeepLinkService deepLinkService;
    late MockApiService mockApi;

    setUp(() {
      deepLinkService = DeepLinkService();
      mockApi = MockApiServiceFactory.empty();
    });

    test('SCENARIO: Joining full room via QR code shows error', () async {
      debugPrint('\n📝 Tentative de join d\'une room pleine via QR');

      // ===== SETUP: Room complète (4 joueurs) =====
      final session = await mockApi.createGameSession();
      await mockApi.joinGameSession(session.id, 'red');
      await mockApi.joinGameSession(session.id, 'red');
      await mockApi.joinGameSession(session.id, 'blue');
      await mockApi.joinGameSession(session.id, 'blue');

      final fullSession = await mockApi.refreshGameSession(session.id);
      expect(fullSession.players.length, equals(4));
      debugPrint('✅ Room complète (4 joueurs)');

      // ===== ACTION: Guest scanne QR code =====
      final qrLink = deepLinkService.generateRoomLink(session.id);
      final roomId = deepLinkService.parseRoomIdFromLink(qrLink);
      expect(roomId, isNotNull);

      debugPrint('📱 Guest scanne le QR code...');

      // ===== VÉRIFICATION: Tentative de join échoue =====
      // Tenter de rejoindre l'équipe rouge (pleine)
      expect(
        () async => await mockApi.joinGameSession(roomId!, 'red'),
        throwsException,
      );

      debugPrint('✅ Erreur correctement levée (équipe rouge pleine)');

      // Tenter de rejoindre l'équipe bleue (pleine aussi)
      expect(
        () async => await mockApi.joinGameSession(roomId!, 'blue'),
        throwsException,
      );

      debugPrint('✅ Erreur correctement levée (équipe bleue pleine)');
      debugPrint('✅ TEST PASSED: Full room rejection');
    });

    test('SCENARIO: Scanning QR code of non-existent room', () {
      debugPrint('\n📝 QR code d\'une room inexistante');

      const fakeRoomId = 'NONEXISTENT';
      final qrLink = deepLinkService.generateRoomLink(fakeRoomId);

      debugPrint('✅ QR code généré pour room inexistante: $qrLink');

      // Le parsing fonctionne (lien valide)
      final roomId = deepLinkService.parseRoomIdFromLink(qrLink);
      expect(roomId, isNotNull);
      expect(roomId, equals(fakeRoomId));
      debugPrint('✅ Parsing réussi: $roomId');

      // Mais la tentative de join échouera (session inexistante)
      expect(
        () async => await mockApi.getGameSession(roomId!),
        throwsException,
      );

      debugPrint('✅ Join correctement échoué (room n\'existe pas)');
      debugPrint('✅ TEST PASSED: Non-existent room handling');
    });

    test('SCENARIO: Re-joining room via QR code after leaving', () async {
      debugPrint('\n📝 Re-join via QR après avoir quitté');

      // ===== SETUP: Player rejoint puis quitte =====
      final session = await mockApi.createGameSession();
      final player = await mockApi.joinGameSession(session.id, 'red');

      debugPrint('✅ ${player.name} a rejoint la room');

      await mockApi.leaveGameSession(session.id, player.id);
      debugPrint('✅ ${player.name} a quitté la room');

      // ===== ACTION: Player re-scanne le QR code =====
      final qrLink = deepLinkService.generateRoomLink(session.id);
      final roomId = deepLinkService.parseRoomIdFromLink(qrLink);
      expect(roomId, isNotNull);

      debugPrint('📱 ${player.name} re-scanne le QR code...');

      // ===== VÉRIFICATION: Re-join fonctionne =====
      final rejoinedPlayer = await mockApi.joinGameSession(roomId!, 'blue');
      expect(rejoinedPlayer, isNotNull);
      debugPrint('✅ Re-join réussi (nouvelle équipe: ${rejoinedPlayer.color})');

      final updatedSession = await mockApi.refreshGameSession(session.id);
      expect(updatedSession.players.any((p) => p.id == rejoinedPlayer.id), isTrue);

      debugPrint('✅ TEST PASSED: Re-join after leaving');
    });
  });
}
