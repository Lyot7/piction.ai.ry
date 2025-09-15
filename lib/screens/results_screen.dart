import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../themes/app_theme.dart';
import 'home_screen.dart';
import 'lobby_screen.dart';

/// Écran des résultats finaux de la partie
class ResultsScreen extends StatelessWidget {
  final int scoreTeam1;
  final int scoreTeam2;

  const ResultsScreen({
    super.key,
    required this.scoreTeam1,
    required this.scoreTeam2,
  });

  @override
  Widget build(BuildContext context) {
    final winner = _getWinner();
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              winner == 'Équipe 1' 
                  ? AppTheme.team1Color.withValues(alpha: 0.2)
                  : winner == 'Équipe 2'
                      ? AppTheme.team2Color.withValues(alpha: 0.2)
                      : AppTheme.primaryColor.withValues(alpha: 0.1),
              AppTheme.backgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AnimationLimiter(
              child: AnimationConfiguration.staggeredList(
                position: 0,
                duration: const Duration(milliseconds: 600),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icône et titre de fin
                    SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(child: _buildHeader(winner)),
                    ),
                    const SizedBox(height: 40),
                    
                    // Scores finaux
                    SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(child: _buildScoresCard()),
                    ),
                    const SizedBox(height: 40),
                    
                    // Statistiques (optional future feature)
                    SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(child: _buildStatsCard()),
                    ),
                    const SizedBox(height: 40),
                    
                    // Boutons d'action
                    SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(child: _buildActionButtons(context)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String winner) {
    return Column(
      children: [
        // Icône de célébration ou fin de partie
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: winner == 'Égalité'
                ? AppTheme.primaryColor
                : winner == 'Équipe 1'
                    ? AppTheme.team1Color
                    : AppTheme.team2Color,
            borderRadius: BorderRadius.circular(60),
            boxShadow: [
              BoxShadow(
                color: (winner == 'Égalité'
                        ? AppTheme.primaryColor
                        : winner == 'Équipe 1'
                            ? AppTheme.team1Color
                            : AppTheme.team2Color)
                    .withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            winner == 'Égalité' ? Icons.handshake : Icons.emoji_events,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        
        // Titre résultat
        Text(
          winner == 'Égalité' ? 'Égalité !' : '$winner gagne !',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: winner == 'Égalité'
                ? AppTheme.primaryColor
                : winner == 'Équipe 1'
                    ? AppTheme.team1Color
                    : AppTheme.team2Color,
          ),
        ),
        const SizedBox(height: 8),
        
        // Sous-titre
        Text(
          winner == 'Égalité' 
              ? 'Belle partie pour tous !' 
              : 'Félicitations !',
          style: const TextStyle(
            fontSize: 16,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildScoresCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Scores finaux',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(child: _buildScoreItem('Équipe 1', scoreTeam1, AppTheme.team1Color)),
                const SizedBox(width: 20),
                Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(child: _buildScoreItem('Équipe 2', scoreTeam2, AppTheme.team2Color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreItem(String teamName, int score, Color teamColor) {
    final isWinner = _getWinner() == teamName;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: teamColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWinner ? teamColor : teamColor.withValues(alpha: 0.3),
          width: isWinner ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          if (isWinner)
            Icon(
              Icons.star,
              color: teamColor,
              size: 20,
            ),
          Text(
            teamName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: teamColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: teamColor,
            ),
          ),
          Text(
            'points',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Statistiques',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Statistiques simples (pourront être étendues)
            _buildStatRow('Durée de partie', '5:00'),
            _buildStatRow('Challenges terminés', '4/4'),
            _buildStatRow('Images générées', '6'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // Bouton Rejouer
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _rematch(context),
            icon: const Icon(Icons.replay),
            label: const Text('Rejouer'),
          ),
        ),
        const SizedBox(height: 16),
        
        // Bouton Retour à l'accueil
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () => _backToHome(context),
            icon: const Icon(Icons.home),
            label: const Text('Retour à l\'accueil'),
          ),
        ),
      ],
    );
  }

  String _getWinner() {
    if (scoreTeam1 > scoreTeam2) return 'Équipe 1';
    if (scoreTeam2 > scoreTeam1) return 'Équipe 2';
    return 'Égalité';
  }

  void _rematch(BuildContext context) {
    // Retourner au lobby pour une nouvelle partie
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LobbyScreen(isHost: true),
      ),
      (route) => false,
    );
  }

  void _backToHome(BuildContext context) {
    // Retourner à l'accueil
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
      (route) => false,
    );
  }
}