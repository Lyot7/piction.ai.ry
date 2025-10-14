import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/challenge.dart' as models;
import '../../repositories/image_repository.dart';
import '../../themes/app_theme.dart';
import '../../validators/prompt_validator.dart';
import '../../utils/logger.dart';

/// Widget pour la vue du dessinateur (drawer)
/// Principe SOLID: Single Responsibility - Vue drawer uniquement
class DrawerView extends StatefulWidget {
  final models.Challenge challenge;
  final String gameSessionId;
  final Function(int) onScoreDelta;
  final VoidCallback onChallengeComplete;

  const DrawerView({
    super.key,
    required this.challenge,
    required this.gameSessionId,
    required this.onScoreDelta,
    required this.onChallengeComplete,
  });

  @override
  State<DrawerView> createState() => _DrawerViewState();
}

class _DrawerViewState extends State<DrawerView> {
  final TextEditingController _promptController = TextEditingController();
  final ImageRepository _imageRepository = ImageRepository();

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
    _promptError = PromptValidator.getErrorMessage(prompt, widget.challenge);
    setState(() {});
    return _promptError == null;
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
      final imageUrl = await _imageRepository.generateImage(
        prompt,
        widget.gameSessionId,
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

    AppLogger.success('[DrawerView] Image envoyée au devineur');
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
          child: _buildImageArea(),
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

  Widget _buildImageArea() {
    if (_imageUrl == null) {
      return Container(
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
      );
    }

    return Stack(
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
    );
  }
}
