import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../themes/app_theme.dart';
import '../models/game_session.dart';
import '../models/player.dart';
import '../services/game_service.dart';
import '../services/deep_link_service.dart';

/// Écran de lobby pour organiser les équipes et commencer la partie
class LobbyScreen extends StatefulWidget {
  final GameSession gameSession;

  const LobbyScreen({super.key, required this.gameSession});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final GameService _gameService = GameService();
  late GameSession _gameSession;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  bool _isChangingTeam = false;
  DateTime? _lastTeamChangeAttempt;

  // Tracking des joueurs en cours de changement d'équipe
  // Map: playerId -> targetTeamColor
  final Map<String, String> _playersTransitioning = {};

  @override
  void initState() {
    super.initState();
    _gameSession = widget.gameSession;
    _listenToGameSessionUpdates();
    _startAutoRefresh();
    // Faire un refresh immédiat pour afficher l'état actuel
    Future.microtask(() => _refreshSessionOptimized());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _listenToGameSessionUpdates() {
    _gameService.gameSessionStream.listen((gameSession) {
      if (gameSession != null && mounted) {
        setState(() {
          _gameSession = gameSession;
        });
      }
    });
  }

  bool get _isHost {
    final currentPlayer = _gameService.currentPlayer;
    return currentPlayer != null &&
        _gameSession.players.any((player) => 
            player.id == currentPlayer.id && player.isHost == true);
  }

  bool _canStartGame() {
    // Vérifier qu'il y a exactement 2 joueurs par équipe
    final redPlayers = _gameSession.players
        .where((p) => p.color == 'red')
        .length;
    final bluePlayers = _gameSession.players
        .where((p) => p.color == 'blue')
        .length;
    return redPlayers == 2 && bluePlayers == 2 && _isHost;
  }


  Future<void> _startGame() async {
    if (!_canStartGame()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _gameService.startGameSession();
      // La navigation vers l'écran de création de challenges se fera automatiquement
      // via le stream de statut
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Room ${_gameSession.id}'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isHost)
            TextButton.icon(
              onPressed: _canStartGame() && !_isLoading ? _startGame : null,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.play_arrow, color: Colors.white),
              label: Text(
                _isLoading ? 'Démarrage...' : 'Commencer',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: AnimationLimiter(
            child: Column(
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 150),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 20.0,
                  child: FadeInAnimation(child: widget),
                ),
                children: [
                  // Message d'erreur
                  if (_errorMessage != null) ...[
                    _buildErrorMessage(),
                    const SizedBox(height: 16),
                  ],

                  // Code de partie et QR Code
                  _buildGameCodeAndQRCard(),
                  const SizedBox(height: 16),


                  // Équipes en vertical
                  _buildTeamsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: AppTheme.errorColor, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCodeAndQRCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Titre et QR Code sur la même ligne
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section gauche : Titre + Code de la room
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Code de la partie',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _gameSession.id,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Code à partager',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                // QR Code cliquable avec taille fixe
                GestureDetector(
                  onTap: _showQRCodeOverlay,
                  child: Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: _generateJoinLink(),
                      version: QrVersions.auto,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Bouton de partage
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _shareRoom,
                icon: const Icon(Icons.share),
                label: const Text('Partager la room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamsSection() {
    return Column(
      children: [
        // Équipe Rouge (haut)
        _buildTeamCard('Équipe Rouge', 'red', AppTheme.teamRedColor),
        const SizedBox(height: 12),
        // Équipe Bleue (bas)
        _buildTeamCard('Équipe Bleue', 'blue', AppTheme.teamBlueColor),
      ],
    );
  }

  Widget _buildTeamCard(String teamName, String teamColor, Color color) {
    // Joueurs actuellement dans l'équipe (en excluant ceux en transition vers une autre équipe)
    final teamPlayers = _gameSession.players
        .where((p) => p.color == teamColor && !_playersTransitioning.containsKey(p.id))
        .toList();

    // Joueurs en transition VERS cette équipe
    final playersTransitioningToThisTeam = _playersTransitioning.entries
        .where((entry) => entry.value == teamColor)
        .map((entry) {
          // Trouver le joueur dans la session
          return _gameSession.players.firstWhere(
            (p) => p.id == entry.key,
            orElse: () => Player(
              id: entry.key,
              name: 'Chargement...',
              color: teamColor,
              role: null,
              isHost: false,
            ),
          );
        })
        .toList();

    final currentPlayer = _gameService.currentPlayer;
    final isCurrentPlayerInThisTeam =
        currentPlayer != null &&
        teamPlayers.any((p) => p.id == currentPlayer.id);

    // Calculer le compte total (joueurs actuels + en transition)
    final totalCount = teamPlayers.length + playersTransitioningToThisTeam.length;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: currentPlayer != null ? () => _handleTeamClick(teamColor, isCurrentPlayerInThisTeam) : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.05),
                color.withValues(alpha: 0.02),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête de l'équipe avec compteur
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.group,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      teamName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '$totalCount/2',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Liste des slots (2 max)
              ...List.generate(2, (index) {
                // D'abord afficher les joueurs réels
                if (index < teamPlayers.length) {
                  return _buildPlayerSlot(teamPlayers[index], color, isLoading: false);
                }
                // Ensuite les joueurs en transition
                else if (index < totalCount) {
                  final transitionIndex = index - teamPlayers.length;
                  return _buildPlayerSlot(
                    playersTransitioningToThisTeam[transitionIndex],
                    color,
                    isLoading: true,
                  );
                }
                // Enfin les slots vides
                else {
                  return _buildPlayerSlot(null, color, isLoading: false);
                }
              }),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerSlot(Player? player, Color teamColor, {required bool isLoading}) {
    final isCurrentPlayer =
        player != null && _gameService.currentPlayer?.id == player.id;

    // État de chargement : card grisée avec loader
    if (isLoading && player != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey[400]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Avatar avec loader
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Changement en cours...',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            // Icône de chargement
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[500]!),
              ),
            ),
          ],
        ),
      );
    }

    // État normal
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: player != null
            ? (isCurrentPlayer
                  ? teamColor.withValues(alpha: 0.15)
                  : Colors.grey[50])
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: player != null
              ? (isCurrentPlayer ? teamColor : Colors.grey[300]!)
              : Colors.grey[200]!,
          width: isCurrentPlayer ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: player != null ? teamColor : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: player != null
                ? const Icon(Icons.person, color: Colors.white, size: 16)
                : Icon(Icons.person_outline, color: Colors.grey[500], size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player?.name ?? 'Cliquez pour rejoindre',
                  style: TextStyle(
                    fontWeight: isCurrentPlayer
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: player != null
                        ? (isCurrentPlayer ? teamColor : Colors.black87)
                        : Colors.grey[500],
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                // Afficher le rôle si défini
                if (player?.role != null)
                  Row(
                    children: [
                      Icon(
                        player!.role == 'drawer' ? Icons.brush : Icons.search,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        player.role == 'drawer' ? 'Dessinateur' : 'Devineur',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (isCurrentPlayer)
            Icon(Icons.check_circle, color: teamColor, size: 16),
          if (player != null && player.isHost == true)
            const Icon(Icons.star, color: Colors.amber, size: 16),
        ],
      ),
    );
  }

  /// Génère le lien de partage pour rejoindre la room
  String _generateJoinLink() {
    final deepLinkService = DeepLinkService();
    return deepLinkService.generateRoomLink(_gameSession.id);
  }

  /// Partage la room avec la modal native
  void _shareRoom() {
    final deepLinkService = DeepLinkService();
    final joinLink = deepLinkService.generateRoomLink(_gameSession.id);

    final shareText =
        'Rejoignez ma partie Piction.ia.ry ! 🎨\n\n'
        'Code de room: ${_gameSession.id}\n'
        'Lien direct: $joinLink\n\n'
        'Téléchargez l\'app et rejoignez la partie !';

    Share.share(
      shareText,
      subject: 'Invitation Piction.ia.ry - Partie ${_gameSession.id}',
    );
  }

  /// Affiche le QR code en grand dans un overlay qui se ferme au clic
  void _showQRCodeOverlay() {
    final deepLinkService = DeepLinkService();
    final joinLink = deepLinkService.generateRoomLink(_gameSession.id);

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: () => overlayEntry.remove(),
        child: Container(
          color: Colors.black.withValues(alpha: 0.8),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Empêcher la fermeture quand on clique sur le QR
              child: Container(
                margin: const EdgeInsets.all(40),
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'QR Code de la partie',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: QrImageView(
                        data: joinLink,
                        version: QrVersions.auto,
                        size: 250.0,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Code: ${_gameSession.id}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scannez ce QR code pour rejoindre la partie',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cliquez n\'importe où pour fermer',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
  }

  Future<void> _handleTeamClick(String teamColor, bool isCurrentPlayerInThisTeam) async {
    final currentPlayer = _gameService.currentPlayer;
    if (currentPlayer == null) return;

    // Debounce: ignorer les clics trop rapides (< 300ms)
    final now = DateTime.now();
    if (_lastTeamChangeAttempt != null &&
        now.difference(_lastTeamChangeAttempt!).inMilliseconds < 300) {
      return;
    }
    _lastTeamChangeAttempt = now;

    // Si un changement est déjà en cours, ignorer
    if (_isChangingTeam) return;

    try {
      setState(() => _isChangingTeam = true);

      if (isCurrentPlayerInThisTeam) {
        final otherTeamColor = teamColor == 'red' ? 'blue' : 'red';
        final currentGameSession = _gameService.currentGameSession;
        if (currentGameSession != null) {
          final otherTeamCount = currentGameSession.players
              .where((p) => p.color == otherTeamColor)
              .length;

          if (otherTeamCount >= 2) {
            _showErrorMessage('L\'autre équipe est déjà complète');
            return;
          }
        }

        // Marquer le joueur comme en transition
        setState(() {
          _playersTransitioning[currentPlayer.id] = otherTeamColor;
        });

        await _changeTeam(otherTeamColor);
      } else {
        final currentGameSession = _gameService.currentGameSession;
        if (currentGameSession != null) {
          final targetTeamCount = currentGameSession.players
              .where((p) => p.color == teamColor)
              .length;

          if (targetTeamCount >= 2) {
            _showErrorMessage('Cette équipe est déjà complète');
            return;
          }
        }

        // Marquer le joueur comme en transition
        setState(() {
          _playersTransitioning[currentPlayer.id] = teamColor;
        });

        await _joinTeam(teamColor);
      }
    } catch (e) {
      // En cas d'erreur, retirer de la transition
      if (mounted) {
        setState(() {
          _playersTransitioning.remove(currentPlayer.id);
        });
      }
      _showErrorMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isChangingTeam = false);
      }
    }
  }

  Future<void> _joinTeam(String teamColor) async {
    try {
      final currentPlayer = _gameService.currentPlayer;
      if (currentPlayer == null) return;

      final currentGameSession = _gameService.currentGameSession;
      if (currentGameSession == null) {
        await _gameService.joinGameSession(_gameSession.id, teamColor);
        return;
      }

      final targetTeamCount = currentGameSession.players
          .where((p) => p.color == teamColor)
          .length;

      if (targetTeamCount >= 2) {
        _showErrorMessage('L\'équipe est déjà complète');
        return;
      }

      final currentPlayerInSession = currentGameSession.players
          .where((p) => p.id == currentPlayer.id)
          .firstOrNull;

      if (currentPlayerInSession != null) {
        if (currentPlayerInSession.color != teamColor) {
          await _gameService.changeTeam(teamColor);
        }
      } else {
        await _gameService.joinGameSession(_gameSession.id, teamColor);
      }

      // Le polling auto rafraîchit l'UI
    } catch (e) {
      // Ne pas afficher les erreurs transitoires ou de race condition
      final errorMsg = e.toString().toLowerCase();
      if (!errorMsg.contains('already in') &&
          !errorMsg.contains('connection') &&
          !errorMsg.contains('timeout')) {
        _showErrorMessage(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }


  Future<void> _changeTeam(String newTeamColor) async {
    try {
      // Changement d'équipe rapide, le service gère la gestion des appels
      await _gameService.changeTeam(newTeamColor);
    } catch (e) {
      // Ne pas afficher les erreurs transitoires
      final errorMsg = e.toString().toLowerCase();
      if (!errorMsg.contains('already in') &&
          !errorMsg.contains('connection') &&
          !errorMsg.contains('timeout')) {
        _showErrorMessage(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        _refreshSessionOptimized();
      }
    });
  }

  Future<void> _refreshSessionOptimized() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    try {
      await _gameService.refreshGameSession(_gameSession.id);

      final updatedSession = _gameService.currentGameSession;
      if (updatedSession != null && mounted) {
        // Détecter les transitions complètes
        _detectCompletedTransitions(updatedSession);

        // Ne faire setState que si la session a vraiment changé
        // Comparer les joueurs pour éviter les rebuilds inutiles
        final hasChanged = _hasSessionChanged(_gameSession, updatedSession);

        if (hasChanged) {
          setState(() {
            _gameSession = updatedSession;
          });
        } else {
          // Mise à jour silencieuse sans rebuild
          _gameSession = updatedSession;
        }
      }
    } catch (e) {
      // Erreur silencieuse, le prochain refresh réessaiera
    } finally {
      _isRefreshing = false;
    }
  }

  /// Détecte les transitions complètes et retire les joueurs de _playersTransitioning
  void _detectCompletedTransitions(GameSession updatedSession) {
    final completedTransitions = <String>[];

    for (final entry in _playersTransitioning.entries) {
      final playerId = entry.key;
      final targetColor = entry.value;

      // Chercher le joueur dans la nouvelle session
      final player = updatedSession.players
          .where((p) => p.id == playerId)
          .firstOrNull;

      // Si le joueur est maintenant dans l'équipe cible, la transition est complète
      if (player != null && player.color == targetColor) {
        completedTransitions.add(playerId);
      }
    }

    // Retirer les transitions complètes
    if (completedTransitions.isNotEmpty) {
      setState(() {
        for (final playerId in completedTransitions) {
          _playersTransitioning.remove(playerId);
        }
      });
    }
  }

  /// Vérifie si la session a vraiment changé (pour éviter les rebuilds inutiles)
  bool _hasSessionChanged(GameSession oldSession, GameSession newSession) {
    // Comparer le nombre de joueurs
    if (oldSession.players.length != newSession.players.length) return true;

    // Comparer les IDs, couleurs et rôles des joueurs
    for (var i = 0; i < oldSession.players.length; i++) {
      final oldPlayer = oldSession.players[i];
      final newPlayer = newSession.players.firstWhere(
        (p) => p.id == oldPlayer.id,
        orElse: () => oldPlayer,
      );

      if (oldPlayer.id != newPlayer.id ||
          oldPlayer.color != newPlayer.color ||
          oldPlayer.role != newPlayer.role ||
          oldPlayer.name != newPlayer.name) {
        return true;
      }
    }

    // Comparer le statut
    if (oldSession.status != newSession.status) return true;

    return false;
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}
