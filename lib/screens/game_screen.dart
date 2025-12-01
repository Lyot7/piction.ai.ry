import 'dart:async';
import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import '../models/challenge.dart' as models;
import '../services/game_facade.dart';
import '../services/stable_diffusion_service.dart';
import '../services/image_generation_service.dart';
import '../utils/logger.dart';
import '../widgets/game/drawer_view.dart';
import '../widgets/game/guesser_view.dart';
import 'results_screen.dart';
import 'drawing_waiting_screen.dart';
import 'validation_waiting_screen.dart';

/// Écran de jeu principal avec gestion des rôles drawer/guesser
class GameScreen extends StatefulWidget {
  final GameFacade gameFacade;

  const GameScreen({super.key, required this.gameFacade});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Durée des timers par phase
  static const int drawingPhaseSeconds = 5 * 60; // 5 minutes pour dessiner
  static const int guessingPhaseSeconds = 2 * 60; // 2 minutes pour deviner
  Timer? _timer;
  Timer? _refreshTimer;
  int _remaining = drawingPhaseSeconds;

  // État du jeu
  List<models.Challenge> _challenges = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isAutoGenerating = false;

  // ✅ Tracker la phase actuelle de l'écran pour éviter les boucles de navigation
  String _currentScreenPhase = 'drawing'; // 'drawing' ou 'guessing'

  // Scores par équipe
  int _redTeamScore = 100;
  int _blueTeamScore = 100;

  // Suivi des challenges résolus (pour la phase guessing)
  final Set<String> _resolvedChallengeIds = {};

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeGame() async {
    try {
      setState(() => _isLoading = true);

      // Déterminer la phase de jeu
      final gameSession = widget.gameFacade.currentGameSession;
      final gamePhase = gameSession?.gamePhase;
      final status = gameSession?.status;

      // ✅ FIX: Vérifier status ET gamePhase pour détecter la phase correcte
      final isGuessingPhase = gamePhase == 'guessing' || status == 'guessing';

      // ✅ Définir la phase actuelle de l'écran
      _currentScreenPhase = isGuessingPhase ? 'guessing' : 'drawing';

      // ✅ SYNC SCORES: Initialiser les scores depuis la session backend
      _syncScoresFromSession(gameSession);

      AppLogger.info('[GameScreen] Phase initiale - gamePhase: $gamePhase, status: $status, screenPhase: $_currentScreenPhase');

      // Récupérer les challenges en fonction de la phase
      // Phase DRAWING: TOUS les joueurs dessinent leurs 3 challenges
      // Phase GUESSING: TOUS les joueurs devinent les dessins de leur coéquipier
      if (_currentScreenPhase == 'drawing') {
        // ✅ TOUS les joueurs (peu importe le rôle) dessinent leurs 3 challenges
        await widget.gameFacade.refreshMyChallenges();
        _challenges = widget.gameFacade.myChallenges;
      } else {
        // ✅ TOUS les joueurs (peu importe le rôle) devinent les dessins de leur coéquipier
        await widget.gameFacade.refreshChallengesToGuess();
        _challenges = widget.gameFacade.challengesToGuess;
      }

      AppLogger.info('[GameScreen] ${_challenges.length} challenges chargés');

      // ✅ Définir la durée du timer selon la phase
      _remaining = _currentScreenPhase == 'guessing'
          ? guessingPhaseSeconds
          : drawingPhaseSeconds;
      AppLogger.info('[GameScreen] Timer initialisé: ${_remaining ~/ 60} minutes pour phase $_currentScreenPhase');

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });

      _startTimer();
    } catch (e) {
      AppLogger.error('[GameScreen] Erreur initialisation', e);
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        timer.cancel();
        _endGame();
      } else {
        setState(() {
          _remaining--;
        });
      }
    });

    // Démarrer aussi le timer de rafraîchissement des challenges (toutes les 3 secondes)
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _refreshChallenges();
    });
  }

  Future<void> _refreshChallenges() async {
    try {
      final gameSession = widget.gameFacade.currentGameSession;
      if (gameSession == null) return;

      // Rafraîchir la session pour avoir la phase à jour
      await widget.gameFacade.refreshGameSession(gameSession.id);
      final updatedSession = widget.gameFacade.currentGameSession;
      if (updatedSession == null) return;

      // ✅ SYNC SCORES: Synchroniser les scores depuis le backend après refresh
      _syncScoresFromSession(updatedSession);

      final gamePhase = updatedSession.gamePhase;
      final status = updatedSession.status;

      // ✅ FIX: Vérifier status ET gamePhase pour détecter le changement de phase
      final isGuessingPhase = gamePhase == 'guessing' || status == 'guessing';

      // ✅ CRITIQUE: Ne naviguer que si on ÉTAIT en drawing et qu'on PASSE à guessing
      final shouldNavigate = _currentScreenPhase == 'drawing' && isGuessingPhase;

      if (_currentScreenPhase == 'drawing' && !isGuessingPhase) {
        // Mode drawing : refresh des challenges
        await widget.gameFacade.refreshMyChallenges();
        if (mounted) {
          setState(() {
            _challenges = widget.gameFacade.myChallenges;
            // Log pour debug: afficher les imageUrl des challenges récupérés
            for (var challenge in _challenges) {
              AppLogger.info('[GameScreen] Challenge ${challenge.id} - imageUrl: ${challenge.imageUrl}');
            }
          });
        }
      } else if (shouldNavigate) {
        // ✅ TRANSITION: Drawing → Guessing, naviguer vers DrawingWaitingScreen
        AppLogger.warning('[GameScreen] ⚠️ TRANSITION détectée: drawing → guessing (gamePhase=$gamePhase, status=$status)');
        _refreshTimer?.cancel();
        _timer?.cancel();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Transition vers phase devinette...'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.orange,
            ),
          );

          await Future.delayed(const Duration(seconds: 2));

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DrawingWaitingScreen(
                  gameFacade: widget.gameFacade,
                ),
              ),
            );
          }
        }
        return;
      } else if (_currentScreenPhase == 'guessing') {
        // ✅ Déjà en mode guessing, ne rien faire (pas de navigation en boucle)
        AppLogger.info('[GameScreen] Déjà en mode guessing, polling continue sans navigation');
      }
    } catch (e) {
      AppLogger.error('[GameScreen] Erreur rafraîchissement challenges', e);
      // ✅ Si erreur liée au changement de phase ET qu'on était en drawing, naviguer
      if (e.toString().contains('not in the drawing phase') && _currentScreenPhase == 'drawing') {
        AppLogger.warning('[GameScreen] ⚠️ TRANSITION détectée via erreur: drawing → guessing');
        _refreshTimer?.cancel();
        _timer?.cancel();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DrawingWaitingScreen(
                gameFacade: widget.gameFacade,
              ),
            ),
          );
        }
      }
    }
  }

  /// Vérifie si la phase a changé vers "guessing" et navigue si nécessaire
  Future<void> _checkAndHandlePhaseTransition() async {
    try {
      final gameSession = widget.gameFacade.currentGameSession;
      if (gameSession == null) return;

      // Refresh de la session pour avoir la phase à jour
      await widget.gameFacade.refreshGameSession(gameSession.id);
      final updatedSession = widget.gameFacade.currentGameSession;
      if (updatedSession == null) return;

      final gamePhase = updatedSession.gamePhase;
      final status = updatedSession.status;

      // ✅ FIX: Vérifier status ET gamePhase pour détecter le changement de phase
      final isGuessingPhase = gamePhase == 'guessing' || status == 'guessing';

      // ✅ CRITIQUE: Ne naviguer que si on ÉTAIT en drawing et qu'on PASSE à guessing
      final shouldNavigate = _currentScreenPhase == 'drawing' && isGuessingPhase;

      AppLogger.info('[GameScreen] Phase après génération - gamePhase: $gamePhase, status: $status, screenPhase: $_currentScreenPhase, shouldNavigate: $shouldNavigate');

      // Si transition drawing → guessing détectée
      if (shouldNavigate) {
        AppLogger.warning('[GameScreen] ⚠️ TRANSITION détectée: drawing → guessing, navigation automatique');

        // Arrêter les timers
        _timer?.cancel();
        _refreshTimer?.cancel();

        if (mounted) {
          // Message utilisateur
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Tous les joueurs ont terminé. Transition automatique...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );

          // Attendre 2 secondes pour que le message soit visible
          await Future.delayed(const Duration(seconds: 2));

          // Navigation vers DrawingWaitingScreen
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DrawingWaitingScreen(
                  gameFacade: widget.gameFacade,
                ),
              ),
            );
          }
        }
      } else if (_currentScreenPhase == 'guessing') {
        // ✅ Déjà en mode guessing, pas de navigation nécessaire
        AppLogger.info('[GameScreen] Déjà en mode guessing après génération, pas de navigation');
      } else {
        // ✅ Toujours en mode drawing
        AppLogger.info('[GameScreen] Toujours en mode drawing après génération, phase n\'a pas changé');
      }
    } catch (e) {
      AppLogger.error('[GameScreen] Erreur vérification phase', e);
    }
  }

  void _endGame() async {
    // IMPORTANT: Arrêter les timers avant de naviguer
    _timer?.cancel();
    _refreshTimer?.cancel();
    AppLogger.info('[GameScreen] Timers arrêtés avant fin de jeu');

    // ✅ SYNC FINAL SCORES: Récupérer les scores finaux depuis le backend
    try {
      final gameSession = widget.gameFacade.currentGameSession;
      if (gameSession != null) {
        await widget.gameFacade.refreshGameSession(gameSession.id);
        final finalSession = widget.gameFacade.currentGameSession;
        if (finalSession != null) {
          // Utiliser les scores de la session backend (source de vérité)
          final finalRedScore = finalSession.teamScores['red'] ?? _redTeamScore;
          final finalBlueScore = finalSession.teamScores['blue'] ?? _blueTeamScore;

          AppLogger.info('[GameScreen] 🏆 Scores finaux - Backend Red: $finalRedScore, Blue: $finalBlueScore | Local Red: $_redTeamScore, Blue: $_blueTeamScore');

          // Naviguer avec les scores du backend
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => ResultsScreen(
                  gameFacade: widget.gameFacade,
                  scoreTeam1: finalRedScore,
                  scoreTeam2: finalBlueScore,
                ),
                transitionDuration: const Duration(milliseconds: 150),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          }
          return;
        }
      }
    } catch (e) {
      AppLogger.error('[GameScreen] Erreur récupération scores finaux, utilisation scores locaux', e);
    }

    // Fallback: utiliser les scores locaux si le backend échoue
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => ResultsScreen(
            gameFacade: widget.gameFacade,
            scoreTeam1: _redTeamScore,
            scoreTeam2: _blueTeamScore,
          ),
          transitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  /// Récupère la couleur d'équipe du joueur actuel depuis la session de jeu
  ///
  /// Retourne la couleur depuis la liste des joueurs de la session (source fiable)
  /// car currentPlayer peut ne pas avoir la couleur mise à jour
  String? _getCurrentPlayerTeamColor() {
    final currentPlayer = widget.gameFacade.currentPlayer;
    final gameSession = widget.gameFacade.currentGameSession;

    if (currentPlayer == null || gameSession == null) {
      AppLogger.warning('[GameScreen] _getCurrentPlayerTeamColor: player ou session null');
      return null;
    }

    // Chercher le joueur dans la session pour avoir la couleur à jour
    final playerInSession = gameSession.players
        .where((p) => p.id == currentPlayer.id)
        .firstOrNull;

    if (playerInSession != null) {
      AppLogger.info('[GameScreen] 🎨 Couleur depuis session: ${playerInSession.color} (joueur: ${playerInSession.name})');
      return playerInSession.color;
    }

    // Fallback sur currentPlayer.color si pas trouvé dans la session
    AppLogger.warning('[GameScreen] 🎨 Joueur non trouvé dans session, fallback sur currentPlayer.color: ${currentPlayer.color}');
    return currentPlayer.color;
  }

  /// Applique un delta de score à une équipe spécifique
  ///
  /// [delta] : points à ajouter (négatif pour retirer)
  /// [teamColor] : 'red' ou 'blue' - si null, utilise la couleur du joueur actuel
  void _applyScoreDelta(int delta, {String? teamColor}) {
    // Déterminer l'équipe à impacter (utilise teamColor fourni ou récupère depuis la session)
    final String? targetTeam = teamColor ?? _getCurrentPlayerTeamColor();

    // ✅ VALIDATION: S'assurer que targetTeam est valide
    if (targetTeam == null) {
      AppLogger.error('[GameScreen] _applyScoreDelta: impossible de déterminer l\'équipe, delta $delta ignoré');
      return;
    }

    if (targetTeam != 'red' && targetTeam != 'blue') {
      AppLogger.error('[GameScreen] _applyScoreDelta: couleur invalide "$targetTeam", delta $delta ignoré');
      return;
    }

    AppLogger.info('[GameScreen] 💰 Score delta: $delta pour équipe $targetTeam');

    setState(() {
      if (targetTeam == 'red') {
        _redTeamScore += delta;
        if (_redTeamScore < 0) _redTeamScore = 0;
        AppLogger.info('[GameScreen] 💰 Score RED: $_redTeamScore');
      } else if (targetTeam == 'blue') {
        _blueTeamScore += delta;
        if (_blueTeamScore < 0) _blueTeamScore = 0;
        AppLogger.info('[GameScreen] 💰 Score BLUE: $_blueTeamScore');
      }
    });
  }

  /// Synchronise les scores locaux depuis la session backend
  ///
  /// Utilise session.teamScores si disponible (priorité backend),
  /// sinon conserve les scores locaux (fallback)
  void _syncScoresFromSession(dynamic gameSession) {
    if (gameSession == null) return;

    final sessionRedScore = gameSession.teamScores['red'] as int?;
    final sessionBlueScore = gameSession.teamScores['blue'] as int?;

    // Si le backend envoie des scores (différents de 100/100 par défaut ou après des actions),
    // synchroniser avec les valeurs backend
    if (sessionRedScore != null && sessionBlueScore != null) {
      // Vérifier si les scores backend ont changé (différent des valeurs par défaut initiales)
      final hasBackendScores = sessionRedScore != 100 || sessionBlueScore != 100;

      if (hasBackendScores) {
        setState(() {
          _redTeamScore = sessionRedScore;
          _blueTeamScore = sessionBlueScore;
        });
        AppLogger.info('[GameScreen] ✅ Scores synchronisés depuis backend - Red: $sessionRedScore, Blue: $sessionBlueScore');
      } else {
        AppLogger.info('[GameScreen] Scores backend par défaut (100/100), conservation des scores locaux - Red: $_redTeamScore, Blue: $_blueTeamScore');
      }
    }
  }

  void _onChallengeResolved(String challengeId) async {
    setState(() {
      _resolvedChallengeIds.add(challengeId);
    });

    // Vérifier si tous les challenges sont résolus
    if (_resolvedChallengeIds.length == _challenges.length && _challenges.isNotEmpty) {
      AppLogger.success('[GameScreen] Tous les challenges résolus ! Navigation vers validation...');

      // IMPORTANT: Arrêter les timers avant de naviguer
      _timer?.cancel();
      _refreshTimer?.cancel();
      AppLogger.info('[GameScreen] Timers arrêtés avant navigation vers validation');

      // ✅ SYNC SCORES: Récupérer les scores finaux depuis le backend
      int finalRedScore = _redTeamScore;
      int finalBlueScore = _blueTeamScore;

      try {
        final gameSession = widget.gameFacade.currentGameSession;
        if (gameSession != null) {
          await widget.gameFacade.refreshGameSession(gameSession.id);
          final updatedSession = widget.gameFacade.currentGameSession;
          if (updatedSession != null) {
            finalRedScore = updatedSession.teamScores['red'] ?? _redTeamScore;
            finalBlueScore = updatedSession.teamScores['blue'] ?? _blueTeamScore;
            AppLogger.info('[GameScreen] 📊 Scores avant validation - Backend Red: $finalRedScore, Blue: $finalBlueScore');
          }
        }
      } catch (e) {
        AppLogger.error('[GameScreen] Erreur sync scores avant validation, utilisation scores locaux', e);
      }

      // Naviguer vers l'écran de validation avec les scores backend
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ValidationWaitingScreen(
              gameFacade: widget.gameFacade,
              scoreTeam1: finalRedScore,
              scoreTeam2: finalBlueScore,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chargement...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text(
                'Erreur de chargement',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.errorColor),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ FIX CRITIQUE: Utiliser _currentScreenPhase au lieu de gamePhase du backend
    // Le backend peut retourner gamePhase=null, ce qui causerait un affichage incorrect
    final gamePhase = _currentScreenPhase;

    // Si pas de challenges, afficher un message d'attente
    if (_challenges.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Phase: ${gamePhase == 'drawing' ? 'Dessination' : 'Devination'}',
          ),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeaderWithoutChallenge(),
                const SizedBox(height: 32),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          gamePhase == 'drawing' ? Icons.brush : Icons.search,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          gamePhase == 'drawing'
                              ? 'En attente...\nVotre coéquipier dessine les challenges'
                              : 'En attente...\nVotre coéquipier devine les challenges',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Déterminer le titre en fonction de la phase
    String title = gamePhase == 'drawing'
        ? 'Phase Dessination'
        : 'Phase Devination';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              // Bouton auto-fill en mode drawing
              if (gamePhase == 'drawing') ...[
                _buildAutoFillButton(),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: ListView.separated(
                  itemCount: _challenges.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final challenge = _challenges[index];
                    final gameSession = widget.gameFacade.currentGameSession;
                    final gameSessionId = gameSession?.id ?? '';
                    // ✅ FIX: Utiliser _getCurrentPlayerTeamColor() pour obtenir
                    // la couleur depuis la session (pas depuis currentPlayer qui peut être null)
                    final teamColor = _getCurrentPlayerTeamColor();

                    // Afficher DrawerView ou GuesserView selon la phase
                    if (gamePhase == 'drawing') {
                      return _ChallengeCard(
                        key: ValueKey('challenge_card_${challenge.id}'),
                        index: index,
                        totalChallenges: _challenges.length,
                        child: DrawerView(
                          key: ValueKey('drawer_${challenge.id}'),
                          challenge: challenge,
                          gameSessionId: gameSessionId,
                          onImageGenerated: () => setState(() {}),
                          onScoreDelta: _applyScoreDelta,
                          drawerTeamColor: teamColor,
                        ),
                      );
                    } else {
                      return _ChallengeCard(
                        key: ValueKey('challenge_card_${challenge.id}'),
                        index: index,
                        totalChallenges: _challenges.length,
                        child: GuesserView(
                          key: ValueKey('guesser_${challenge.id}'),
                          challenge: challenge,
                          gameSessionId: gameSessionId,
                          onSubmitAnswer: widget.gameFacade.answerChallenge,
                          onScoreDelta: _applyScoreDelta,
                          onChallengeResolved: _onChallengeResolved,
                          isResolved: _resolvedChallengeIds.contains(challenge.id),
                          guesserTeamColor: teamColor,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: gamePhase == 'drawing'
          ? _buildSendAllButton()
          : null,
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _buildTimerChip(),
        const SizedBox(width: 8),
        _buildScoreChip('Rouge', _redTeamScore, AppTheme.teamRedColor),
        const SizedBox(width: 8),
        _buildScoreChip('Bleue', _blueTeamScore, AppTheme.teamBlueColor),
      ],
    );
  }

  Widget _buildHeaderWithoutChallenge() {
    return Row(
      children: [
        _buildTimerChip(),
        const SizedBox(width: 8),
        _buildScoreChip('Rouge', _redTeamScore, AppTheme.teamRedColor),
        const SizedBox(width: 8),
        _buildScoreChip('Bleue', _blueTeamScore, AppTheme.teamBlueColor),
      ],
    );
  }

  Widget _buildTimerChip() {
    final minutes = (_remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    return Chip(
      avatar: const Icon(Icons.timer, size: 18),
      label: Text('$minutes:$seconds'),
      backgroundColor: AppTheme.backgroundColor,
    );
  }

  Widget _buildScoreChip(String label, int score, Color color) {
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 8),
      label: Text('$score pts'),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }

  Widget _buildAutoFillButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isAutoGenerating ? null : _autoFillAndGenerateAll,
        icon: _isAutoGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(
          _isAutoGenerating
              ? 'Génération automatique en cours...'
              : 'Remplir et générer automatiquement',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }

  String _generateAutoPrompt(models.Challenge challenge) {
    // Créer un prompt simple en anglais pour l'IA
    // Format générique qui évite les mots interdits et les mots à deviner
    return 'A simple illustration showing the concept, digital art style, clean background';
  }

  Future<void> _autoFillAndGenerateAll() async {
    setState(() => _isAutoGenerating = true);

    try {
      final gameSession = widget.gameFacade.currentGameSession;
      if (gameSession == null) {
        throw Exception('Aucune session de jeu active');
      }

      // ✅ Copie locale pour travailler uniquement en local
      final localChallenges = List<models.Challenge>.from(_challenges);
      final challengesToGenerate = localChallenges.where(
        (c) => c.imageUrl == null || c.imageUrl!.isEmpty
      ).toList();

      if (challengesToGenerate.isEmpty) {
        AppLogger.info('[GameScreen] Toutes les images déjà générées');
        setState(() => _isAutoGenerating = false);
        return;
      }

      AppLogger.info('[GameScreen] Génération de ${challengesToGenerate.length} images avec ImageGenerationService');

      // Utiliser ImageGenerationService qui RETOURNE les URLs générées
      final imageService = ImageGenerationService(
        isPhaseValid: () async {
          await widget.gameFacade.refreshGameSession(gameSession.id);
          final phase = widget.gameFacade.currentGameSession?.gamePhase ?? 'drawing';
          return phase == 'drawing';
        },
        onProgress: (current, total) {
          AppLogger.info('[GameScreen] Progression: $current/$total');
        },
        // ✅ IMPORTANT: L'imageGenerator doit retourner l'URL
        imageGenerator: (prompt, sessionId, challengeId) async {
          return await StableDiffusionService.generateImageWithRetry(
            prompt,
            sessionId,
            challengeId,
          );
        },
      );

      // Générer toutes les images
      final result = await imageService.generateImagesForChallenges(
        challenges: challengesToGenerate,
        gameSessionId: gameSession.id,
        promptGenerator: _generateAutoPrompt,
      );

      AppLogger.success('[GameScreen] Génération terminée: ${result.successCount}/${result.totalCount}');

      // ✅ CRITIQUE: Mettre à jour l'état LOCAL avec les URLs retournées
      // PAS de refresh backend - on garde 100% local jusqu'à validation
      final updatedChallenges = localChallenges.map((challenge) {
        final generatedUrl = result.generatedUrls[challenge.id];
        if (generatedUrl != null && generatedUrl.isNotEmpty) {
          AppLogger.info('[GameScreen] ✅ Challenge ${challenge.id} mis à jour avec URL: $generatedUrl');
          return challenge.copyWith(imageUrl: generatedUrl);
        }
        return challenge;
      }).toList();

      setState(() {
        _challenges = updatedChallenges;
        _isAutoGenerating = false;
      });

      AppLogger.success('[GameScreen] ✅ État local mis à jour, ${result.generatedUrls.length} URLs capturées');

      // ✅ NOUVEAU: Vérifier immédiatement si la phase a changé
      await _checkAndHandlePhaseTransition();

      // Notification utilisateur
      if (mounted) {
        final imagesWithUrl = _challenges.where(
          (c) => c.imageUrl != null && c.imageUrl!.isNotEmpty
        ).length;

        if (result.phaseClosed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${result.successCount}/${result.totalCount} images générées. Phase changée.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (result.isComplete && imagesWithUrl == _challenges.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Toutes vos images sont prêtes !'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else if (result.hasPartialSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$imagesWithUrl/${_challenges.length} images disponibles'),
              backgroundColor: Colors.orange,
            ),
          );
        } else if (result.hasErrors) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${result.errorMessage}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('[GameScreen] Erreur auto-génération', e);

      setState(() => _isAutoGenerating = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'auto-génération: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildSendAllButton() {
    // Vérifier si tous les challenges ont une image générée
    final allImagesReady = _challenges.every(
      (challenge) =>
          challenge.imageUrl != null && challenge.imageUrl!.isNotEmpty,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: allImagesReady ? _sendAllToGuessers : null,
          icon: const Icon(Icons.send),
          label: Text(
            allImagesReady ? 'Envoyer les images' : 'Générez toutes les images',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendAllToGuessers() async {
    AppLogger.success('[GameScreen] Envoi de tous les dessins aux devineurs');

    // IMPORTANT: Arrêter les timers avant de naviguer pour éviter les erreurs
    _timer?.cancel();
    _refreshTimer?.cancel();
    AppLogger.info('[GameScreen] Timers arrêtés avant navigation');

    // Naviguer vers l'écran d'attente
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DrawingWaitingScreen(
          gameFacade: widget.gameFacade,
        ),
      ),
    );

    // Ici, le backend gère automatiquement la transition vers la phase guessing
    // Pas besoin d'action supplémentaire, le polling va détecter le changement
  }
}

/// Card wrapper pour chaque challenge avec numéro
class _ChallengeCard extends StatelessWidget {
  final int index;
  final int totalChallenges;
  final Widget child;

  const _ChallengeCard({
    super.key,
    required this.index,
    required this.totalChallenges,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec numéro du challenge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Challenge ${index + 1}/$totalChallenges',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Contenu du challenge
            child,
          ],
        ),
      ),
    );
  }
}
