import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../themes/app_theme.dart';
import '../models/game_session.dart';
import '../models/player.dart';
import '../services/game_service.dart';
import '../services/deep_link_service.dart';

/// Écran de lobby pour organiser les équipes et commencer la partie
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
  final GameService _gameService = GameService();
  late GameSession _gameSession;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _gameSession = widget.gameSession;
    _listenToGameSessionUpdates();
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
    return currentPlayer != null && _gameSession.players.isNotEmpty && 
           _gameSession.players.any((player) => player.id == currentPlayer.id);
  }

  bool _canStartGame() {
    return _gameSession.players.length == 4 && _isHost;
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
        child: Padding(
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
                  const SizedBox(height: 24),
                  
                  // Statut de la partie
                  _buildGameStatus(),
                  const SizedBox(height: 24),
                  
                  // Liste des joueurs
                  Expanded(
                    child: _buildPlayersList(),
                  ),
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
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppTheme.errorColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: AppTheme.errorColor,
                fontSize: 14,
              ),
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
            Text(
              'Code de la partie',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            
            // Code de la room et QR Code côte à côte
            Row(
              children: [
                // Code de la room
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _gameSession.id,
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
                
                // QR Code
                if (_isHost) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          data: _generateJoinLink(),
                          version: QrVersions.auto,
                          size: 100.0,
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
                        const SizedBox(height: 4),
                        Text(
                          'Scanner',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

  Widget _buildGameStatus() {
    final playersCount = _gameSession.players.length;
    
    return Row(
      children: [
        Expanded(
          child: _buildStatusItem(
            icon: Icons.people,
            label: 'Joueurs',
            value: '$playersCount/4',
            color: playersCount == 4 ? AppTheme.accentColor : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatusItem(
            icon: Icons.schedule,
            label: 'Statut',
            value: _getStatusLabel(_gameSession.status),
            color: _getStatusColor(_gameSession.status),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Joueurs connectés',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_gameSession.players.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'En attente de joueurs...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(4, (index) {
                final player = index < _gameSession.players.length 
                    ? _gameSession.players[index] 
                    : null;
                return _buildPlayerSlot(index, player);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSlot(int index, Player? player) {
    final isCurrentPlayer = player != null && 
        _gameService.currentPlayer?.id == player.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: player != null 
            ? (isCurrentPlayer 
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : Colors.grey[50])
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: player != null 
              ? (isCurrentPlayer 
                  ? AppTheme.primaryColor
                  : Colors.grey[300]!)
              : Colors.grey[200]!,
          width: isCurrentPlayer ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: player != null 
                  ? _getPlayerColor(player.color)
                  : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: player != null
                ? Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  )
                : Icon(
                    Icons.person_outline,
                    color: Colors.grey[500],
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player?.name ?? 'Slot ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: player != null 
                        ? (isCurrentPlayer 
                            ? AppTheme.primaryColor
                            : Colors.black87)
                        : Colors.grey[500],
                  ),
                ),
                if (player != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Équipe ${player.color == 'red' ? 'Rouge' : 'Bleue'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isCurrentPlayer)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Vous',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getPlayerColor(String? color) {
    switch (color) {
      case 'red':
        return AppTheme.team1Color;
      case 'blue':
        return AppTheme.team2Color;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'lobby':
        return 'En attente';
      case 'challenge':
        return 'Création';
      case 'drawing':
        return 'Dessin';
      case 'guessing':
        return 'Devine';
      case 'finished':
        return 'Terminée';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'lobby':
        return Colors.orange;
      case 'challenge':
        return Colors.blue;
      case 'drawing':
        return Colors.purple;
      case 'guessing':
        return Colors.green;
      case 'finished':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  /// Génère le lien de partage pour rejoindre la room
  String _generateJoinLink() {
    final deepLinkService = DeepLinkService();
    return deepLinkService.generateRoomLink(_gameSession.id);
  }

  /// Partage la room avec un lien direct
  void _shareRoom() {
    final deepLinkService = DeepLinkService();
    final joinLink = deepLinkService.generateRoomLink(_gameSession.id);
    
    final shareText = 'Rejoignez ma partie Piction.ia.ry !\n\n'
        'Code de room: ${_gameSession.id}\n'
        'Lien direct: $joinLink\n\n'
        'Téléchargez l\'app et rejoignez la partie !';
    
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Lien de partage copié dans le presse-papiers'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
