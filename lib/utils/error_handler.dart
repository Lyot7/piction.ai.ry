import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import 'logger.dart';

/// Utilitaire pour gérer les erreurs de manière cohérente dans toute l'application
///
/// Remplace les patterns try-catch-showSnackBar dupliqués dans tous les écrans
class ErrorHandler {
  /// Affiche un message d'erreur à l'utilisateur via SnackBar
  ///
  /// Gère automatiquement:
  /// - Le formatage du message (retire "Exception: ")
  /// - La vérification du context monté
  /// - Le logging de l'erreur
  /// - Le style cohérent (couleur rouge)
  static void showError(
    BuildContext context,
    dynamic error, {
    String? customMessage,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) {
      AppLogger.warning('[ErrorHandler] Context not mounted, skipping error display');
      return;
    }

    // Logger l'erreur pour debug
    AppLogger.error('[ErrorHandler] Error occurred', error);

    // Formater le message
    String message = customMessage ?? _formatErrorMessage(error);

    // Afficher le SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Affiche un message de succès
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Affiche un message d'information
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue[700],
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Affiche un avertissement
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange[700],
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Affiche un dialogue d'erreur pour les erreurs critiques
  static Future<void> showErrorDialog(
    BuildContext context,
    dynamic error, {
    String? title,
    String? customMessage,
  }) async {
    if (!context.mounted) return;

    AppLogger.error('[ErrorHandler] Critical error', error);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title ?? 'Erreur'),
          content: Text(customMessage ?? _formatErrorMessage(error)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Wrapper pour try-catch avec gestion automatique des erreurs
  ///
  /// Usage:
  /// ```dart
  /// await ErrorHandler.handleAsync(
  ///   context,
  ///   () async => await someAsyncOperation(),
  ///   successMessage: 'Opération réussie',
  ///   errorMessage: 'Erreur lors de l\'opération',
  /// );
  /// ```
  static Future<T?> handleAsync<T>(
    BuildContext context,
    Future<T> Function() operation, {
    String? successMessage,
    String? errorMessage,
    void Function(T result)? onSuccess,
    void Function(dynamic error)? onError,
  }) async {
    try {
      final result = await operation();

      if (successMessage != null && context.mounted) {
        showSuccess(context, successMessage);
      }

      onSuccess?.call(result);
      return result;
    } catch (e) {
      if (context.mounted) {
        showError(context, e, customMessage: errorMessage);
      }

      onError?.call(e);
      return null;
    }
  }

  /// Formate un message d'erreur de manière cohérente
  static String _formatErrorMessage(dynamic error) {
    if (error == null) return 'Une erreur inconnue est survenue';

    String message = error.toString();

    // Retirer les préfixes courants
    message = message.replaceFirst('Exception: ', '');
    message = message.replaceFirst('Error: ', '');

    // Nettoyer les stack traces
    if (message.contains('\n')) {
      message = message.split('\n').first;
    }

    return message;
  }

  /// Vérifie si une erreur est une erreur réseau transitoire
  static bool isTransientError(dynamic error) {
    final errorMessage = error.toString().toLowerCase();
    return errorMessage.contains('connection closed') ||
        errorMessage.contains('timeout') ||
        errorMessage.contains('connection refused') ||
        errorMessage.contains('socket') ||
        errorMessage.contains('network');
  }

  /// Vérifie si une erreur est une erreur d'authentification
  static bool isAuthError(dynamic error) {
    final errorMessage = error.toString().toLowerCase();
    return errorMessage.contains('401') ||
        errorMessage.contains('unauthorized') ||
        errorMessage.contains('authentication') ||
        errorMessage.contains('jwt');
  }
}
