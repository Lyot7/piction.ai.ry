import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/polling_service.dart';
import '../utils/logger.dart';

/// Service responsable de la gestion des transitions de phase du jeu
///
/// Principe SOLID: Single Responsibility Principle
/// Ce service a une seule responsabilité: gérer les transitions de phase
class PhaseTransitionService {
  final PollingService _pollingService = PollingService();

  /// Callback appelé quand une transition est détectée
  VoidCallback? onTransitionDetected;

  /// Démarre l'écoute d'une transition de phase spécifique
  ///
  /// [checkCondition] - Fonction async qui retourne true quand la transition doit se produire
  /// [onTransition] - Callback appelé quand la condition est remplie
  /// [pollingInterval] - Intervalle entre chaque vérification (défaut: 2 secondes)
  void startListening({
    required Future<bool> Function() checkCondition,
    required VoidCallback onTransition,
    Duration pollingInterval = const Duration(seconds: 2),
  }) {
    bool hasTransitioned = false;

    _pollingService.startPolling(
      interval: pollingInterval,
      onPoll: () async {
        if (hasTransitioned) return;

        try {
          final shouldTransition = await checkCondition();

          if (shouldTransition && !hasTransitioned) {
            hasTransitioned = true;
            _pollingService.stopPolling();
            onTransition();
            AppLogger.info('[PhaseTransitionService] Transition déclenchée');
          }
        } catch (e) {
          AppLogger.error('[PhaseTransitionService] Erreur lors de la vérification', e);
        }
      },
      name: 'PhaseTransitionService',
    );
  }

  /// Arrête l'écoute des transitions
  void stopListening() {
    _pollingService.stopPolling();
    AppLogger.info('[PhaseTransitionService] Arrêt de l\'écoute des transitions');
  }

  /// Nettoie les ressources
  void dispose() {
    stopListening();
  }
}

/// Factory pour créer des conditions de transition pré-configurées
///
/// Principe SOLID: Open/Closed Principle
/// Facile d'ajouter de nouvelles conditions sans modifier le code existant
class TransitionConditions {
  /// Condition: attendre que la phase du jeu change vers une phase spécifique
  static Future<bool> Function() waitForPhase({
    required Future<String?> Function() getCurrentPhase,
    required String targetPhase,
  }) {
    return () async {
      final currentPhase = await getCurrentPhase();
      final result = currentPhase == targetPhase;

      if (result) {
        AppLogger.info('[TransitionConditions] Phase cible "$targetPhase" atteinte');
      }

      return result;
    };
  }

  /// Condition: attendre que le statut du jeu change vers un statut spécifique
  static Future<bool> Function() waitForStatus({
    required Future<String?> Function() getCurrentStatus,
    required String targetStatus,
  }) {
    return () async {
      final currentStatus = await getCurrentStatus();
      final result = currentStatus == targetStatus;

      if (result) {
        AppLogger.info('[TransitionConditions] Statut cible "$targetStatus" atteint');
      }

      return result;
    };
  }

  /// Condition: attendre qu'un nombre minimum de joueurs aient terminé
  static Future<bool> Function() waitForPlayersReady({
    required Future<int> Function() getReadyPlayersCount,
    required int requiredCount,
  }) {
    return () async {
      final readyCount = await getReadyPlayersCount();
      final result = readyCount >= requiredCount;

      if (result) {
        AppLogger.info('[TransitionConditions] $readyCount/$requiredCount joueurs prêts');
      }

      return result;
    };
  }
}
