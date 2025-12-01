import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/challenge.dart' as models;
import '../../themes/app_theme.dart';
import '../../utils/logger.dart';

/// Callback type pour soumettre une réponse
typedef SubmitAnswerCallback = Future<void> Function(
  String gameSessionId,
  String challengeId,
  String answer,
  bool isCorrect,
);

/// Widget pour la vue du devineur (guesser)
/// Principe SOLID: Single Responsibility - Vue guesser uniquement
class GuesserView extends StatefulWidget {
  final models.Challenge challenge;
  final String gameSessionId;

  /// Callback pour soumettre une réponse à l'API
  final SubmitAnswerCallback onSubmitAnswer;

  /// Callback pour appliquer un delta de score
  /// [delta] : points à ajouter (négatif pour retirer)
  /// [teamColor] : optionnel, la couleur de l'équipe à impacter ('red' ou 'blue')
  final Function(int delta, {String? teamColor}) onScoreDelta;

  /// Callback appelé quand le challenge est résolu
  final Function(String challengeId) onChallengeResolved;

  /// Indique si le challenge est déjà résolu
  final bool isResolved;

  /// Couleur de l'équipe du guesser (pour les points)
  final String? guesserTeamColor;

  const GuesserView({
    super.key,
    required this.challenge,
    required this.gameSessionId,
    required this.onSubmitAnswer,
    required this.onScoreDelta,
    required this.onChallengeResolved,
    this.isResolved = false,
    this.guesserTeamColor,
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
    return widget.challenge.targetWords
        .any((target) => guessLower.contains(target.toLowerCase()));
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

    // Capturer la couleur de l'équipe avant les opérations async
    final teamColor = widget.guesserTeamColor;
    if (teamColor != null) {
      AppLogger.info(
          '[GuesserView] 🎯 Tentative par équipe $teamColor');
    }

    setState(() {
      _isSubmitting = true;
      _previousGuesses.add(guess.toLowerCase());
    });

    try {
      final isCorrect = _checkAnswer(guess);

      // Envoyer la réponse à l'API
      await widget.onSubmitAnswer(
        widget.gameSessionId,
        widget.challenge.id,
        guess,
        isCorrect,
      );

      if (isCorrect) {
        // Appliquer les points avec l'équipe explicite
        if (teamColor != null) {
          AppLogger.info(
              '[GuesserView] ✅ Bonne réponse: +25 pts pour équipe $teamColor');
          widget.onScoreDelta(25, teamColor: teamColor);
        } else {
          widget.onScoreDelta(25);
        }

        widget.onChallengeResolved(widget.challenge.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bravo ! Réponse correcte ! 🎉 Passez au challenge suivant'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Appliquer la pénalité avec l'équipe explicite
        if (teamColor != null) {
          AppLogger.info(
              '[GuesserView] ❌ Mauvaise réponse: -1 pt pour équipe $teamColor');
          widget.onScoreDelta(-1, teamColor: teamColor);
        } else {
          widget.onScoreDelta(-1);
        }

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
    final isResolved = widget.isResolved;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner de succès si résolu
        if (isResolved) _buildSuccessBanner(),
        if (isResolved) const SizedBox(height: 16),

        // Info card
        _buildInfoCard(context, isResolved),
        const SizedBox(height: 16),

        // Zone d'affichage de l'image
        SizedBox(
          height: 300,
          child: _buildImageArea(imageUrl),
        ),
        const SizedBox(height: 16),

        // Tentatives précédentes
        if (_previousGuesses.isNotEmpty) ...[
          _buildPreviousGuesses(context),
          const SizedBox(height: 12),
        ],

        // Input pour deviner
        _buildGuessInput(imageUrl, isResolved),
      ],
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Challenge résolu ! ✓',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, bool isResolved) {
    return Card(
      color: isResolved
          ? Colors.green.withValues(alpha: 0.1)
          : AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isResolved ? Icons.check_circle : Icons.search,
              color: isResolved ? Colors.green : AppTheme.primaryColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isResolved
                    ? 'Challenge terminé'
                    : 'Devinez ce qui est représenté dans l\'image',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isResolved ? Colors.green : AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousGuesses(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _buildGuessInput(String? imageUrl, bool isResolved) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _guessController,
            decoration: InputDecoration(
              hintText: isResolved ? 'Challenge résolu ✓' : 'Votre réponse...',
              labelText: isResolved ? 'Terminé' : 'Que voyez-vous dans l\'image ?',
            ),
            enabled: !_isSubmitting && imageUrl != null && !isResolved,
            onSubmitted: (_) => _submitGuess(),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed:
              !_isSubmitting && imageUrl != null && !isResolved ? _submitGuess : null,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(isResolved ? Icons.check : Icons.send),
          label: Text(isResolved ? 'Validé' : 'Valider'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isResolved ? Colors.green : AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
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
