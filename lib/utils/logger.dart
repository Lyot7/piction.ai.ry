import 'package:flutter/foundation.dart';

/// Simple logger utility for the app
/// Uses debugPrint in development, no-op in production
class AppLogger {
  static void log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('❌ ERROR: $message');
      if (error != null) {
        debugPrint('Error details: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ INFO: $message');
    }
  }

  static void success(String message) {
    if (kDebugMode) {
      debugPrint('✅ SUCCESS: $message');
    }
  }

  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ WARNING: $message');
    }
  }
}
