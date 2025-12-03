import 'dart:async';
import 'package:flutter/material.dart';
import '../di/locator.dart';
import '../interfaces/facades/challenge_facade_interface.dart';
import '../interfaces/facades/session_facade_interface.dart';
import '../themes/app_theme.dart';
import '../utils/logger.dart';
import '../widgets/common/game_waiting_screen.dart';
import '../widgets/common/waiting_players_card.dart';
import '../models/player.dart';
import 'game_screen.dart';

/// Écran d'attente après l'envoi des images (phase drawing)
/// Migré vers Locator (SOLID DIP) - n'utilise plus GameFacade prop drilling
///
/// Affiche le statut de tous les joueurs et leur progression
class DrawingWaitingScreen extends StatefulWidget {
  const DrawingWaitingScreen({super.key});

  @override
  State<DrawingWaitingScreen> createState() => _DrawingWaitingScreenState();
}

class _DrawingWaitingScreenState extends State<DrawingWaitingScreen> {
  List<Player> _players = [];
  int _totalImages = 0;
  int _totalChallenges = 0;
  Timer? _refreshTimer;

  ISessionFacade get _sessionFacade => Locator.get<ISessionFacade>();
  IChallengeFacade get _challengeFacade => Locator.get<IChallengeFacade>();

  @override
  void initState() {
    super.initState();
    _loadPlayersStatus();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        _loadPlayersStatus();
      }
    });
  }

  Future<void> _loadPlayersStatus() async {
    try {
      final gameSession = _sessionFacade.currentGameSession;
      if (gameSession == null) return;

      // Refresh session pour avoir les données à jour
      await _sessionFacade.refreshGameSession(gameSession.id);
      final updatedSession = _sessionFacade.currentGameSession;
      if (updatedSession == null) return;

      // Récupérer tous les challenges
      final allChallenges = await _challengeFacade.listSessionChallenges(updatedSession.id);

      // Compter les images globalement
      final imagesCount = allChallenges.where((c) => c.imageUrl != null && c.imageUrl!.isNotEmpty).length;

      if (mounted) {
        setState(() {
          _players = updatedSession.players;
          _totalImages = imagesCount;
          _totalChallenges = allChallenges.length;
        });
      }
    } catch (e) {
      AppLogger.error('[DrawingWaitingScreen] Erreur chargement statut', e);
    }
  }

  Future<bool> _checkIfGuessingPhase() async {
    try {
      final gameSession = _sessionFacade.currentGameSession;
      if (gameSession == null) return false;

      await _sessionFacade.refreshGameSession(gameSession.id);
      final updatedSession = _sessionFacade.currentGameSession;
      if (updatedSession == null) return false;

      final gamePhase = updatedSession.gamePhase;
      final status = updatedSession.status;
      AppLogger.info('[DrawingWaitingScreen] Status: $status, Phase: $gamePhase, Images: $_totalImages/$_totalChallenges');

      // Transition si gamePhase = 'guessing' OU status = 'guessing'
      // FIX: Le backend retourne status='guessing' mais gamePhase peut être null
      if (gamePhase == 'guessing' || status == 'guessing') {
        AppLogger.success('[DrawingWaitingScreen] Phase guessing détectée (gamePhase=$gamePhase, status=$status)');
        return true;
      }

      // Backup: vérifier si toutes les images sont générées
      if ((status == 'playing' || status == 'drawing') && _totalChallenges > 0) {
        final allReady = _totalImages == _totalChallenges;

        if (allReady) {
          AppLogger.success('[DrawingWaitingScreen] Toutes les images prêtes ($_totalImages/$_totalChallenges), transition');
          return true;
        }
      }

      return false;
    } catch (e) {
      AppLogger.error('[DrawingWaitingScreen] Erreur vérification phase', e);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameWaitingScreen(
      title: 'En attente...',
      mainMessage: 'Images envoyées !',
      secondaryMessage: 'En attente des autres joueurs...',
      icon: Icons.send,
      accentColor: AppTheme.primaryColor,
      cardMessage: _totalChallenges > 0
          ? '$_totalImages/$_totalChallenges images générées'
          : 'Chargement...',
      cardSubMessage: _totalImages == _totalChallenges
          ? 'Tous les joueurs sont prêts !'
          : 'Attendez que tous les joueurs génèrent leurs images',
      playersCard: _players.isNotEmpty && _totalChallenges > 0
          ? WaitingPlayersCard(
              players: _players,
              getPlayerStatus: (player) {
                // Approximation: un joueur est prêt si au moins 3×(nb joueurs prêts) images sont générées
                // Car on ne peut pas mapper facilement challengerId (int) vers Player.id (String)
                final imagesPerPlayer = _totalChallenges ~/ _players.length;
                final minImagesExpected = imagesPerPlayer * 3;
                return _totalImages >= minImagesExpected ? 1 : 0;
              },
              readyLabel: 'Prêt',
              waitingLabel: 'En attente',
            )
          : null,
      transitionCondition: _checkIfGuessingPhase,
      onTransition: () {
        _refreshTimer?.cancel();
        AppLogger.success('[DrawingWaitingScreen] Transition vers phase guessing');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const GameScreen(),
          ),
        );
      },
    );
  }
}
