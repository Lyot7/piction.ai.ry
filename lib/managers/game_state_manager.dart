import 'dart:async';
import '../models/game_session.dart';
import 'challenge_manager.dart';
import '../utils/logger.dart';

/// Manager pour la gestion des transitions d'état du jeu
/// Principe SOLID: Single Responsibility - Uniquement les états et transitions
/// États: lobby -> challenge -> playing -> finished
class GameStateManager {
  final ChallengeManager _challengeManager;

  // État actuel
  String _currentStatus = 'lobby';
  String get currentStatus => _currentStatus;

  // Stream pour notifier les changements d'état
  final StreamController<String> _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  GameStateManager(this._challengeManager);

  /// Met à jour le statut actuel
  void updateStatus(String newStatus) {
    if (_currentStatus != newStatus) {
      AppLogger.info('[GameStateManager] Changement d\'état: $_currentStatus -> $newStatus');
      _currentStatus = newStatus;
      _statusController.add(_currentStatus);
    }
  }

  /// Vérifie et effectue les transitions automatiques d'état
  Future<void> checkTransitions(GameSession? currentSession) async {
    if (currentSession == null) return;

    if (_currentStatus == 'challenge') {
      // challenge -> playing: Tous les joueurs ont envoyé 3 challenges
      if (currentSession.players.every((p) => p.challengesSent == 3)) {
        updateStatus('playing');
      }
    } else if (_currentStatus == 'playing') {
      // playing -> finished: Timer écoulé ou tous challenges terminés
      final now = DateTime.now();
      final start = currentSession.startTime;

      // Finir si timer >5 min
      if (start != null && now.difference(start).inMinutes >= 5) {
        updateStatus('finished');
        return;
      }

      // Vérifier si tous les challenges sont terminés (async)
      await _checkAllChallengesCompleted(currentSession);
    }
  }

  /// Vérifie si tous les challenges sont terminés (async)
  Future<void> _checkAllChallengesCompleted(GameSession currentSession) async {
    if (_currentStatus != 'playing') return;

    try {
      final allChallenges = await _challengeManager.listSessionChallenges(currentSession.id);

      // Si tous les challenges sont résolus, finir la partie
      if (allChallenges.isNotEmpty && allChallenges.every((c) => c.isCompleted)) {
        updateStatus('finished');
        AppLogger.success('[GameStateManager] Tous les challenges terminés, fin de la partie');
      }
    } catch (e) {
      AppLogger.error('[GameStateManager] Erreur lors de la vérification des challenges', e);
    }
  }

  /// Démarre le jeu (passe en mode "challenge")
  void startGame() {
    updateStatus('challenge');
  }

  /// Vérifie si le jeu est en cours
  bool get isGameActive => ['challenge', 'playing'].contains(_currentStatus);

  /// Vérifie si le jeu est terminé
  bool get isGameFinished => _currentStatus == 'finished';

  /// Réinitialise l'état à lobby
  void resetToLobby() {
    updateStatus('lobby');
  }

  /// Nettoie les ressources
  void dispose() {
    _statusController.close();
  }
}
