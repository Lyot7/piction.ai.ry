import 'dart:async';
import 'package:flutter/material.dart';
import '../../di/locator.dart';
import '../../interfaces/facades/game_state_facade_interface.dart';
import '../../interfaces/facades/session_facade_interface.dart';
import '../../themes/app_theme.dart';
import '../../utils/logger.dart';

/// Mode de comportement quand la phase est "devancée" par l'API
enum PhaseSkippedBehavior {
  /// Afficher un overlay avec option de continuer l'action en cours
  showOverlayWithContinue,

  /// Naviguer automatiquement vers la phase suivante
  autoNavigate,

  /// Ne rien faire (laisser le screen gérer)
  ignore,
}

/// Configuration du PhaseGuard
class PhaseGuardConfig {
  /// Phases autorisées pour ce screen (ex: ['drawing'])
  final List<String> allowedPhases;

  /// Status autorisés pour ce screen (ex: ['playing'])
  final List<String> allowedStatuses;

  /// Comportement quand la phase est devancée
  final PhaseSkippedBehavior onPhaseSkipped;

  /// Callback pour la navigation quand la phase est devancée
  final void Function(BuildContext context, String newPhase, String newStatus)?
      onNavigateToNextPhase;

  /// Message à afficher quand la phase est devancée
  final String phaseSkippedMessage;

  /// Intervalle de vérification
  final Duration checkInterval;

  const PhaseGuardConfig({
    required this.allowedPhases,
    this.allowedStatuses = const ['playing'],
    this.onPhaseSkipped = PhaseSkippedBehavior.showOverlayWithContinue,
    this.onNavigateToNextPhase,
    this.phaseSkippedMessage =
        'La partie a avancé. Vous pouvez terminer votre action ou continuer.',
    this.checkInterval = const Duration(seconds: 3),
  });
}

/// Widget qui surveille la phase du jeu et gère les transitions inattendues
///
/// Utilisation:
/// ```dart
/// PhaseGuard(
///   config: PhaseGuardConfig(
///     allowedPhases: ['drawing'],
///     onNavigateToNextPhase: (context, phase, status) {
///       Navigator.pushReplacement(context, ...);
///     },
///   ),
///   child: DrawerView(...),
/// )
/// ```
class PhaseGuard extends StatefulWidget {
  final PhaseGuardConfig config;
  final Widget child;

  /// Callback optionnel appelé avant la navigation forcée
  /// Retourne true pour permettre la navigation, false pour l'annuler
  final Future<bool> Function()? onBeforeForceNavigate;

  const PhaseGuard({
    super.key,
    required this.config,
    required this.child,
    this.onBeforeForceNavigate,
  });

  @override
  State<PhaseGuard> createState() => _PhaseGuardState();
}

class _PhaseGuardState extends State<PhaseGuard> {
  Timer? _checkTimer;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _phaseSubscription;
  bool _phaseSkipped = false;
  String? _currentPhase;
  String? _currentStatus;

  IGameStateFacade get _gameStateFacade => Locator.get<IGameStateFacade>();
  ISessionFacade get _sessionFacade => Locator.get<ISessionFacade>();

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _statusSubscription?.cancel();
    _phaseSubscription?.cancel();
    super.dispose();
  }

  void _startMonitoring() {
    // Écouter les streams
    _statusSubscription = _gameStateFacade.statusStream.listen((status) {
      _currentStatus = status;
      _checkPhase();
    });

    _phaseSubscription = _gameStateFacade.phaseStream.listen((phase) {
      _currentPhase = phase;
      _checkPhase();
    });

    // Polling de backup
    _checkTimer = Timer.periodic(widget.config.checkInterval, (_) {
      if (mounted) {
        _refreshAndCheck();
      }
    });

    // Check initial
    _refreshAndCheck();
  }

  Future<void> _refreshAndCheck() async {
    try {
      final session = _sessionFacade.currentGameSession;
      if (session != null) {
        await _gameStateFacade.syncWithSession();
        _currentStatus = session.status;
        _currentPhase = session.gamePhase;
        _checkPhase();
      }
    } catch (e) {
      AppLogger.error('[PhaseGuard] Refresh error', e);
    }
  }

  void _checkPhase() {
    if (!mounted || _phaseSkipped) return;

    final status = _currentStatus ?? _gameStateFacade.currentStatus;
    final phase = _currentPhase ?? _gameStateFacade.currentPhase;

    // Vérifier si le status est autorisé
    final statusAllowed = widget.config.allowedStatuses.contains(status);

    // Vérifier si la phase est autorisée (null est accepté si 'null' est dans la liste)
    final phaseAllowed = widget.config.allowedPhases.contains(phase) ||
        (phase == null && widget.config.allowedPhases.contains('null'));

    // Si le status est "finished", toujours considérer comme "devancé"
    if (status == 'finished') {
      _handlePhaseSkipped(phase, status);
      return;
    }

    // Si ni status ni phase n'est autorisé, la phase a été devancée
    if (!statusAllowed || !phaseAllowed) {
      AppLogger.warning(
        '[PhaseGuard] Phase skipped! Status: $status (allowed: ${widget.config.allowedStatuses}), '
        'Phase: $phase (allowed: ${widget.config.allowedPhases})',
      );
      _handlePhaseSkipped(phase, status);
    }
  }

  void _handlePhaseSkipped(String? phase, String? status) {
    if (_phaseSkipped) return;

    setState(() {
      _phaseSkipped = true;
    });

    switch (widget.config.onPhaseSkipped) {
      case PhaseSkippedBehavior.autoNavigate:
        _navigateToNextPhase(phase, status);
        break;
      case PhaseSkippedBehavior.showOverlayWithContinue:
        // L'overlay sera affiché via le build
        break;
      case PhaseSkippedBehavior.ignore:
        // Ne rien faire
        break;
    }
  }

  Future<void> _navigateToNextPhase(String? phase, String? status) async {
    if (widget.config.onNavigateToNextPhase != null && mounted) {
      // Vérifier si on peut naviguer
      if (widget.onBeforeForceNavigate != null) {
        final canNavigate = await widget.onBeforeForceNavigate!();
        if (!canNavigate || !mounted) return;
      }

      if (!mounted) return;

      widget.config.onNavigateToNextPhase!(
        context,
        phase ?? 'unknown',
        status ?? 'unknown',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_phaseSkipped &&
            widget.config.onPhaseSkipped ==
                PhaseSkippedBehavior.showOverlayWithContinue)
          _buildPhaseSkippedOverlay(),
      ],
    );
  }

  Widget _buildPhaseSkippedOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 8,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            border: Border(
              top: BorderSide(color: Colors.orange.shade300, width: 2),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.config.phaseSkippedMessage,
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _phaseSkipped = false;
                        });
                      },
                      child: const Text('Continuer mon action'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _navigateToNextPhase(
                        _currentPhase,
                        _currentStatus,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                      ),
                      child: const Text('Aller à la suite'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
