import 'dart:async';
import '../utils/logger.dart';

/// Service pour gérer le polling (rafraîchissement périodique)
/// Principe SOLID: Single Responsibility - Uniquement le polling
class PollingService {
  Timer? _timer;
  bool _isPolling = false;

  /// Démarre le polling avec un intervalle donné
  void startPolling({
    required Duration interval,
    required Future<void> Function() onPoll,
    String? name,
  }) {
    if (_isPolling) {
      AppLogger.warning('[PollingService] Polling déjà en cours');
      return;
    }

    _isPolling = true;
    final serviceName = name ?? 'PollingService';

    AppLogger.info('[$serviceName] Démarrage du polling toutes les ${interval.inMilliseconds}ms');

    _timer = Timer.periodic(interval, (timer) async {
      if (_isPolling) {
        try {
          await onPoll();
        } catch (e) {
          // Erreur silencieuse, le prochain poll réessaiera
          AppLogger.error('[$serviceName] Erreur lors du polling', e);
        }
      } else {
        timer.cancel();
      }
    });
  }

  /// Arrête le polling
  void stopPolling() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
      _isPolling = false;
      AppLogger.info('[PollingService] Polling arrêté');
    }
  }

  /// Vérifie si le polling est en cours
  bool get isPolling => _isPolling;

  /// Nettoie les ressources
  void dispose() {
    stopPolling();
  }
}

/// Service de polling optimisé pour le rafraîchissement de session
class SessionPollingService extends PollingService {
  bool _isRefreshing = false;

  /// Démarre le polling de session avec gestion de la concurrence
  void startSessionPolling({
    Duration interval = const Duration(milliseconds: 1000),
    required Future<void> Function() onRefresh,
  }) {
    startPolling(
      interval: interval,
      onPoll: () async {
        // Éviter les appels concurrents
        if (_isRefreshing) return;

        _isRefreshing = true;
        try {
          await onRefresh();
        } finally {
          _isRefreshing = false;
        }
      },
      name: 'SessionPollingService',
    );
  }
}
