import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../themes/app_theme.dart';
import 'results_screen.dart';
import 'challenge_creation_screen.dart';

/// Écran de jeu principal
class GameScreen extends StatefulWidget {
  final List<Challenge> challenges;
  const GameScreen({super.key, required this.challenges});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Timer de 5 minutes
  static const int totalSeconds = 5 * 60;
  Timer? _timer;
  int _remaining = totalSeconds;

  int _currentChallengeIndex = 0;
  int _scoreTeam1 = 100;
  int _scoreTeam2 = 100;
  int _regenCount = 0;

  // Saisie du devineur
  final TextEditingController _guessController = TextEditingController();

  // Image générée (placeholder URL pour l'instant)
  String? _imageUrl;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _generateImage();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _guessController.dispose();
    super.dispose();
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

  Future<void> _generateImage({bool isRegen = false}) async {
    setState(() {
      _isGenerating = true;
    });

    // TODO: intégrer l'appel réel à l'API StableDiffusion.
    // Simulation: attente 2 secondes et attribution d'une image de placeholder.
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _imageUrl = 'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/600/400';
      _isGenerating = false;
      if (isRegen) {
        _regenCount++;
        _applyScoreDelta(-10); // coût de régénération
      }
    });
  }

  void _applyScoreDelta(int delta) {
    // Pour cette base, appliquons les points à l'équipe 1
    setState(() {
      _scoreTeam1 += delta;
      if (_scoreTeam1 < 0) _scoreTeam1 = 0;
    });
  }

  void _submitGuess() {
    final guess = _guessController.text.trim().toLowerCase();
    if (guess.isEmpty) return;

    final challenge = widget.challenges[_currentChallengeIndex];
    final target1 = challenge.input1.toLowerCase();
    final target2 = challenge.input2.toLowerCase();

    if (guess.contains(target1) || guess.contains(target2)) {
      _applyScoreDelta(25);
      _nextChallenge();
    } else {
      _applyScoreDelta(-1);
    }

    _guessController.clear();
  }

  void _nextChallenge() {
    if (_currentChallengeIndex < widget.challenges.length - 1) {
      setState(() {
        _currentChallengeIndex++;
        _regenCount = 0;
      });
      _generateImage();
    } else {
      _endGame();
    }
  }

  void _endGame() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultsScreen(
          scoreTeam1: _scoreTeam1,
          scoreTeam2: _scoreTeam2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenges[_currentChallengeIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manche en cours'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildHeader(challenge),
              const SizedBox(height: 12),
              Expanded(child: _buildImageArea()),
              const SizedBox(height: 12),
              _buildGuessInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Challenge challenge) {
    return Row(
      children: [
        _buildTimerChip(),
        const SizedBox(width: 8),
        _buildScoreChip('Équipe 1', _scoreTeam1, AppTheme.team1Color),
        const SizedBox(width: 8),
        _buildScoreChip('Équipe 2', _scoreTeam2, AppTheme.team2Color),
        const Spacer(),
        Text('Challenge ${_currentChallengeIndex + 1}/${widget.challenges.length}'),
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
      backgroundColor: color.withOpacity(0.08),
      side: BorderSide(color: color.withOpacity(0.3)),
    );
  }

  Widget _buildImageArea() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.textLight),
            ),
            child: _imageUrl == null
                ? const Center(child: Text('Aucune image encore'))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: _imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(Icons.broken_image, size: 48),
                      ),
                    ),
                  ),
          ),
        ),
        if (_isGenerating)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildGuessInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _guessController,
            decoration: const InputDecoration(
              hintText: 'Votre proposition...',
            ),
            onSubmitted: (_) => _submitGuess(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _submitGuess,
          icon: const Icon(Icons.send),
          color: AppTheme.primaryColor,
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _regenCount < 2 && !_isGenerating
              ? () => _generateImage(isRegen: true)
              : null,
          icon: const Icon(Icons.refresh),
          label: Text('Régénérer (${2 - _regenCount})'),
        ),
      ],
    );
  }
}