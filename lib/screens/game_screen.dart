import 'dart:async';
import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import '../models/challenge.dart' as models;
import '../di/locator.dart';
import '../interfaces/facades/auth_facade_interface.dart';
import '../interfaces/facades/challenge_facade_interface.dart';
import '../interfaces/image_api_interface.dart';
import '../services/image_generation_service.dart';
import '../utils/logger.dart';
import '../viewmodels/game_view_model.dart';
import '../viewmodels/viewmodel_factory.dart';
import '../widgets/game/drawer_view.dart';
import '../widgets/game/guesser_view.dart';
import 'results_screen.dart';
import 'drawing_waiting_screen.dart';
import 'validation_waiting_screen.dart';

/// Écran de jeu principal avec gestion des rôles drawer/guesser (SOLID)
/// Utilise GameViewModel pour séparer la logique métier de l'UI (SRP)
/// Migré vers Locator (DIP) - n'utilise plus GameFacade prop drilling
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameViewModel _viewModel;
  bool _isAutoGenerating = false;

  IAuthFacade get _authFacade => Locator.get<IAuthFacade>();
  IChallengeFacade get _challengeFacade => Locator.get<IChallengeFacade>();

  @override
  void initState() {
    super.initState();
    _viewModel = ViewModelFactory.createGameViewModel();
    _initializeGame();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _initializeGame() async {
    await _viewModel.initializeGame();
    if (mounted && !_viewModel.isLoading) {
      _startTimers();
    }
  }

  void _startTimers() {
    _viewModel.startTimer(onTimerEnd: _endGame);
    _viewModel.startRefreshTimer(onRefresh: _refreshChallenges);
  }

  Future<void> _refreshChallenges() async {
    final shouldTransition = await _viewModel.refreshChallenges();
    if (shouldTransition && mounted) {
      _navigateToDrawingWaiting();
    }
  }

  void _endGame() {
    _viewModel.stopTimers();

    final session = _viewModel.currentGameSession;
    final finalRedScore = session?.teamScores['red'] ?? _viewModel.redTeamScore;
    final finalBlueScore = session?.teamScores['blue'] ?? _viewModel.blueTeamScore;

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => ResultsScreen(
            initialScoreTeam1: finalRedScore,
            initialScoreTeam2: finalBlueScore,
          ),
          transitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  void _navigateToDrawingWaiting() {
    _viewModel.stopTimers();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Transition vers phase devinette...'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const DrawingWaitingScreen(),
            ),
          );
        }
      });
    }
  }

  String? _getCurrentPlayerTeamColor() {
    final currentPlayer = _authFacade.currentPlayer;
    final gameSession = _viewModel.currentGameSession;

    if (currentPlayer == null || gameSession == null) return null;

    final playerInSession = gameSession.players
        .where((p) => p.id == currentPlayer.id)
        .firstOrNull;

    return playerInSession?.color ?? currentPlayer.color;
  }

  void _applyScoreDelta(int delta, {String? teamColor}) {
    final targetTeam = teamColor ?? _getCurrentPlayerTeamColor();
    if (targetTeam == null || (targetTeam != 'red' && targetTeam != 'blue')) {
      return;
    }
    _viewModel.applyScoreDelta(targetTeam, delta);
  }

  void _onChallengeResolved(String challengeId) {
    _viewModel.markChallengeResolved(challengeId);

    if (_viewModel.allChallengesResolved) {
      AppLogger.success('[GameScreen] Tous les challenges résolus !');
      _viewModel.stopTimers();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ValidationWaitingScreen(
              scoreTeam1: _viewModel.redTeamScore,
              scoreTeam2: _viewModel.blueTeamScore,
            ),
          ),
        );
      }
    }
  }

  String _generateAutoPrompt(models.Challenge challenge) {
    return 'A simple illustration showing the concept, digital art style, clean background';
  }

  Future<void> _autoFillAndGenerateAll() async {
    setState(() => _isAutoGenerating = true);
    _viewModel.setAutoGenerating(true);

    try {
      final gameSession = _viewModel.currentGameSession;
      if (gameSession == null) {
        throw Exception('Aucune session de jeu active');
      }

      final challenges = _viewModel.challenges;
      final challengesToGenerate = challenges.where(
        (c) => c.imageUrl == null || c.imageUrl!.isEmpty
      ).toList();

      if (challengesToGenerate.isEmpty) {
        AppLogger.info('[GameScreen] Toutes les images déjà générées');
        return;
      }

      final imageApi = Locator.get<IImageApi>();
      final imageService = ImageGenerationService(
        isPhaseValid: () async {
          await _viewModel.refreshChallenges();
          return _viewModel.currentScreenPhase == 'drawing';
        },
        onProgress: (current, total) {
          AppLogger.info('[GameScreen] Progression: $current/$total');
        },
        imageGenerator: (prompt, sessionId, challengeId) async {
          return await imageApi.generateImageWithRetry(
            sessionId,
            challengeId,
            prompt,
          );
        },
      );

      final result = await imageService.generateImagesForChallenges(
        challenges: challengesToGenerate,
        gameSessionId: gameSession.id,
        promptGenerator: _generateAutoPrompt,
      );

      AppLogger.success('[GameScreen] Génération terminée: ${result.successCount}/${result.totalCount}');

      if (mounted) {
        _showGenerationResult(result);
      }
    } catch (e) {
      AppLogger.error('[GameScreen] Erreur auto-génération', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAutoGenerating = false);
        _viewModel.setAutoGenerating(false);
      }
    }
  }

  void _showGenerationResult(ImageGenerationResult result) {
    if (result.phaseClosed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.successCount}/${result.totalCount} images générées. Phase changée.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else if (result.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Toutes vos images sont prêtes !'),
          backgroundColor: Colors.green,
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

  Future<void> _sendAllToGuessers() async {
    _viewModel.stopTimers();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const DrawingWaitingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        if (_viewModel.isLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chargement...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (_viewModel.errorMessage != null) {
          return _buildErrorScreen();
        }

        return _buildGameScreen();
      },
    );
  }

  Widget _buildErrorScreen() {
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
                _viewModel.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    final challenges = _viewModel.challenges;
    final gamePhase = _viewModel.currentScreenPhase;

    if (challenges.isEmpty) {
      return _buildWaitingScreen(gamePhase);
    }

    final title = gamePhase == 'drawing' ? 'Phase Dessination' : 'Phase Devination';

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
              if (gamePhase == 'drawing') ...[
                _buildAutoFillButton(),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: _buildChallengesList(challenges, gamePhase),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: gamePhase == 'drawing' ? _buildSendAllButton() : null,
    );
  }

  Widget _buildWaitingScreen(String gamePhase) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Phase: ${gamePhase == 'drawing' ? 'Dessination' : 'Devination'}'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildHeader(),
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

  Widget _buildHeader() {
    return Row(
      children: [
        _buildTimerChip(),
        const SizedBox(width: 8),
        _buildScoreChip('Rouge', _viewModel.redTeamScore, AppTheme.teamRedColor),
        const SizedBox(width: 8),
        _buildScoreChip('Bleue', _viewModel.blueTeamScore, AppTheme.teamBlueColor),
      ],
    );
  }

  Widget _buildTimerChip() {
    final remaining = _viewModel.remaining;
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
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

  Widget _buildChallengesList(List<models.Challenge> challenges, String gamePhase) {
    final gameSession = _viewModel.currentGameSession;
    final gameSessionId = gameSession?.id ?? '';
    final teamColor = _getCurrentPlayerTeamColor();

    return ListView.separated(
      itemCount: challenges.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final challenge = challenges[index];

        if (gamePhase == 'drawing') {
          return _ChallengeCard(
            key: ValueKey('challenge_card_${challenge.id}'),
            index: index,
            totalChallenges: challenges.length,
            child: DrawerView(
              key: ValueKey('drawer_${challenge.id}'),
              challenge: challenge,
              gameSessionId: gameSessionId,
              onImageGenerated: () {},
              onScoreDelta: _applyScoreDelta,
              drawerTeamColor: teamColor,
            ),
          );
        } else {
          return _ChallengeCard(
            key: ValueKey('challenge_card_${challenge.id}'),
            index: index,
            totalChallenges: challenges.length,
            child: GuesserView(
              key: ValueKey('guesser_${challenge.id}'),
              challenge: challenge,
              gameSessionId: gameSessionId,
              onSubmitAnswer: _challengeFacade.answerChallenge,
              onScoreDelta: _applyScoreDelta,
              onChallengeResolved: _onChallengeResolved,
              isResolved: _viewModel.isChallengeResolved(challenge.id),
              guesserTeamColor: teamColor,
            ),
          );
        }
      },
    );
  }

  Widget _buildSendAllButton() {
    final allImagesReady = _viewModel.allImagesReady;

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
            child,
          ],
        ),
      ),
    );
  }
}
