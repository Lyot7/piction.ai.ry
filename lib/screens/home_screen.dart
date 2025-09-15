import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../themes/app_theme.dart';
import 'lobby_screen.dart';

/// Écran d'accueil principal de Piction.ia.ry
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor.withOpacity(0.1),
              AppTheme.backgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: AnimationLimiter(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: AnimationConfiguration.toStaggeredList(
                  duration: const Duration(milliseconds: 500),
                  childAnimationBuilder: (widget) => SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(child: widget),
                  ),
                  children: [
                    // Logo et titre
                    _buildHeader(context),
                    const SizedBox(height: 60),
                    
                    // Boutons principaux
                    _buildMainButtons(context),
                    const SizedBox(height: 40),
                    
                    // Description du jeu
                    _buildGameDescription(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        // Icône du jeu (placeholder pour maintenant)
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.palette,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        
        // Titre principal
        Text(
          'Piction.ia.ry',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        // Sous-titre
        Text(
          'Devinez avec l\'IA générative',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMainButtons(BuildContext context) {
    return Column(
      children: [
        // Bouton Créer une partie
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => _navigateToLobby(context, isHost: true),
            child: const Text('Créer une partie'),
          ),
        ),
        const SizedBox(height: 16),
        
        // Bouton Rejoindre une partie
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () => _navigateToLobby(context, isHost: false),
            child: const Text('Rejoindre une partie'),
          ),
        ),
      ],
    );
  }

  Widget _buildGameDescription() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Comment jouer ?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGameRule('👥', '4 joueurs en 2 équipes'),
            _buildGameRule('🎨', 'Le dessinateur crée un prompt IA'),
            _buildGameRule('🤔', 'Le devineur trouve les mots'),
            _buildGameRule('⏰', '5 minutes par manche'),
            _buildGameRule('🏆', '25 points par mot trouvé'),
          ],
        ),
      ),
    );
  }

  Widget _buildGameRule(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToLobby(BuildContext context, {required bool isHost}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LobbyScreen(isHost: isHost),
      ),
    );
  }
}