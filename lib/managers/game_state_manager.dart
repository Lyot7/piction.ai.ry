import 'dart:async';
import '../interfaces/challenge_api_interface.dart';
import '../models/game_session.dart';
import '../utils/logger.dart';

/// Manager pour la gestion des transitions d'état du jeu
/// Principe SOLID: Single Responsibility - Uniquement les états et transitions
///
/// **Flow simplifié (1 seul cycle, pas d'inversion de rôles):**
/// 1. lobby: Attente de 4 joueurs
/// 2. challenge: Création des 3 challenges par joueur
/// 3. playing/drawing: Les drawers dessinent leurs 3 challenges (1 seule fois)
/// 4. playing/guessing: Les guessers devinent les 3 challenges (1 seule fois)
/// 5. finished: Jeu terminé
///
/// **Phases pendant "playing" (gamePhase):**
/// - drawing: Drawers dessinent (phase unique, pas de répétition)
/// - guessing: Guessers devinent (phase unique, pas de répétition)
///
/// **Note:** Les rôles sont fixes pour toute la partie, pas d'inversion.
/// Migré vers IChallengeApi (SOLID DIP) - n'utilise plus ChallengeManager legacy
class GameStateManager {
  final IChallengeApi _challengeApi;

  // État actuel (lobby, challenge, playing, finished)
  String _currentStatus = 'lobby';
  String get currentStatus => _currentStatus;

  // Phase actuelle pendant "playing" (drawing, guessing)
  String? _currentPhase;
  String? get currentPhase => _currentPhase;

  // Stream pour notifier les changements d'état
  final StreamController<String> _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  // Stream pour notifier les changements de phase
  final StreamController<String?> _phaseController = StreamController<String?>.broadcast();
  Stream<String?> get phaseStream => _phaseController.stream;

  GameStateManager(this._challengeApi);

  /// Met à jour le statut actuel
  void updateStatus(String newStatus) {
    if (_currentStatus != newStatus) {
      AppLogger.info('[GameStateManager] Changement d\'état: $_currentStatus -> $newStatus');
      _currentStatus = newStatus;
      _statusController.add(_currentStatus);
    }
  }

  /// Met à jour la phase actuelle (drawing/guessing)
  void updatePhase(String? newPhase) {
    if (_currentPhase != newPhase) {
      AppLogger.info('[GameStateManager] Changement de phase: $_currentPhase -> $newPhase');
      _currentPhase = newPhase;
      _phaseController.add(_currentPhase);
    }
  }

  /// Vérifie et effectue les transitions automatiques d'état et de phase
  Future<void> checkTransitions(GameSession? currentSession) async {
    if (currentSession == null) {
      AppLogger.warning('[GameStateManager] checkTransitions called with null session');
      return;
    }

    AppLogger.info('[GameStateManager] 🔍 Checking transitions - Status: $_currentStatus -> ${currentSession.status}, Phase: $_currentPhase -> ${currentSession.gamePhase}');

    // Log player challenge status
    final playersReady = currentSession.players.where((p) => p.challengesSent >= 3).length;
    AppLogger.info('[GameStateManager] 🔍 Players ready: $playersReady/${currentSession.players.length}');

    // IMPORTANT: Toujours synchroniser avec le backend
    bool statusChanged = false;
    bool phaseChanged = false;

    // Synchroniser le status
    if (currentSession.status != _currentStatus) {
      AppLogger.info('[GameStateManager] 🎯 Sync status: $_currentStatus -> ${currentSession.status}');
      updateStatus(currentSession.status);
      statusChanged = true;
    }

    // Synchroniser la phase
    if (currentSession.gamePhase != _currentPhase) {
      AppLogger.info('[GameStateManager] 🎯 Sync phase: $_currentPhase -> ${currentSession.gamePhase}');
      updatePhase(currentSession.gamePhase);
      phaseChanged = true;
    }

    // Si sync depuis backend, on s'arrête là (le backend a autorité)
    if (statusChanged || phaseChanged) {
      return;
    }

    // === Transitions locales (backup si le backend n'a pas encore mis à jour) ===

    // 1. challenge → playing (avec phase "drawing")
    if (_currentStatus == 'challenge') {
      if (currentSession.players.every((p) => p.challengesSent >= 3)) {
        AppLogger.info('[GameStateManager] 🎯 All players sent 3 challenges → playing/drawing');
        updateStatus('playing');
        updatePhase('drawing');
        return;
      }
    }

    // 2. Pendant "playing", gérer les transitions de phase
    if (_currentStatus == 'playing') {
      // Vérifier si le temps est écoulé
      final now = DateTime.now();
      final start = currentSession.startTime;
      if (start != null && now.difference(start).inMinutes >= 5) {
        AppLogger.info('[GameStateManager] ⏱️ Timer expired → finished');
        updateStatus('finished');
        updatePhase(null);
        return;
      }

      // Vérifier si tous les challenges sont terminés
      await _checkAllChallengesCompleted(currentSession);

      // Transitions de phase simplifiées (1 cycle unique):
      // drawing → guessing → finished (PAS de retour à drawing)
      if (_currentPhase == 'drawing') {
        // drawing → guessing : Tous les drawers ont fini leurs 3 dessins
        final allDrawersReady = await _checkAllDrawersReady(currentSession);
        if (allDrawersReady) {
          AppLogger.info('[GameStateManager] 🎯 All drawers finished → guessing');
          updatePhase('guessing');
        }
      } else if (_currentPhase == 'guessing') {
        // guessing → finished : Tous les guessers ont fini leurs 3 devinettes
        final allGuessersReady = _checkAllGuessersReady(currentSession);
        if (allGuessersReady) {
          AppLogger.info('[GameStateManager] 🎯 All guessers finished → finished');
          updateStatus('finished');
          updatePhase(null);
        }
      }
    }
  }

  /// Vérifie si tous les drawers ont généré leurs 3 images
  Future<bool> _checkAllDrawersReady(GameSession session) async {
    try {
      // Récupérer tous les challenges de la session via ChallengeManager
      final allChallenges = await _challengeApi.listSessionChallenges(session.id);

      if (allChallenges.isEmpty) {
        AppLogger.warning('[GameStateManager] Aucun challenge trouvé');
        return false;
      }

      // Compter combien de challenges ont une image
      final challengesWithImage = allChallenges.where((c) {
        return c.imageUrl != null && c.imageUrl!.isNotEmpty;
      }).length;

      AppLogger.info('[GameStateManager] 🖼️ Images générées: $challengesWithImage/${allChallenges.length}');

      // Tous les drawers sont prêts si TOUS les challenges ont une image
      final allReady = challengesWithImage == allChallenges.length && allChallenges.isNotEmpty;

      if (allReady) {
        AppLogger.success('[GameStateManager] ✅ Tous les drawers ont généré leurs images ($challengesWithImage/$challengesWithImage)');
      }

      return allReady;
    } catch (e) {
      AppLogger.error('[GameStateManager] Erreur _checkAllDrawersReady', e);
      return false;
    }
  }

  /// Vérifie si tous les guessers ont résolu leurs 3 challenges
  bool _checkAllGuessersReady(GameSession session) {
    // Le backend gère cela via hasGuessed ou challenges.is_resolved
    // Pour l'instant, on laisse le backend gérer la transition
    return false;
  }

  /// Vérifie si tous les challenges sont terminés (async)
  Future<void> _checkAllChallengesCompleted(GameSession currentSession) async {
    if (_currentStatus != 'playing') return;

    try {
      final allChallenges = await _challengeApi.listSessionChallenges(currentSession.id);

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
    _phaseController.close();
  }
}
