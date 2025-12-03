import 'dart:async';
import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';
import '../../utils/logger.dart';

/// Configuration pour le WaitingOverlay
class WaitingOverlayConfig {
  /// Titre affiché en haut
  final String title;

  /// Message principal
  final String message;

  /// Sous-message (optionnel)
  final String? subMessage;

  /// Icône à afficher
  final IconData icon;

  /// Couleur d'accentuation
  final Color accentColor;

  /// Intervalle de polling
  final Duration pollingInterval;

  /// Timeout après lequel un bouton "Forcer" apparaît (null = pas de timeout)
  final Duration? forceButtonTimeout;

  /// Texte du bouton "Forcer"
  final String forceButtonText;

  const WaitingOverlayConfig({
    required this.title,
    required this.message,
    this.subMessage,
    this.icon = Icons.hourglass_top,
    this.accentColor = AppTheme.primaryColor,
    this.pollingInterval = const Duration(seconds: 2),
    this.forceButtonTimeout = const Duration(seconds: 30),
    this.forceButtonText = 'Continuer quand même',
  });
}

/// Callback pour vérifier si la transition doit se produire
typedef TransitionCondition = Future<bool> Function();

/// Callback pour obtenir le nombre de joueurs prêts
typedef PlayersReadyCallback = Future<(int ready, int total)> Function();

/// Overlay d'attente réutilisable avec gestion des transitions
///
/// Fonctionnalités:
/// - Affiche le statut des joueurs (X/4 prêts)
/// - Polling automatique avec condition configurable
/// - Timeout avec bouton "Forcer" pour débloquer
/// - Gestion des phases "devancées" par l'API
class WaitingOverlay extends StatefulWidget {
  /// Configuration de l'overlay
  final WaitingOverlayConfig config;

  /// Condition pour déclencher la transition
  final TransitionCondition onCheckTransition;

  /// Callback pour récupérer le statut des joueurs (optionnel)
  final PlayersReadyCallback? onGetPlayersReady;

  /// Callback appelé quand la transition est déclenchée
  final VoidCallback onTransition;

  /// Callback appelé quand l'utilisateur force la continuation
  final VoidCallback? onForceTransition;

  /// Widget personnalisé pour afficher les joueurs (optionnel)
  final Widget Function(int ready, int total)? playerStatusBuilder;

  const WaitingOverlay({
    super.key,
    required this.config,
    required this.onCheckTransition,
    required this.onTransition,
    this.onGetPlayersReady,
    this.onForceTransition,
    this.playerStatusBuilder,
  });

  @override
  State<WaitingOverlay> createState() => _WaitingOverlayState();
}

class _WaitingOverlayState extends State<WaitingOverlay>
    with SingleTickerProviderStateMixin {
  Timer? _pollingTimer;
  Timer? _forceButtonTimer;
  bool _hasTransitioned = false;
  bool _showForceButton = false;
  int _playersReady = 0;
  int _totalPlayers = 4;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _startPolling();
    _startForceButtonTimer();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _forceButtonTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startPolling() {
    // Premier check immédiat
    _checkTransition();

    _pollingTimer = Timer.periodic(widget.config.pollingInterval, (_) {
      if (!_hasTransitioned && mounted) {
        _checkTransition();
      }
    });
  }

  void _startForceButtonTimer() {
    final timeout = widget.config.forceButtonTimeout;
    if (timeout == null) return;

    _forceButtonTimer = Timer(timeout, () {
      if (mounted && !_hasTransitioned) {
        setState(() {
          _showForceButton = true;
        });
        AppLogger.warning('[WaitingOverlay] Force button shown after timeout');
      }
    });
  }

  Future<void> _checkTransition() async {
    if (_hasTransitioned) return;

    try {
      // Mettre à jour le statut des joueurs
      if (widget.onGetPlayersReady != null) {
        final (ready, total) = await widget.onGetPlayersReady!();
        if (mounted) {
          setState(() {
            _playersReady = ready;
            _totalPlayers = total;
          });
        }
      }

      // Vérifier la condition de transition
      final shouldTransition = await widget.onCheckTransition();

      if (shouldTransition && !_hasTransitioned && mounted) {
        _hasTransitioned = true;
        _pollingTimer?.cancel();
        _forceButtonTimer?.cancel();

        AppLogger.success('[WaitingOverlay] Transition triggered');
        widget.onTransition();
      }
    } catch (e) {
      AppLogger.error('[WaitingOverlay] Check transition error', e);
    }
  }

  void _handleForceTransition() {
    if (_hasTransitioned) return;

    _hasTransitioned = true;
    _pollingTimer?.cancel();
    _forceButtonTimer?.cancel();

    AppLogger.warning('[WaitingOverlay] Force transition triggered by user');

    if (widget.onForceTransition != null) {
      widget.onForceTransition!();
    } else {
      widget.onTransition();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône animée
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_pulseController.value * 0.1),
                      child: Icon(
                        widget.config.icon,
                        size: 48,
                        color: widget.config.accentColor,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Titre
                Text(
                  widget.config.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Message
                Text(
                  widget.config.message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),

                // Sous-message
                if (widget.config.subMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.config.subMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 24),

                // Statut des joueurs
                if (widget.playerStatusBuilder != null)
                  widget.playerStatusBuilder!(_playersReady, _totalPlayers)
                else
                  _buildDefaultPlayerStatus(),

                // Bouton "Forcer"
                if (_showForceButton) ...[
                  const SizedBox(height: 24),
                  _buildForceButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultPlayerStatus() {
    final progress = _totalPlayers > 0 ? _playersReady / _totalPlayers : 0.0;
    final isComplete = _playersReady == _totalPlayers;

    return Column(
      children: [
        // Cercle de progression
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 6,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isComplete ? AppTheme.accentColor : widget.config.accentColor,
                ),
              ),
              if (isComplete)
                Icon(
                  Icons.check_circle,
                  color: AppTheme.accentColor,
                  size: 40,
                )
              else
                Text(
                  '$_playersReady/$_totalPlayers',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: widget.config.accentColor,
                      ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isComplete ? 'Tous les joueurs sont prêts !' : 'joueurs',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isComplete ? AppTheme.accentColor : Colors.grey,
                fontWeight: isComplete ? FontWeight.bold : FontWeight.normal,
              ),
        ),
      ],
    );
  }

  Widget _buildForceButton() {
    return Column(
      children: [
        const Text(
          'La transition semble bloquée...',
          style: TextStyle(
            color: Colors.orange,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _handleForceTransition,
          icon: const Icon(Icons.skip_next),
          label: Text(widget.config.forceButtonText),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
            side: const BorderSide(color: Colors.orange),
          ),
        ),
      ],
    );
  }
}

/// Dialog d'attente simple avec WaitingOverlay
class WaitingDialog extends StatelessWidget {
  final WaitingOverlayConfig config;
  final TransitionCondition onCheckTransition;
  final VoidCallback onTransition;
  final PlayersReadyCallback? onGetPlayersReady;
  final VoidCallback? onForceTransition;

  const WaitingDialog({
    super.key,
    required this.config,
    required this.onCheckTransition,
    required this.onTransition,
    this.onGetPlayersReady,
    this.onForceTransition,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: WaitingOverlay(
        config: config,
        onCheckTransition: onCheckTransition,
        onTransition: onTransition,
        onGetPlayersReady: onGetPlayersReady,
        onForceTransition: onForceTransition,
      ),
    );
  }
}
