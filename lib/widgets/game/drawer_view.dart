import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../di/locator.dart';
import '../../interfaces/image_api_interface.dart';
import '../../models/challenge.dart' as models;
import '../../themes/app_theme.dart';
import '../../validators/prompt_validator.dart';
import '../../utils/logger.dart';

/// Widget pour la vue du dessinateur (drawer)
/// Principe SOLID: Single Responsibility - Vue drawer uniquement
class DrawerView extends StatefulWidget {
  final models.Challenge challenge;
  final String gameSessionId;

  /// Callback pour appliquer un delta de score
  /// [delta] : points à ajouter (négatif pour retirer)
  /// [teamColor] : optionnel, la couleur de l'équipe à impacter ('red' ou 'blue')
  final Function(int delta, {String? teamColor}) onScoreDelta;

  /// Callback appelé quand une image est générée avec succès
  final VoidCallback onImageGenerated;

  /// Couleur de l'équipe du drawer (pour les pénalités de régénération)
  final String? drawerTeamColor;

  /// Image URL initiale (si déjà générée)
  final String? initialImageUrl;

  const DrawerView({
    super.key,
    required this.challenge,
    required this.gameSessionId,
    required this.onScoreDelta,
    required this.onImageGenerated,
    this.drawerTeamColor,
    this.initialImageUrl,
  });

  @override
  State<DrawerView> createState() => _DrawerViewState();
}

class _DrawerViewState extends State<DrawerView> {
  final TextEditingController _promptController = TextEditingController();
  IImageApi get _imageApi => Locator.get<IImageApi>();

  String? _imageUrl;
  bool _isGenerating = false;
  int _regenCount = 0;
  String? _promptError;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.initialImageUrl ?? widget.challenge.imageUrl;
    if (widget.challenge.prompt != null) {
      _promptController.text = widget.challenge.prompt!;
    }
  }

  @override
  void didUpdateWidget(DrawerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.challenge.id != widget.challenge.id ||
        oldWidget.challenge.imageUrl != widget.challenge.imageUrl) {
      setState(() {
        _imageUrl = widget.challenge.imageUrl;
        if (widget.challenge.prompt != null &&
            widget.challenge.prompt != _promptController.text) {
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
      final imageUrl = await _imageApi.generateImageWithRetry(
        widget.gameSessionId,
        widget.challenge.id,
        prompt,
      );

      setState(() {
        _imageUrl = imageUrl;
        _isGenerating = false;
        if (isRegen) {
          _regenCount++;
          // Appliquer le coût de régénération avec l'équipe explicite
          if (widget.drawerTeamColor != null) {
            AppLogger.info(
                '[DrawerView] 💸 Régénération: -10 pts pour équipe ${widget.drawerTeamColor}');
            widget.onScoreDelta(-10, teamColor: widget.drawerTeamColor);
          } else {
            AppLogger.warning(
                '[DrawerView] 💸 Régénération: -10 pts (équipe non spécifiée)');
            widget.onScoreDelta(-10);
          }
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Challenge à illustrer
        _buildChallengeCard(context),
        const SizedBox(height: 16),

        // Input pour le prompt
        _buildPromptInput(),
        const SizedBox(height: 12),

        // Zone d'affichage de l'image
        SizedBox(
          height: 300,
          child: _buildImageArea(),
        ),
        const SizedBox(height: 12),

        // Bouton régénération avec coût affiché
        _buildRegenerateButton(),
      ],
    );
  }

  Widget _buildChallengeCard(BuildContext context) {
    return Card(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    );
  }

  Widget _buildPromptInput() {
    return TextField(
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
    );
  }

  Widget _buildRegenerateButton() {
    return ElevatedButton.icon(
      onPressed: _regenCount < 2 && !_isGenerating && _imageUrl != null
          ? () => _generateImage(isRegen: true)
          : null,
      icon: const Icon(Icons.refresh),
      label: Text('Régénérer (${2 - _regenCount} restant) -10 pts'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 44),
      ),
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
