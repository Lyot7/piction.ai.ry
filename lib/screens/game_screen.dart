import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../themes/app_theme.dart';
import '../models/challenge.dart' as models;
import '../services/game_facade.dart';
import '../services/stable_diffusion_service.dart';
import '../utils/logger.dart';
import 'results_screen.dart';

/// Écran de jeu principal avec gestion des rôles drawer/guesser
class GameScreen extends StatefulWidget {
  final GameFacade gameFacade;

  const GameScreen({
    super.key,
    required this.gameFacade,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {

  // Timer de 5 minutes
  static const int totalSeconds = 5 * 60;
  Timer? _timer;
  int _remaining = totalSeconds;

  // État du jeu
  List<models.Challenge> _challenges = [];
  int _currentChallengeIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  // Scores par équipe
  int _redTeamScore = 100;
  int _blueTeamScore = 100;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeGame() async {
    try {
      setState(() => _isLoading = true);

      // Déterminer le rôle du joueur
      final role = widget.gameFacade.getCurrentPlayerRole();
      AppLogger.info('[GameScreen] Rôle du joueur: $role');

      // Récupérer les challenges en fonction du rôle
      if (role == 'drawer') {
        await widget.gameFacade.refreshMyChallenges();
        _challenges = widget.gameFacade.myChallenges;
      } else {
        await widget.gameFacade.refreshChallengesToGuess();
        _challenges = widget.gameFacade.challengesToGuess;
      }

      AppLogger.info('[GameScreen] ${_challenges.length} challenges chargés');

      if (_challenges.isEmpty) {
        throw Exception('Aucun challenge disponible');
      }

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
  }

  void _endGame() {
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

  void _nextChallenge() {
    if (_currentChallengeIndex < _challenges.length - 1) {
      setState(() {
        _currentChallengeIndex++;
      });
    } else {
      _endGame();
    }
  }

  void _applyScoreDelta(int delta) {
    final currentPlayer = widget.gameFacade.currentPlayer;
    if (currentPlayer == null) return;

    setState(() {
      if (currentPlayer.color == 'red') {
        _redTeamScore += delta;
        if (_redTeamScore < 0) _redTeamScore = 0;
      } else {
        _blueTeamScore += delta;
        if (_blueTeamScore < 0) _blueTeamScore = 0;
      }
    });
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

    final role = widget.gameFacade.getCurrentPlayerRole();
    final currentChallenge = _challenges[_currentChallengeIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(role == 'drawer' ? 'Dessinateur' : 'Devineur'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildHeader(currentChallenge),
              const SizedBox(height: 12),
              Expanded(
                child: role == 'drawer'
                    ? _DrawerView(
                        challenge: currentChallenge,
                        gameFacade: widget.gameFacade,
                        onImageGenerated: () => setState(() {}),
                        onScoreDelta: _applyScoreDelta,
                        onChallengeComplete: _nextChallenge,
                      )
                    : _GuesserView(
                        challenge: currentChallenge,
                        gameFacade: widget.gameFacade,
                        onScoreDelta: _applyScoreDelta,
                        onChallengeComplete: _nextChallenge,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(models.Challenge challenge) {
    return Row(
      children: [
        _buildTimerChip(),
        const SizedBox(width: 8),
        _buildScoreChip('Rouge', _redTeamScore, AppTheme.teamRedColor),
        const SizedBox(width: 8),
        _buildScoreChip('Bleue', _blueTeamScore, AppTheme.teamBlueColor),
        const Spacer(),
        Text('${_currentChallengeIndex + 1}/${_challenges.length}'),
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
      label: Text('$label: $score'),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }
}

/// Vue pour le dessinateur (drawer)
class _DrawerView extends StatefulWidget {
  final models.Challenge challenge;
  final GameFacade gameFacade;
  final VoidCallback onImageGenerated;
  final Function(int) onScoreDelta;
  final VoidCallback onChallengeComplete;

  const _DrawerView({
    required this.challenge,
    required this.gameFacade,
    required this.onImageGenerated,
    required this.onScoreDelta,
    required this.onChallengeComplete,
  });

  @override
  State<_DrawerView> createState() => _DrawerViewState();
}

class _DrawerViewState extends State<_DrawerView> {
  final TextEditingController _promptController = TextEditingController();
  String? _imageUrl;
  bool _isGenerating = false;
  int _regenCount = 0;
  String? _promptError;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  bool _validatePrompt(String prompt) {
    if (prompt.trim().isEmpty) {
      setState(() => _promptError = 'Le prompt ne peut pas être vide');
      return false;
    }

    if (widget.challenge.promptContainsForbiddenWords(prompt)) {
      setState(() => _promptError = 'Le prompt contient des mots interdits !');
      return false;
    }

    setState(() => _promptError = null);
    return true;
  }

  Future<void> _generateImage({bool isRegen = false}) async {
    final prompt = _promptController.text.trim();

    if (!_validatePrompt(prompt)) {
      return;
    }

    setState(() {
      _isGenerating = true;
      _promptError = null;
    });

    try {
      final gameSession = widget.gameFacade.currentGameSession;
      if (gameSession == null) {
        throw Exception('Aucune session de jeu active');
      }

      // Générer l'image via l'API
      final imageUrl = await StableDiffusionService.generateImageWithRetry(
        prompt,
        gameSession.id,
        widget.challenge.id,
      );

      setState(() {
        _imageUrl = imageUrl;
        _isGenerating = false;
        if (isRegen) {
          _regenCount++;
          widget.onScoreDelta(-10); // Coût de régénération
        }
      });

      widget.onImageGenerated();
      AppLogger.success('[DrawerView] Image générée avec succès');
    } catch (e) {
      AppLogger.error('[DrawerView] Erreur génération image', e);
      setState(() {
        _isGenerating = false;
        _promptError = 'Erreur: ${e.toString()}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _sendToGuesser() {
    if (_imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez d\'abord générer une image'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Marquer le challenge comme envoyé
    AppLogger.success('[DrawerView] Image envoyée au devineur');

    // Passer au prochain challenge ou attendre le devineur
    widget.onChallengeComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Challenge à illustrer
        Card(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Challenge à illustrer:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.challenge.fullPhrase,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '⚠️ Ne pas utiliser: ${widget.challenge.allForbiddenWords.join(", ")}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.errorColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Input pour le prompt
        TextField(
          controller: _promptController,
          decoration: InputDecoration(
            labelText: 'Votre prompt pour l\'IA',
            hintText: 'Décrivez l\'image sans utiliser les mots interdits...',
            errorText: _promptError,
            suffixIcon: IconButton(
              icon: const Icon(Icons.auto_awesome),
              onPressed: _isGenerating ? null : () => _generateImage(),
              tooltip: 'Générer l\'image',
            ),
          ),
          maxLines: 3,
          enabled: !_isGenerating,
        ),
        const SizedBox(height: 12),

        // Zone d'affichage de l'image
        Expanded(
          child: _imageUrl == null
              ? Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _isGenerating
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Génération de l\'image en cours...'),
                            ],
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Écrivez un prompt et générez l\'image',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                )
              : Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: _imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.broken_image, size: 48),
                        ),
                      ),
                    ),
                    if (_isGenerating)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),

        // Boutons d'action
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _regenCount < 2 && !_isGenerating && _imageUrl != null
                    ? () => _generateImage(isRegen: true)
                    : null,
                icon: const Icon(Icons.refresh),
                label: Text('Régénérer (${2 - _regenCount})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _imageUrl != null && !_isGenerating ? _sendToGuesser : null,
                icon: const Icon(Icons.send),
                label: const Text('Envoyer au devineur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Vue pour le devineur (guesser)
class _GuesserView extends StatefulWidget {
  final models.Challenge challenge;
  final GameFacade gameFacade;
  final Function(int) onScoreDelta;
  final VoidCallback onChallengeComplete;

  const _GuesserView({
    required this.challenge,
    required this.gameFacade,
    required this.onScoreDelta,
    required this.onChallengeComplete,
  });

  @override
  State<_GuesserView> createState() => _GuesserViewState();
}

class _GuesserViewState extends State<_GuesserView> {
  final TextEditingController _guessController = TextEditingController();
  bool _isSubmitting = false;
  final List<String> _previousGuesses = [];

  @override
  void dispose() {
    _guessController.dispose();
    super.dispose();
  }

  bool _checkAnswer(String guess) {
    final guessLower = guess.toLowerCase().trim();

    // Vérifier si la réponse contient input1 ou input2
    return widget.challenge.targetWords.any((target) =>
      guessLower.contains(target.toLowerCase())
    );
  }

  Future<void> _submitGuess() async {
    final guess = _guessController.text.trim();

    if (guess.isEmpty) return;
    if (_previousGuesses.contains(guess.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous avez déjà essayé cette réponse'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _previousGuesses.add(guess.toLowerCase());
    });

    try {
      final isCorrect = _checkAnswer(guess);

      // Envoyer la réponse à l'API
      await widget.gameFacade.answerChallenge(
        widget.gameFacade.currentGameSession!.id,
        widget.challenge.id,
        guess,
        isCorrect,
      );

      if (isCorrect) {
        widget.onScoreDelta(25); // +25 points pour bonne réponse

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Bravo ! Réponse correcte ! 🎉'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Attendre un peu puis passer au suivant
        await Future.delayed(const Duration(seconds: 2));
        widget.onChallengeComplete();
      } else {
        widget.onScoreDelta(-1); // -1 point pour mauvaise réponse

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Raté ! Essayez encore (-1 point)'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }

      _guessController.clear();
      setState(() => _isSubmitting = false);
    } catch (e) {
      AppLogger.error('[GuesserView] Erreur soumission réponse', e);
      setState(() => _isSubmitting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.challenge.imageUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Info
        Card(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.search, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Devinez ce qui est représenté dans l\'image',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Zone d'affichage de l'image
        Expanded(
          child: imageUrl == null || imageUrl.isEmpty
              ? Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'En attente de l\'image du dessinateur...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 16),

        // Tentatives précédentes
        if (_previousGuesses.isNotEmpty) ...[
          Text(
            'Tentatives précédentes:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _previousGuesses.map((guess) {
              return Chip(
                label: Text(guess),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: null,
                backgroundColor: Colors.red.withValues(alpha: 0.1),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Input pour deviner
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _guessController,
                decoration: const InputDecoration(
                  hintText: 'Votre réponse...',
                  labelText: 'Que voyez-vous dans l\'image ?',
                ),
                enabled: !_isSubmitting && imageUrl != null,
                onSubmitted: (_) => _submitGuess(),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: !_isSubmitting && imageUrl != null ? _submitGuess : null,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('Valider'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
