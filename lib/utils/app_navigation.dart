import 'package:flutter/material.dart';

/// Utilitaire pour gérer la navigation de manière cohérente
///
/// Remplace les patterns PageRouteBuilder dupliqués dans toute l'application
class AppNavigation {
  /// Durée par défaut des transitions
  static const Duration defaultTransitionDuration = Duration(milliseconds: 150);

  /// Navigue vers un nouvel écran avec une transition fade
  ///
  /// Usage:
  /// ```dart
  /// AppNavigation.fadeTo(context, const HomeScreen());
  /// ```
  static Future<T?> fadeTo<T>(
    BuildContext context,
    Widget screen, {
    Duration? duration,
  }) {
    return Navigator.push<T>(
      context,
      _buildFadeRoute(screen, duration: duration),
    );
  }

  /// Remplace l'écran actuel avec une transition fade
  ///
  /// Usage:
  /// ```dart
  /// AppNavigation.fadeReplaceTo(context, const LobbyScreen());
  /// ```
  static Future<T?> fadeReplaceTo<T>(
    BuildContext context,
    Widget screen, {
    Duration? duration,
  }) {
    return Navigator.pushReplacement<T, void>(
      context,
      _buildFadeRoute(screen, duration: duration),
    );
  }

  /// Remplace tous les écrans de la stack avec une transition fade
  ///
  /// Usage:
  /// ```dart
  /// AppNavigation.fadeReplaceAll(context, const HomeScreen());
  /// ```
  static Future<T?> fadeReplaceAll<T>(
    BuildContext context,
    Widget screen, {
    Duration? duration,
  }) {
    return Navigator.pushAndRemoveUntil<T>(
      context,
      _buildFadeRoute(screen, duration: duration),
      (route) => false,
    );
  }

  /// Navigue vers un écran avec une transition slide (de droite à gauche)
  ///
  /// Usage:
  /// ```dart
  /// AppNavigation.slideTo(context, const GameScreen());
  /// ```
  static Future<T?> slideTo<T>(
    BuildContext context,
    Widget screen, {
    Duration? duration,
    SlideDirection direction = SlideDirection.fromRight,
  }) {
    return Navigator.push<T>(
      context,
      _buildSlideRoute(screen, direction: direction, duration: duration),
    );
  }

  /// Retourne à l'écran précédent
  ///
  /// Usage:
  /// ```dart
  /// AppNavigation.back(context, result: someData);
  /// ```
  static void back<T>(BuildContext context, {T? result}) {
    Navigator.pop<T>(context, result);
  }

  /// Retourne jusqu'à l'écran racine
  ///
  /// Usage:
  /// ```dart
  /// AppNavigation.backToRoot(context);
  /// ```
  static void backToRoot(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  /// Retourne jusqu'à un écran spécifique
  ///
  /// Usage:
  /// ```dart
  /// AppNavigation.backUntil(context, (route) => route.settings.name == '/home');
  /// ```
  static void backUntil(BuildContext context, bool Function(Route) predicate) {
    Navigator.popUntil(context, predicate);
  }

  /// Affiche un dialogue avec transition fade
  ///
  /// Usage:
  /// ```dart
  /// final result = await AppNavigation.showFadeDialog(
  ///   context,
  ///   child: const MyCustomDialog(),
  /// );
  /// ```
  static Future<T?> showFadeDialog<T>(
    BuildContext context, {
    required Widget child,
    bool barrierDismissible = true,
    Color? barrierColor,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: barrierColor ?? Colors.black54,
      transitionDuration: defaultTransitionDuration,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  /// Affiche un bottom sheet avec animation personnalisée
  ///
  /// Usage:
  /// ```dart
  /// await AppNavigation.showBottomSheet(
  ///   context,
  ///   child: const MyBottomSheetContent(),
  /// );
  /// ```
  static Future<T?> showBottomSheet<T>(
    BuildContext context, {
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => child,
    );
  }

  // === PRIVATE HELPERS ===

  /// Construit une route avec transition fade
  static PageRouteBuilder<T> _buildFadeRoute<T>(
    Widget screen, {
    Duration? duration,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionDuration: duration ?? defaultTransitionDuration,
      reverseTransitionDuration: duration ?? defaultTransitionDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  /// Construit une route avec transition slide
  static PageRouteBuilder<T> _buildSlideRoute<T>(
    Widget screen, {
    required SlideDirection direction,
    Duration? duration,
  }) {
    Offset begin;
    switch (direction) {
      case SlideDirection.fromRight:
        begin = const Offset(1.0, 0.0);
        break;
      case SlideDirection.fromLeft:
        begin = const Offset(-1.0, 0.0);
        break;
      case SlideDirection.fromTop:
        begin = const Offset(0.0, -1.0);
        break;
      case SlideDirection.fromBottom:
        begin = const Offset(0.0, 1.0);
        break;
    }

    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionDuration: duration ?? defaultTransitionDuration,
      reverseTransitionDuration: duration ?? defaultTransitionDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: begin, end: Offset.zero);
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        );

        return SlideTransition(
          position: tween.animate(curvedAnimation),
          child: child,
        );
      },
    );
  }
}

/// Direction de la transition slide
enum SlideDirection {
  /// De droite à gauche
  fromRight,

  /// De gauche à droite
  fromLeft,

  /// De haut en bas
  fromTop,

  /// De bas en haut
  fromBottom,
}
