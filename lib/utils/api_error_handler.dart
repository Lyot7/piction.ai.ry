import 'logger.dart';

/// Utilitaire pour gérer les erreurs API de manière centralisée
/// Principe SOLID: Single Responsibility - Uniquement la gestion d'erreurs
class ApiErrorHandler {
  /// Détermine si une erreur est transitoire (réseau, timeout, etc.)
  static bool isTransientError(Exception error) {
    final errorMessage = error.toString().toLowerCase();

    return errorMessage.contains('connection closed') ||
        errorMessage.contains('connection reset') ||
        errorMessage.contains('timeout') ||
        errorMessage.contains('socket') ||
        errorMessage.contains('network') ||
        errorMessage.contains('handshake') ||
        errorMessage.contains('connection refused');
  }

  /// Détermine si une erreur indique que le joueur est déjà dans une session
  static bool isAlreadyInSessionError(Exception error) {
    final errorMessage = error.toString().toLowerCase();

    return errorMessage.contains('already in game session') ||
        errorMessage.contains('player already in') ||
        errorMessage.contains('already in room');
  }

  /// Détermine si une erreur indique que le joueur n'est pas dans une session
  static bool isNotInSessionError(Exception error) {
    final errorMessage = error.toString().toLowerCase();

    return errorMessage.contains('not in game session') ||
        errorMessage.contains('player not in') ||
        errorMessage.contains('not in room');
  }

  /// Détermine si une erreur doit être ignorée silencieusement
  static bool shouldIgnoreError(Exception error) {
    return isTransientError(error) ||
        isAlreadyInSessionError(error) ||
        isNotInSessionError(error);
  }

  /// Formate un message d'erreur pour l'affichage à l'utilisateur
  static String formatUserMessage(Exception error) {
    final errorMessage = error.toString();

    // Retirer le préfixe "Exception: " si présent
    if (errorMessage.startsWith('Exception: ')) {
      return errorMessage.substring(11);
    }

    return errorMessage;
  }

  /// Log une erreur avec contexte
  static void logError(String context, Exception error, [StackTrace? stackTrace]) {
    AppLogger.error('[$context] ${error.toString()}', error);

    if (stackTrace != null) {
      AppLogger.error('[$context] StackTrace:', stackTrace);
    }
  }

  /// Gère une erreur avec retry automatique
  static Future<T> handleWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration? retryDelay,
    String? context,
  }) async {
    int attempt = 0;
    Exception? lastError;

    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        attempt++;

        if (context != null) {
          AppLogger.warning('[$context] Tentative $attempt/$maxRetries échouée');
        }

        if (isTransientError(lastError) && attempt < maxRetries) {
          final delay = retryDelay ?? Duration(milliseconds: 100 * attempt);
          await Future.delayed(delay);
        } else if (!isTransientError(lastError)) {
          rethrow;
        }
      }
    }

    throw Exception('Opération échouée après $maxRetries tentatives: $lastError');
  }
}
