import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../themes/app_theme.dart';
import '../models/game_session.dart';
import '../models/player.dart';
import '../services/deep_link_service.dart';
import '../viewmodels/lobby_view_model.dart';
import '../viewmodels/viewmodel_factory.dart';
import 'challenge_creation_screen.dart';

/// Écran de lobby pour organiser les équipes (SOLID)
/// Utilise LobbyViewModel pour séparer la logique métier de l'UI (SRP)
/// Migré vers Locator (DIP) - n'utilise plus GameFacade prop drilling
class LobbyScreen extends StatefulWidget {
  final GameSession gameSession;

  const LobbyScreen({
    super.key,
    required this.gameSession,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late final LobbyViewModel _viewModel;
  late final String _cachedJoinLink;
  DateTime? _lastTeamChangeAttempt;

  @override
  void initState() {
    super.initState();
    _viewModel = ViewModelFactory.createLobbyViewModel();
    _cachedJoinLink = _generateJoinLink();
    _viewModel.startPolling();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  String _generateJoinLink() {
    final deepLinkService = DeepLinkService();
    return deepLinkService.generateRoomLink(widget.gameSession.id);
  }

  void _shareRoom() {
    final shareText =
        'Rejoignez ma partie Piction.ia.ry ! 🎨\n\n'
        'Code de room: ${widget.gameSession.id}\n'
        'Lien direct: $_cachedJoinLink\n\n'
        'Téléchargez l\'app et rejoignez la partie !';

    Share.share(
      shareText,
      subject: 'Invitation Piction.ia.ry - Partie ${widget.gameSession.id}',
    );
  }

  Future<void> _startGame() async {
    if (!_viewModel.canStartGame()) return;

    final success = await _viewModel.startGame();
    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ChallengeCreationScreen(),
        ),
      );
    }
  }

  Future<void> _handleTeamClick(String teamColor, bool isCurrentPlayerInThisTeam) async {
    final now = DateTime.now();
    if (_lastTeamChangeAttempt != null &&
        now.difference(_lastTeamChangeAttempt!).inMilliseconds < 300) {
      return;
    }
    _lastTeamChangeAttempt = now;

    await _viewModel.handleTeamClick(teamColor, isCurrentPlayerInThisTeam);
  }

  void _showQRCodeOverlay() {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: () => overlayEntry.remove(),
        child: Container(
          color: Colors.black.withValues(alpha: 0.8),
          child: Center(
            child: GestureDetector(
              onTap: () {},
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
                        data: _cachedJoinLink,
                        version: QrVersions.auto,
                        size: 250.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Code: ${widget.gameSession.id}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scannez ce QR code pour rejoindre la partie',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey[600]),
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        final gameSession = _viewModel.currentGameSession ?? widget.gameSession;

        return Scaffold(
          appBar: AppBar(
            title: Text('Room ${gameSession.id}'),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            actions: [
              if (_viewModel.isHost)
                TextButton.icon(
                  onPressed: _viewModel.canStartGame() && !_viewModel.isLoading
                      ? _startGame
                      : null,
                  icon: _viewModel.isLoading
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
                    _viewModel.isLoading ? 'Démarrage...' : 'Commencer',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_viewModel.errorMessage != null) ...[
                    _buildErrorMessage(),
                    const SizedBox(height: 16),
                  ],
                  _buildGameCodeAndQRCard(gameSession),
                  const SizedBox(height: 16),
                  _buildTeamsSection(gameSession),
                ],
              ),
            ),
          ),
        );
      },
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
              _viewModel.errorMessage!,
              style: TextStyle(color: AppTheme.errorColor, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCodeAndQRCard(GameSession gameSession) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        gameSession.id,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
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
                      data: _cachedJoinLink,
                      version: QrVersions.auto,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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

  Widget _buildTeamsSection(GameSession gameSession) {
    return Column(
      children: [
        _buildTeamCard('Équipe Rouge', 'red', AppTheme.teamRedColor, gameSession),
        const SizedBox(height: 12),
        _buildTeamCard('Équipe Bleue', 'blue', AppTheme.teamBlueColor, gameSession),
      ],
    );
  }

  Widget _buildTeamCard(String teamName, String teamColor, Color color, GameSession gameSession) {
    final teamPlayers = _viewModel.getTeamPlayers(teamColor);
    final isCurrentPlayerInThisTeam = _viewModel.isPlayerInTeam(teamColor);
    final totalCount = teamPlayers.length;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleTeamClick(teamColor, isCurrentPlayerInThisTeam),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
              ...List.generate(2, (index) {
                if (index < teamPlayers.length) {
                  return _buildPlayerSlot(teamPlayers[index], color, gameSession);
                }
                return _buildPlayerSlot(null, color, gameSession);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerSlot(Player? player, Color teamColor, GameSession gameSession) {
    final currentPlayer = _viewModel.currentPlayer;
    final isCurrentPlayer = player != null && currentPlayer?.id == player.id;

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
            child: Text(
              player?.name ?? 'Cliquez pour rejoindre',
              style: TextStyle(
                fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
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
          if (player != null && gameSession.isPlayerHost(player.id))
            const Icon(Icons.star, color: Colors.amber, size: 16),
        ],
      ),
    );
  }
}
