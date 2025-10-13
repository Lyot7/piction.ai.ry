# Test Infrastructure - Piction.ia.ry

Cette documentation explique l'infrastructure de tests mise en place pour le projet Piction.ia.ry.

## 📊 Vue d'ensemble

Le projet utilise une stratégie de tests complète avec 3 niveaux:

1. **Tests unitaires** (`test/unit/`) - Tests isolés de composants individuels
2. **Tests d'intégration** (`test/integration/`) - Tests de plusieurs composants ensemble
3. **Tests E2E** (`test/e2e/`) - Tests de l'application complète (à implémenter)

### Structure des dossiers

```
test/
├── unit/                    # Tests unitaires
│   ├── services/            # Tests des services
│   │   └── game_service_test.dart
│   └── models/              # Tests des modèles (à ajouter)
├── integration/             # Tests d'intégration
│   └── room_creation_flow_test.dart
├── e2e/                     # Tests End-to-End
│   └── room_creation_e2e_test.dart (placeholder)
├── helpers/                 # Utilitaires de test
│   ├── test_data.dart       # Fixtures de données
│   ├── test_helpers.dart    # Fonctions utilitaires
│   └── mock_api_service.dart # Mock de ApiService
└── README.md                # Ce fichier
```

## 🚀 Exécution des tests

### Tous les tests
```bash
flutter test
```

### Tests unitaires uniquement
```bash
flutter test test/unit/
```

### Tests d'intégration uniquement
```bash
flutter test test/integration/
```

### Un fichier spécifique
```bash
flutter test test/unit/services/game_service_test.dart
```

### Avec rapport de couverture
```bash
flutter test --coverage
# Voir le rapport:
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## 📝 Types de tests

### 1. Tests unitaires (Unit Tests)

**Objectif:** Tester un composant isolé (fonction, classe, méthode)

**Caractéristiques:**
- Très rapides (< 100ms par test)
- Pas de dépendances externes
- Utilisent des mocks/stubs
- Focalisés sur la logique métier

**Exemple:**
```dart
test('should correctly identify if player is drawer', () {
  final drawer = TestData.player1Host(role: 'drawer');
  expect(drawer.isDrawer, isTrue);
});
```

**Quand les utiliser:**
- Tester la logique métier
- Tester les modèles de données
- Tester les fonctions pures
- Validation de données

### 2. Tests d'intégration (Integration Tests)

**Objectif:** Tester plusieurs composants ensemble

**Caractéristiques:**
- Plus lents que les unitaires (100ms-1s)
- Testent les interactions entre composants
- Utilisent des mocks pour API
- Simulent des scénarios réels

**Exemple:**
```dart
test('SCENARIO: User creates room, joins red team, and sees themselves in lobby', () async {
  final mockApi = MockApiServiceFactory.empty();
  final session = await mockApi.createGameSession();
  final host = await mockApi.joinGameSession(session.id, 'red');
  final refreshed = await mockApi.refreshGameSession(session.id);

  expect(refreshed.players, contains(host));
});
```

**Quand les utiliser:**
- Tester des flows complets
- Tester des interactions service-modèle
- Valider des scénarios métier
- Tester la gestion d'erreurs

### 3. Tests E2E (End-to-End Tests)

**Objectif:** Tester l'application complète comme un utilisateur réel

**Caractéristiques:**
- Très lents (plusieurs secondes)
- Nécessitent un serveur de test
- Testent l'UI et les APIs réelles
- Détectent les bugs de régression

**Exemple:**
```dart
testWidgets('User can create a room and see QR code', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.tap(find.text('Créer une Room'));
  await tester.pumpAndSettle();

  expect(find.text('Partie créée avec succès'), findsOneWidget);
});
```

**Quand les utiliser:**
- Tester les flows critiques
- Validation avant release
- Tests de régression
- Tests d'acceptance

## 🛠️ Helpers et utilitaires

### TestData (`test/helpers/test_data.dart`)

Fournit des fixtures de données pour les tests.

**Exemples:**
```dart
// Créer un joueur host
final player = TestData.player1Host();

// Créer une session complète
final session = TestData.sessionWith4Players();

// Créer des réponses JSON
final json = TestData.sessionWithHostJson();
```

### TestHelpers (`test/helpers/test_helpers.dart`)

Fonctions utilitaires pour les tests.

**Exemples:**
```dart
// Attendre une condition
await TestHelpers.waitUntil(() => session.isReady);

// Vérifier une exception
await TestHelpers.expectThrowsWithMessage(
  () async => service.invalidOperation(),
  'Expected error message',
);

// Comparer des listes sans ordre
TestHelpers.expectUnorderedListEquals(actual, expected);
```

### MockApiService (`test/helpers/mock_api_service.dart`)

Mock de ApiService pour tester sans appels réseau.

**Exemples:**
```dart
// Mock basique
final mock = MockApiServiceFactory.empty();

// Mock avec données pré-remplies
final mock = MockApiServiceFactory.withHost();

// Mock qui échoue
final mock = MockApiServiceFactory.failing('Network error');

// Mock avec délai
final mock = MockApiServiceFactory.withDelay(Duration(milliseconds: 100));
```

## 📈 Statistiques actuelles

**Total:** 31 tests ✅

- **Tests unitaires:** 18 tests
  - GameService: 3 tests (placeholders pour extension)
  - Player Management: 3 tests
  - Team Management: 2 tests
  - GameSession Model: 4 tests
  - Player Model: 3 tests
  - Error Handling: 3 tests

- **Tests d'intégration:** 13 tests
  - Complete Room Flow: 6 tests
  - ID Matching: 3 tests
  - Error Scenarios: 3 tests
  - State Transitions: 1 test

- **Tests E2E:** 0 tests (infrastructure prête)

## 🎯 Bonnes pratiques

### 1. Nommer les tests clairement

```dart
// ✅ BON
test('should throw error when team is full', () { ... });

// ❌ MAUVAIS
test('error test', () { ... });
```

### 2. Suivre la structure AAA (Arrange-Act-Assert)

```dart
test('should add player to session', () {
  // ARRANGE (Given)
  final session = TestData.emptySession();
  final player = TestData.player1Host();

  // ACT (When)
  final updated = session.copyWith(players: [player]);

  // ASSERT (Then)
  expect(updated.players.length, equals(1));
});
```

### 3. Utiliser des noms de scénarios pour l'intégration

```dart
test('SCENARIO: User creates room, joins team, and starts game', () async {
  // ...
});
```

### 4. Un test = Une assertion principale

```dart
// ✅ BON
test('should mark host as isHost true', () {
  final player = TestData.player1Host();
  expect(player.isHost, isTrue);
});

test('should give host drawer role', () {
  final player = TestData.player1Host();
  expect(player.role, equals('drawer'));
});

// ❌ MAUVAIS (trop d'assertions)
test('host test', () {
  final player = TestData.player1Host();
  expect(player.isHost, isTrue);
  expect(player.role, equals('drawer'));
  expect(player.color, equals('red'));
  // ... 10 autres assertions
});
```

### 5. Nettoyer après les tests

```dart
setUp(() {
  // Initialisation
  gameService = GameService();
});

tearDown(() {
  // Nettoyage
  TestHelpers.cleanupSingletons();
});
```

## 🐛 Tests pour le debugging

Les tests incluent des diagnostics ultra-détaillés pour faciliter le debugging:

### Logs dans les tests
```dart
TestHelpers.debugLog('Testing player creation...');
```

### ID Matching Strategies
Les tests vérifient 4 stratégies de matching d'ID:
1. Match exact
2. Match après trim()
3. Match case-insensitive
4. Match par nom (fallback)

### Messages d'erreur détaillés
```dart
expect(player, isNotNull,
  reason: 'Player should be found by exact ID match'
);
```

## 📚 Ressources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Effective Dart: Testing](https://dart.dev/guides/language/effective-dart/testing)
- [Integration Testing](https://docs.flutter.dev/testing/integration-tests)

## 🔄 CI/CD Integration

Pour intégrer les tests dans une pipeline CI/CD:

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - run: flutter test test/integration/
```

## 🎓 Pour aller plus loin

### Tests à ajouter:
- [ ] Tests unitaires pour ApiService
- [ ] Tests unitaires pour les modèles (Challenge, etc.)
- [ ] Tests d'intégration pour le flow de jeu complet
- [ ] Tests de widgets pour les screens
- [ ] Tests E2E avec serveur de test
- [ ] Tests de performance

### Améliorations:
- [ ] Augmenter la couverture de code (target: 80%)
- [ ] Ajouter des tests de widgets
- [ ] Implémenter les E2E tests
- [ ] Ajouter des tests de snapshot
- [ ] Créer des golden tests pour l'UI
