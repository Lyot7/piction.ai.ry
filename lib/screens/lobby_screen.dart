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
import '../utils/logger.dart';

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

  @override
  void initState() {
    super.initState();
    _gameSession = widget.gameSession;
    _listenToGameSessionUpdates();
    _startAutoRefresh();
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
                duration: const Duration(milliseconds: 600),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 30.0,
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
        _buildTeamCard('Équipe Rouge', 'red', AppTheme.team1Color),
        const SizedBox(height: 12),
        // Équipe Bleue (bas)
        _buildTeamCard('Équipe Bleue', 'blue', AppTheme.team2Color),
      ],
    );
  }

  Widget _buildTeamCard(String teamName, String teamColor, Color color) {
    final teamPlayers = _gameSession.players
        .where((p) => p.color == teamColor)
        .toList();
    final currentPlayer = _gameService.currentPlayer;
    final isCurrentPlayerInThisTeam =
        currentPlayer != null &&
        teamPlayers.any((p) => p.id == currentPlayer.id);

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
                      '${teamPlayers.length}/2',
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

              // Liste des joueurs (2 slots)
              ...List.generate(2, (index) {
                final player = index < teamPlayers.length
                    ? teamPlayers[index]
                    : null;
                return _buildPlayerSlot(player, color);
              }),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerSlot(Player? player, Color teamColor) {
    final isCurrentPlayer =
        player != null && _gameService.currentPlayer?.id == player.id;

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
                ? Icon(Icons.person, color: Colors.white, size: 16)
                : Icon(Icons.person_outline, color: Colors.grey[500], size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
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
          ),
          if (isCurrentPlayer)
            Icon(Icons.check_circle, color: teamColor, size: 16),
          if (player != null && player.isHost == true)
            Icon(Icons.star, color: Colors.amber, size: 16),
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
    AppLogger.log('[LobbyScreen] 🎯 Clic sur équipe $teamColor (isCurrentPlayer: $isCurrentPlayerInThisTeam)');

    final currentPlayer = _gameService.currentPlayer;
    if (currentPlayer == null) return;

    try {
      if (isCurrentPlayerInThisTeam) {
        // Joueur clique sur sa propre équipe -> changer d'équipe vers l'autre
        final otherTeamColor = teamColor == 'red' ? 'blue' : 'red';
        AppLogger.log('[LobbyScreen] 🔄 Changement vers l\'autre équipe: $otherTeamColor');

        // Vérifier que l'autre équipe n'est pas pleine
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

        await _changeTeam(otherTeamColor);
      } else {
        // Joueur clique sur une autre équipe -> rejoindre cette équipe
        AppLogger.log('[LobbyScreen] 📝 Rejoindre l\'équipe: $teamColor');

        // Vérifier que l'équipe cible n'est pas pleine
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

        await _joinTeam(teamColor);
      }
    } catch (e) {
      AppLogger.error('[LobbyScreen] Erreur lors du clic sur équipe', e);
      _showErrorMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _joinTeam(String teamColor) async {
    try {
      final currentPlayer = _gameService.currentPlayer;
      if (currentPlayer == null) return;

      AppLogger.log('[LobbyScreen] 🎯 Tentative de rejoindre équipe $teamColor');

      // Force une synchronisation complète avec le serveur
      AppLogger.log('[LobbyScreen] 🔄 Synchronisation avec le serveur...');
      await _gameService.forceSyncWithServer();

      // Utiliser la session du service (état le plus récent)
      final currentGameSession = _gameService.currentGameSession;
      if (currentGameSession == null) {
        AppLogger.warning('[LobbyScreen] Aucune session active après sync');
        await _gameService.joinGameSession(_gameSession.id, teamColor);
        return;
      }

      // Vérifier l'équipe cible n'est pas pleine
      final targetTeamCount = currentGameSession.players
          .where((p) => p.color == teamColor)
          .length;

      AppLogger.log('[LobbyScreen] 📊 Équipe $teamColor: $targetTeamCount/2 joueurs');

      if (targetTeamCount >= 2) {
        throw Exception('L\'équipe $teamColor est déjà complète');
      }

      // Vérifier si le joueur est déjà dans la session
      final currentPlayerInSession = currentGameSession.players
          .where((p) => p.id == currentPlayer.id)
          .firstOrNull;

      AppLogger.log('[LobbyScreen] 🔍 Joueur dans session: ${currentPlayerInSession?.id} (couleur: ${currentPlayerInSession?.color})');

      if (currentPlayerInSession != null) {
        // Joueur déjà dans la session
        if (currentPlayerInSession.color != teamColor) {
          AppLogger.log('[LobbyScreen] 🔄 Changement d\'équipe nécessaire');
          await _gameService.changeTeam(teamColor);
        } else {
          AppLogger.success('[LobbyScreen] Déjà dans la bonne équipe');
        }
      } else {
        // Joueur pas dans la session, rejoindre
        AppLogger.log('[LobbyScreen] 📡 Join de la session');
        await _gameService.joinGameSession(_gameSession.id, teamColor);
      }

      AppLogger.success('[LobbyScreen] Rejoindre équipe terminé avec succès');

      // Forcer un refresh immédiat de l'affichage
      await _refreshSessionOptimized();
    } catch (e) {
      AppLogger.error('[LobbyScreen] Erreur lors du join', e);
      _showErrorMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }


  Future<void> _changeTeam(String newTeamColor) async {
    try {
      AppLogger.log('[LobbyScreen] 🔄 Changement vers équipe $newTeamColor');
      await _gameService.changeTeam(newTeamColor);
      AppLogger.success('[LobbyScreen] Changement d\'équipe réussi');

      // Forcer un refresh immédiat de l'affichage
      await _refreshSessionOptimized();
    } catch (e) {
      AppLogger.error('[LobbyScreen] Erreur lors du changement', e);
      _showErrorMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _refreshSessionOptimized();
      }
    });
  }

  Future<void> _refreshSessionOptimized() async {
    if (_isRefreshing) return; // Éviter les rafraîchissements multiples

    _isRefreshing = true;
    try {
      AppLogger.log('[LobbyScreen] 🔄 Rafraîchissement optimisé...');
      await _gameService.refreshGameSession(_gameSession.id);

      final updatedSession = _gameService.currentGameSession;
      if (updatedSession != null && mounted) {
        setState(() {
          _gameSession = updatedSession;
        });
        AppLogger.success('[LobbyScreen] Rafraîchissement terminé');
      }
    } catch (e) {
      AppLogger.error('[LobbyScreen] Erreur lors du rafraîchissement', e);
    } finally {
      _isRefreshing = false;
    }
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
