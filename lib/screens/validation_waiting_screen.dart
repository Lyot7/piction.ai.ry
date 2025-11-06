import 'package:flutter/material.dart';
import '../services/game_facade.dart';
import '../utils/logger.dart';
import '../widgets/common/game_waiting_screen.dart';
import 'results_screen.dart';

/// Écran d'attente après avoir répondu à tous les challenges (phase guessing)
///
/// Refactorisé pour utiliser GameWaitingScreen (principe DRY)
class ValidationWaitingScreen extends StatelessWidget {
  final GameFacade gameFacade;
  final int scoreTeam1;
  final int scoreTeam2;

  const ValidationWaitingScreen({
    super.key,
    required this.gameFacade,
    required this.scoreTeam1,
    required this.scoreTeam2,
  });

  Future<bool> _checkIfFinished() async {
    try {
      final gameSession = gameFacade.currentGameSession;
      if (gameSession == null) return false;

      await gameFacade.refreshGameSession(gameSession.id);
      final updatedSession = gameFacade.currentGameSession;
      if (updatedSession == null) return false;

      final status = updatedSession.status;
      AppLogger.info('[ValidationWaitingScreen] Status: $status');

      return status == 'finished';
    } catch (e) {
      AppLogger.error('[ValidationWaitingScreen] Erreur vérification status', e);
      return false;
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
      onTransition: () {
        AppLogger.success('[ValidationWaitingScreen] Transition vers résultats');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResultsScreen(
              gameFacade: gameFacade,
              scoreTeam1: scoreTeam1,
              scoreTeam2: scoreTeam2,
            ),
          ),
        );
      },
    );
  }
}
