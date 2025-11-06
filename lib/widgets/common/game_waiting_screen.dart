import 'package:flutter/material.dart';
import '../../services/phase_transition_service.dart';
import '../../themes/app_theme.dart';

/// Widget générique pour les écrans d'attente pendant le jeu
///
/// Principe SOLID: Dependency Inversion Principle
/// Ce widget dépend d'abstractions (callbacks) plutôt que d'implémentations concrètes
///
/// Principe DRY: Don't Repeat Yourself
/// Centralise la logique d'attente utilisée 3 fois dans l'app
class GameWaitingScreen extends StatefulWidget {
  /// Titre affiché dans l'AppBar
  final String title;

  /// Message principal affiché en haut
  final String mainMessage;

  /// Message secondaire affiché en dessous
  final String secondaryMessage;

  /// Icône principale à afficher
  final IconData icon;

  /// Couleur de l'icône et des accents
  final Color accentColor;

  /// Condition à vérifier pour la transition
  final Future<bool> Function() transitionCondition;

  /// Callback appelé quand la transition doit se produire
  final VoidCallback onTransition;

  /// Intervalle de polling (défaut: 2 secondes)
  final Duration pollingInterval;

  /// Message optionnel dans la card
  final String? cardMessage;

  /// Sous-message optionnel dans la card
  final String? cardSubMessage;

  /// Widget optionnel pour afficher le statut des joueurs
  final Widget? playersCard;

  const GameWaitingScreen({
    super.key,
    required this.title,
    required this.mainMessage,
    required this.secondaryMessage,
    required this.icon,
    required this.transitionCondition,
    required this.onTransition,
    this.accentColor = AppTheme.primaryColor,
    this.pollingInterval = const Duration(seconds: 2),
    this.cardMessage,
    this.cardSubMessage,
    this.playersCard,
  });

  @override
  State<GameWaitingScreen> createState() => _GameWaitingScreenState();
}

class _GameWaitingScreenState extends State<GameWaitingScreen> {
  final PhaseTransitionService _transitionService = PhaseTransitionService();
  bool _hasTransitioned = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _transitionService.dispose();
    super.dispose();
  }

  void _startListening() {
    _transitionService.startListening(
      checkCondition: widget.transitionCondition,
      onTransition: () {
        if (!_hasTransitioned && mounted) {
          _hasTransitioned = true;
          widget.onTransition();
        }
      },
      pollingInterval: widget.pollingInterval,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animation de l'icône
              _buildAnimatedIcon(),
              const SizedBox(height: 32),

              // Message principal
              Text(
                widget.mainMessage,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: widget.accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Message secondaire
              Text(
                widget.secondaryMessage,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Card des joueurs (si fournie)
              if (widget.playersCard != null) ...[
                widget.playersCard!,
                const SizedBox(height: 16),
              ],

              // Card d'information
              _buildInfoCard(),
              const SizedBox(height: 32),

              // Indicateur de chargement
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Le jeu continue automatiquement...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: child,
        );
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: widget.accentColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.icon,
          size: 60,
          color: widget.accentColor,
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.hourglass_empty,
              size: 48,
              color: widget.accentColor,
            ),
            const SizedBox(height: 16),
            Text(
              widget.cardMessage ?? 'Veuillez patienter',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            if (widget.cardSubMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.cardSubMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            // Animation de points d'attente
            _buildLoadingDots(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (index) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 600 + (index * 200)),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.accentColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
