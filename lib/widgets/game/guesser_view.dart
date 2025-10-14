import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/challenge.dart' as models;
import '../../managers/challenge_manager.dart';
import '../../themes/app_theme.dart';
import '../../utils/logger.dart';

/// Widget pour la vue du devineur (guesser)
/// Principe SOLID: Single Responsibility - Vue guesser uniquement
class GuesserView extends StatefulWidget {
  final models.Challenge challenge;
  final String gameSessionId;
  final ChallengeManager challengeManager;
  final Function(int) onScoreDelta;
  final VoidCallback onChallengeComplete;

  const GuesserView({
    super.key,
    required this.challenge,
    required this.gameSessionId,
    required this.challengeManager,
    required this.onScoreDelta,
    required this.onChallengeComplete,
  });

  @override
  State<GuesserView> createState() => _GuesserViewState();
}

class _GuesserViewState extends State<GuesserView> {
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
      await widget.challengeManager.answerChallenge(
        widget.gameSessionId,
        widget.challenge.id,
        guess,
        isCorrect,
      );

      if (isCorrect) {
        widget.onScoreDelta(25); // +25 points pour bonne réponse

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bravo ! Réponse correcte ! 🎉'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
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
              content: const Text('Raté ! Essayez encore (-1 point)'),
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
          child: _buildImageArea(imageUrl),
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

  Widget _buildImageArea(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
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
      );
    }

    return ClipRRect(
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
    );
  }
}
