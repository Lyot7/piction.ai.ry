import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'dart:async';

/// General test utilities and helper functions
class TestHelpers {
  /// Attend que tous les microtasks et timers soient complétés
  static Future<void> pumpEventQueue() async {
    await Future.delayed(Duration.zero);
  }

  /// Simule un délai réseau
  static Future<void> simulateNetworkDelay({int milliseconds = 100}) async {
    await Future.delayed(Duration(milliseconds: milliseconds));
  }

  /// Vérifie qu'une exception est lancée avec un message spécifique
  static Future<void> expectThrowsWithMessage(
    Future<void> Function() callback,
    String expectedMessage,
  ) async {
    try {
      await callback();
      fail('Expected exception was not thrown');
    } catch (e) {
      expect(e.toString(), contains(expectedMessage));
    }
  }

  /// Vérifie qu'une exception de type spécifique est lancée
  static Future<T> expectThrowsType<T extends Exception>(
    Future<void> Function() callback,
  ) async {
    try {
      await callback();
      fail('Expected exception of type $T was not thrown');
    } catch (e) {
      expect(e, isA<T>());
      return e as T;
    }
  }

  /// Attend qu'une condition soit vraie (avec timeout)
  static Future<void> waitUntil(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration checkInterval = const Duration(milliseconds: 100),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (!condition()) {
      if (stopwatch.elapsed > timeout) {
        throw TimeoutException('Condition not met within $timeout');
      }
      await Future.delayed(checkInterval);
    }
  }

  /// Vérifie qu'un Stream émet une valeur spécifique
  static Future<T> expectStreamEmits<T>(
    Stream<T> stream,
    T expectedValue, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final value = await stream.first.timeout(timeout);
    expect(value, equals(expectedValue));
    return value;
  }

  /// Vérifie qu'un Stream émet une valeur qui satisfait une condition
  static Future<T> expectStreamEmitsWhere<T>(
    Stream<T> stream,
    bool Function(T) test, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await for (final value in stream) {
      if (test(value)) {
        return value;
      }
    }
    throw TimeoutException('Stream did not emit expected value');
  }

  /// Compte le nombre d'émissions d'un Stream pendant une durée
  static Future<int> countStreamEmissions<T>(
    Stream<T> stream,
    Duration duration,
  ) async {
    int count = 0;
    final subscription = stream.listen((_) => count++);

    await Future.delayed(duration);
    await subscription.cancel();

    return count;
  }

  /// Exécute une fonction avec un FakeAsync pour contrôler le temps
  static T runWithFakeAsync<T>(T Function(FakeAsync) callback) {
    return fakeAsync((async) => callback(async));
  }

  /// Compare deux listes sans tenir compte de l'ordre
  static void expectUnorderedListEquals<T>(List<T> actual, List<T> expected) {
    expect(actual.length, equals(expected.length));
    for (final item in expected) {
      expect(actual, contains(item));
    }
  }

  /// Vérifie qu'une Map contient toutes les clés attendues
  static void expectMapContainsKeys(Map map, List keys) {
    for (final key in keys) {
      expect(map.containsKey(key), isTrue, reason: 'Map should contain key: $key');
    }
  }

  /// Crée un matcher custom pour vérifier un Player
  static Matcher isPlayerWithId(String id) {
    return predicate(
      (dynamic player) => player is Map && player['id'] == id,
      'Player with id $id',
    );
  }

  /// Crée un matcher custom pour vérifier un GameSession
  static Matcher isSessionWithId(String id) {
    return predicate(
      (dynamic session) => session is Map && session['id'] == id,
      'GameSession with id $id',
    );
  }

  /// Crée un matcher custom pour vérifier un status de GameSession
  static Matcher hasStatus(String status) {
    return predicate(
      (dynamic session) => session is Map && session['status'] == status,
      'GameSession with status $status',
    );
  }

  /// Crée un matcher custom pour vérifier le nombre de joueurs
  static Matcher hasPlayerCount(int count) {
    return predicate(
      (dynamic session) => session is Map && (session['players'] as List?)?.length == count,
      'GameSession with $count players',
    );
  }

  /// Vérifie qu'un joueur est dans une équipe spécifique
  static Matcher isInTeam(String color) {
    return predicate(
      (dynamic player) => player is Map && player['color'] == color,
      'Player in team $color',
    );
  }

  /// Vérifie qu'un joueur a un rôle spécifique
  static Matcher hasRole(String role) {
    return predicate(
      (dynamic player) => player is Map && player['role'] == role,
      'Player with role $role',
    );
  }

  /// Crée un ID de test unique
  static String generateTestId([String? prefix]) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return '${prefix ?? 'test'}-$timestamp-$random';
  }

  /// Nettoie les singletons entre les tests (si nécessaire)
  static void cleanupSingletons() {
    // Cette fonction peut être étendue pour nettoyer les singletons
    // entre les tests si nécessaire
  }
}

/// Matchers personnalisés pour les tests
class CustomMatchers {
  /// Vérifie qu'une String est un ID valide (non vide, format correct)
  static Matcher isValidId() {
    return predicate(
      (value) => value is String && value.isNotEmpty && value.length > 5,
      'valid ID',
    );
  }

  /// Vérifie qu'une DateTime est récente (moins de N secondes)
  static Matcher isRecent({int seconds = 10}) {
    return predicate(
      (value) {
        if (value is! DateTime) return false;
        final diff = DateTime.now().difference(value);
        return diff.inSeconds.abs() <= seconds;
      },
      'recent DateTime (within $seconds seconds)',
    );
  }

  /// Vérifie qu'une liste n'est pas vide
  static Matcher isNotEmptyList() {
    return predicate(
      (value) => value is List && value.isNotEmpty,
      'non-empty list',
    );
  }

  /// Vérifie qu'une liste a une taille spécifique
  static Matcher hasLength(int length) {
    return predicate(
      (value) => value is List && value.length == length,
      'list with length $length',
    );
  }
}
