import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../themes/app_theme.dart';
import 'challenge_creation_screen.dart';

/// Écran de lobby pour organiser les équipes et commencer la partie
class LobbyScreen extends StatefulWidget {
  final bool isHost;

  const LobbyScreen({
    super.key,
    required this.isHost,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  // Simulation des joueurs connectés
  final List<Player> _players = [
    Player(id: '1', name: 'Vous', isReady: true),
  ];

  // Code de la partie (simulé)
  final String _gameCode = 'ABC123';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lobby'),
        actions: [
          if (widget.isHost)
            TextButton.icon(
              onPressed: _canStartGame() ? _startGame : null,
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: const Text(
                'Commencer',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AnimationLimiter(
            child: AnimationConfiguration.staggeredList(
              position: 0,
              duration: const Duration(milliseconds: 300),
              child: Column(
                children: [
                  // Code de partie
                  SlideAnimation(
                    verticalOffset: 30.0,
                    child: FadeInAnimation(child: _buildGameCodeCard()),
                  ),
                  const SizedBox(height: 24),
                  
                  // Statut de la partie
                  SlideAnimation(
                    verticalOffset: 30.0,
                    child: FadeInAnimation(child: _buildGameStatus()),
                  ),
                  const SizedBox(height: 24),
                  
                  // Équipes
                  Expanded(
                    child: SlideAnimation(
                      verticalOffset: 30.0,
                      child: FadeInAnimation(child: _buildTeams()),
                    ),
                  ),
                  
                  // Bouton d'action
                  SlideAnimation(
                    verticalOffset: 30.0,
                    child: FadeInAnimation(child: _buildActionButton()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameCodeCard() {
    return Card(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Code de la partie',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _gameCode,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: _copyGameCode,
                  icon: const Icon(Icons.copy),
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameStatus() {
    final playersCount = _players.length;
    final readyCount = _players.where((p) => p.isReady).length;
    
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
            icon: Icons.check_circle,
            label: 'Prêts',
            value: '$readyCount/$playersCount',
            color: readyCount == playersCount && playersCount == 4 
                ? AppTheme.accentColor 
                : AppTheme.textSecondary,
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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeams() {
    return Row(
      children: [
        Expanded(child: _buildTeam('Équipe 1', AppTheme.team1Color, 0)),
        const SizedBox(width: 16),
        Expanded(child: _buildTeam('Équipe 2', AppTheme.team2Color, 2)),
      ],
    );
  }

  Widget _buildTeam(String teamName, Color teamColor, int startIndex) {
    final teamPlayers = _players.length > startIndex 
        ? _players.skip(startIndex).take(2).toList() 
        : <Player>[];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: teamColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  teamName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: teamColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Slots de joueurs
            for (int i = 0; i < 2; i++)
              _buildPlayerSlot(
                i < teamPlayers.length ? teamPlayers[i] : null,
                i == 0 ? 'Dessinateur' : 'Devineur',
                i == 0 ? AppTheme.drawerColor : AppTheme.guesserColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSlot(Player? player, String role, Color roleColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: player != null 
            ? roleColor.withValues(alpha: 0.1) 
            : AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: player != null 
              ? roleColor.withValues(alpha: 0.3) 
              : AppTheme.textLight,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: player != null ? roleColor : AppTheme.textLight,
            child: Text(
              player?.name.substring(0, 1).toUpperCase() ?? '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player?.name ?? 'En attente...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: player != null ? AppTheme.textPrimary : AppTheme.textLight,
                  ),
                ),
                Text(
                  role,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: roleColor,
                  ),
                ),
              ],
            ),
          ),
          if (player != null)
            Icon(
              player.isReady ? Icons.check_circle : Icons.schedule,
              color: player.isReady ? AppTheme.accentColor : AppTheme.textSecondary,
              size: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (!widget.isHost) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _toggleReady,
          child: Text(_players.first.isReady ? 'Annuler' : 'Je suis prêt !'),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  bool _canStartGame() {
    return _players.length == 4 && _players.every((p) => p.isReady);
  }

  void _copyGameCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code $_gameCode copié !'),
        backgroundColor: AppTheme.accentColor,
      ),
    );
  }

  void _toggleReady() {
    setState(() {
      _players.first.isReady = !_players.first.isReady;
    });
  }

  void _startGame() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChallengeCreationScreen(),
      ),
    );
  }
}

/// Modèle simple pour représenter un joueur
class Player {
  final String id;
  final String name;
  bool isReady;

  Player({
    required this.id,
    required this.name,
    this.isReady = false,
  });
}