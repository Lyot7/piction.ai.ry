import 'package:flutter/material.dart';
import '../services/game_facade.dart';
import '../utils/logger.dart';
import '../widgets/common/game_waiting_screen.dart';
import 'results_screen.dart';

/// Écran d'attente après avoir répondu à tous les challenges (phase guessing)
///
/// Refactorisé pour utiliser GameWaitingScreen (principe DRY)
class ValidationWaitingScreen extends StatefulWidget {
  final GameFacade gameFacade;
  final int scoreTeam1;
  final int scoreTeam2;

  const ValidationWaitingScreen({
    super.key,
    required this.gameFacade,
    required this.scoreTeam1,
    required this.scoreTeam2,
  });

  @override
  State<ValidationWaitingScreen> createState() => _ValidationWaitingScreenState();
}

class _ValidationWaitingScreenState extends State<ValidationWaitingScreen> {
  Future<bool> _checkIfFinished() async {
    try {
      final gameSession = widget.gameFacade.currentGameSession;
      if (gameSession == null) return false;

      await widget.gameFacade.refreshGameSession(gameSession.id);
      final updatedSession = widget.gameFacade.currentGameSession;
      if (updatedSession == null) return false;

      final status = updatedSession.status;
      AppLogger.info('[ValidationWaitingScreen] Status: $status');

      return status == 'finished';
    } catch (e) {
      AppLogger.error('[ValidationWaitingScreen] Erreur vérification status', e);
      return false;
    }
  }

  /// Récupère les scores finaux depuis le backend et navigue vers ResultsScreen
  Future<void> _navigateToResults() async {
    AppLogger.success('[ValidationWaitingScreen] Transition vers résultats');

    // ✅ SYNC FINAL SCORES: Récupérer les scores finaux depuis le backend
    int finalRedScore = widget.scoreTeam1;
    int finalBlueScore = widget.scoreTeam2;

    try {
      final gameSession = widget.gameFacade.currentGameSession;
      if (gameSession != null) {
        await widget.gameFacade.refreshGameSession(gameSession.id);
        final finalSession = widget.gameFacade.currentGameSession;
        if (finalSession != null) {
          finalRedScore = finalSession.teamScores['red'] ?? widget.scoreTeam1;
          finalBlueScore = finalSession.teamScores['blue'] ?? widget.scoreTeam2;
          AppLogger.info('[ValidationWaitingScreen] 🏆 Scores finaux backend - Red: $finalRedScore, Blue: $finalBlueScore');
        }
      }
    } catch (e) {
      AppLogger.error('[ValidationWaitingScreen] Erreur récupération scores finaux, utilisation scores passés', e);
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(
            gameFacade: widget.gameFacade,
            scoreTeam1: finalRedScore,
            scoreTeam2: finalBlueScore,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameWaitingScreen(
      title: 'Validation...',
      mainMessage: 'Réponses envoyées !',
      secondaryMessage: 'En attente des autres joueurs...',
      icon: Icons.check_circle,
      accentColor: Colors.green,
      cardMessage: 'Validation des résultats',
      cardSubMessage: 'Nous attendons que tous les joueurs terminent leurs challenges',
      transitionCondition: _checkIfFinished,
      onTransition: _navigateToResults,
    );
  }
}
