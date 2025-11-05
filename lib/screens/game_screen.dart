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

  const GameScreen({super.key, required this.gameFacade});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Timer de 5 minutes
  static const int totalSeconds = 5 * 60;
  Timer? _timer;
  Timer? _refreshTimer;
  int _remaining = totalSeconds;

  // État du jeu
  List<models.Challenge> _challenges = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isAutoGenerating = false;

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
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeGame() async {
    try {
      setState(() => _isLoading = true);

      // Déterminer la phase de jeu
      final gameSession = widget.gameFacade.currentGameSession;
      final gamePhase = gameSession?.gamePhase ?? 'drawing';

      AppLogger.info('[GameScreen] Phase: $gamePhase');

      // Récupérer les challenges en fonction de la phase
      // Phase DRAWING: TOUS les joueurs dessinent leurs 3 challenges
      // Phase GUESSING: TOUS les joueurs devinent les dessins de leur coéquipier
      if (gamePhase == 'drawing') {
        // ✅ TOUS les joueurs (peu importe le rôle) dessinent leurs 3 challenges
        await widget.gameFacade.refreshMyChallenges();
        _challenges = widget.gameFacade.myChallenges;
      } else if (gamePhase == 'guessing') {
        // ✅ TOUS les joueurs (peu importe le rôle) devinent les dessins de leur coéquipier
        await widget.gameFacade.refreshChallengesToGuess();
        _challenges = widget.gameFacade.challengesToGuess;
      }

      AppLogger.info('[GameScreen] ${_challenges.length} challenges chargés');

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

      final gamePhase = gameSession.gamePhase ?? 'drawing';

      if (gamePhase == 'drawing') {
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
      } else if (gamePhase == 'guessing') {
        await widget.gameFacade.refreshChallengesToGuess();
        if (mounted) {
          setState(() {
            _challenges = widget.gameFacade.challengesToGuess;
          });
        }
      }
    } catch (e) {
      AppLogger.error('[GameScreen] Erreur rafraîchissement challenges', e);
    }
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

    final gameSession = widget.gameFacade.currentGameSession;
    final gamePhase = gameSession?.gamePhase ?? 'drawing';

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

                    // Afficher DrawerView ou GuesserView selon la phase
                    if (gamePhase == 'drawing') {
                      return _ChallengeCard(
                        key: ValueKey('challenge_card_${challenge.id}'),
                        index: index,
                        totalChallenges: _challenges.length,
                        child: _DrawerView(
                          key: ValueKey('drawer_${challenge.id}'),
                          challenge: challenge,
                          gameFacade: widget.gameFacade,
                          onImageGenerated: () => setState(() {}),
                          onScoreDelta: _applyScoreDelta,
                        ),
                      );
                    } else {
                      return _ChallengeCard(
                        key: ValueKey('challenge_card_${challenge.id}'),
                        index: index,
                        totalChallenges: _challenges.length,
                        child: _GuesserView(
                          key: ValueKey('guesser_${challenge.id}'),
                          challenge: challenge,
                          gameFacade: widget.gameFacade,
                          onScoreDelta: _applyScoreDelta,
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
      AppLogger.info('[GameScreen] Début auto-génération pour ${_challenges.length} challenges');

      for (int i = 0; i < _challenges.length; i++) {
        final challenge = _challenges[i];

        // Générer un prompt automatique
        final autoPrompt = _generateAutoPrompt(challenge);

        AppLogger.info('[GameScreen] Génération challenge ${i + 1}/${_challenges.length}: $autoPrompt');

        // Rafraîchir la session pour vérifier la phase
        final gameSession = widget.gameFacade.currentGameSession;
        if (gameSession != null) {
          await widget.gameFacade.refreshGameSession(gameSession.id);
        }

        final updatedSession = widget.gameFacade.currentGameSession;
        if (updatedSession == null) {
          throw Exception('Session de jeu non disponible');
        }

        // Utiliser 'drawing' par défaut si gamePhase est null
        final gamePhase = updatedSession.gamePhase ?? 'drawing';
        AppLogger.info('[GameScreen] Phase pour challenge ${i + 1}: $gamePhase');

        if (gamePhase != 'drawing' && gamePhase != 'playing') {
          throw Exception('Phase de jeu incorrecte: $gamePhase. Veuillez générer les images en phase "drawing".');
        }

        // Générer l'image
        await StableDiffusionService.generateImageWithRetry(
          autoPrompt,
          updatedSession.id,
          challenge.id,
        );

        // Attendre un peu entre chaque génération
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Rafraîchir les challenges pour récupérer les URLs
      await widget.gameFacade.refreshMyChallenges();

      setState(() {
        _challenges = widget.gameFacade.myChallenges;
        _isAutoGenerating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les images ont été générées automatiquement !'),
            backgroundColor: Colors.green,
          ),
        );
      }

      AppLogger.success('[GameScreen] Auto-génération terminée avec succès');
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_challenges.length} dessins envoyés ! En attente des autres joueurs...',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
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

/// Vue pour le dessinateur (drawer)
class _DrawerView extends StatefulWidget {
  final models.Challenge challenge;
  final GameFacade gameFacade;
  final VoidCallback onImageGenerated;
  final Function(int) onScoreDelta;

  const _DrawerView({
    super.key,
    required this.challenge,
    required this.gameFacade,
    required this.onImageGenerated,
    required this.onScoreDelta,
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
  void initState() {
    super.initState();
    // Initialiser avec l'image existante si disponible
    _imageUrl = widget.challenge.imageUrl;
    if (widget.challenge.prompt != null) {
      _promptController.text = widget.challenge.prompt!;
    }
  }

  @override
  void didUpdateWidget(_DrawerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Log pour debug
    AppLogger.info('[DrawerView] didUpdateWidget appelé - challengeId: ${widget.challenge.id}');
    AppLogger.info('[DrawerView] oldWidget.imageUrl: ${oldWidget.challenge.imageUrl}');
    AppLogger.info('[DrawerView] newWidget.imageUrl: ${widget.challenge.imageUrl}');
    AppLogger.info('[DrawerView] _imageUrl actuel: $_imageUrl');

    // Mettre à jour l'image si le challenge a changé
    if (oldWidget.challenge.id != widget.challenge.id ||
        oldWidget.challenge.imageUrl != widget.challenge.imageUrl) {
      AppLogger.success('[DrawerView] Mise à jour de l\'image vers: ${widget.challenge.imageUrl}');
      setState(() {
        _imageUrl = widget.challenge.imageUrl;
        if (widget.challenge.prompt != null && widget.challenge.prompt != _promptController.text) {
          _promptController.text = widget.challenge.prompt!;
        }
      });
    }
  }

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

      // Rafraîchir l'état de la game session pour avoir la phase à jour
      await widget.gameFacade.refreshGameSession(gameSession.id);

      // Récupérer la session mise à jour
      final updatedSession = widget.gameFacade.currentGameSession;
      if (updatedSession == null) {
        throw Exception('Impossible de récupérer l\'état de la session');
      }

      // Vérifier que la session est en phase "drawing" (null = drawing par défaut)
      final gamePhase = updatedSession.gamePhase ?? 'drawing';
      AppLogger.info('[DrawerView] Phase actuelle avant génération: $gamePhase');

      if (gamePhase != 'drawing' && gamePhase != 'playing') {
        throw Exception('La phase de jeu ne permet plus de générer d\'images (phase: $gamePhase).\nVeuillez générer toutes les images avant que le jeu ne commence.');
      }

      // Générer l'image via l'API
      final imageUrl = await StableDiffusionService.generateImageWithRetry(
        prompt,
        updatedSession.id,
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

      // Rafraîchir les challenges pour récupérer l'URL depuis le backend
      await widget.gameFacade.refreshMyChallenges();

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
                const SizedBox(height: 12),
                // Mots interdits avec chips
                Row(
                  children: [
                    Icon(Icons.block, color: AppTheme.errorColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Mots interdits:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.challenge.allForbiddenWords.map((word) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.errorColor,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        word,
                        style: TextStyle(
                          color: AppTheme.errorColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }).toList(),
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
        SizedBox(
          height: 300, // Hauteur fixe pour le scroll
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
                              Icon(
                                Icons.image_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
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
                        placeholder: (context, url) =>
                            const Center(child: CircularProgressIndicator()),
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
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),

        // Bouton régénération
        ElevatedButton.icon(
          onPressed: _regenCount < 2 && !_isGenerating && _imageUrl != null
              ? () => _generateImage(isRegen: true)
              : null,
          icon: const Icon(Icons.refresh),
          label: Text('Régénérer (${2 - _regenCount})'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 44),
          ),
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

  const _GuesserView({
    super.key,
    required this.challenge,
    required this.gameFacade,
    required this.onScoreDelta,
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
    return widget.challenge.targetWords.any(
      (target) => guessLower.contains(target.toLowerCase()),
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
              content: const Text(
                'Bravo ! Réponse correcte ! 🎉 Passez au challenge suivant',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
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
        SizedBox(
          height: 300, // Hauteur fixe pour le scroll
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
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        const Center(child: Icon(Icons.broken_image, size: 48)),
                  ),
                ),
        ),
        const SizedBox(height: 16),

        // Tentatives précédentes
        if (_previousGuesses.isNotEmpty) ...[
          Text(
            'Tentatives précédentes:',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
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
              onPressed: !_isSubmitting && imageUrl != null
                  ? _submitGuess
                  : null,
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
