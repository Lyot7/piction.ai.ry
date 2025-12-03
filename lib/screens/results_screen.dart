import 'package:flutter/material.dart';
import '../di/locator.dart';
import '../interfaces/facades/session_facade_interface.dart';
import '../themes/app_theme.dart';
import '../utils/logger.dart';
import 'home_screen.dart';

/// Écran des résultats finaux de la partie
/// Charge les scores dynamiquement depuis le backend
class ResultsScreen extends StatefulWidget {
  /// Scores optionnels passés en paramètre (fallback si backend indisponible)
  final int? initialScoreTeam1;
  final int? initialScoreTeam2;

  const ResultsScreen({
    super.key,
    this.initialScoreTeam1,
    this.initialScoreTeam2,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  int _scoreTeam1 = 100;
  int _scoreTeam2 = 100;
  bool _isLoading = true;
  String? _gameDuration;
  int _challengesCompleted = 0;
  int _totalChallenges = 0;
  int _imagesGenerated = 0;

  ISessionFacade get _sessionFacade => Locator.get<ISessionFacade>();

  @override
  void initState() {
    super.initState();
    _loadFinalScores();
  }

  Future<void> _loadFinalScores() async {
    try {
      // Utiliser les scores passés en paramètre comme fallback initial
      if (widget.initialScoreTeam1 != null) {
        _scoreTeam1 = widget.initialScoreTeam1!;
      }
      if (widget.initialScoreTeam2 != null) {
        _scoreTeam2 = widget.initialScoreTeam2!;
      }

      // Récupérer les scores finaux depuis le backend
      final session = _sessionFacade.currentGameSession;
      if (session != null) {
        AppLogger.info('[ResultsScreen] Fetching final scores from backend...');
        await _sessionFacade.refreshGameSession(session.id);

        final updatedSession = _sessionFacade.currentGameSession;
        if (updatedSession != null) {
          // Récupérer les scores du backend
          final redScore = updatedSession.teamScores['red'];
          final blueScore = updatedSession.teamScores['blue'];

          AppLogger.info('[ResultsScreen] Backend scores - Red: $redScore, Blue: $blueScore');

          if (redScore != null) _scoreTeam1 = redScore;
          if (blueScore != null) _scoreTeam2 = blueScore;

          // Calculer les statistiques
          _calculateStats(updatedSession);
        }
      }
    } catch (e) {
      AppLogger.error('[ResultsScreen] Error loading scores', e);
      // Garder les scores passés en paramètre ou les valeurs par défaut
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _calculateStats(dynamic session) {
    try {
      // Durée de partie
      if (session.startTime != null) {
        final duration = DateTime.now().difference(session.startTime as DateTime);
        final minutes = duration.inMinutes;
        final seconds = duration.inSeconds % 60;
        _gameDuration = '$minutes:${seconds.toString().padLeft(2, '0')}';
      } else {
        _gameDuration = '5:00'; // Durée max par défaut
      }

      // Challenges
      _totalChallenges = session.players.length * 3; // 3 challenges par joueur

      // Compter les challenges terminés et images
      // (approximation basée sur le nombre de joueurs)
      _challengesCompleted = _totalChallenges; // Si on arrive à l'écran résultat, tous sont terminés
      _imagesGenerated = _totalChallenges;
    } catch (e) {
      AppLogger.warning('[ResultsScreen] Could not calculate stats: $e');
      _gameDuration = '5:00';
      _totalChallenges = 12;
      _challengesCompleted = 12;
      _imagesGenerated = 12;
    }
  }

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
              winner == 'Équipe Rouge'
                  ? AppTheme.teamRedColor.withValues(alpha: 0.2)
                  : winner == 'Équipe Bleue'
                      ? AppTheme.teamBlueColor.withValues(alpha: 0.2)
                      : AppTheme.primaryColor.withValues(alpha: 0.1),
              AppTheme.backgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? _buildLoadingState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Icône et titre de fin
                      _buildHeader(winner),
                      const SizedBox(height: 32),

                      // Scores finaux
                      _buildScoresCard(),
                      const SizedBox(height: 24),

                      // Statistiques
                      _buildStatsCard(),
                      const SizedBox(height: 32),

                      // Boutons d'action
                      _buildActionButtons(context),
                      const SizedBox(height: 24), // Padding bottom
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement des résultats...',
            style: TextStyle(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String winner) {
    return Column(
      children: [
        // Icône de célébration ou fin de partie
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: winner == 'Égalité'
                ? AppTheme.primaryColor
                : winner == 'Équipe Rouge'
                    ? AppTheme.teamRedColor
                    : AppTheme.teamBlueColor,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: (winner == 'Égalité'
                        ? AppTheme.primaryColor
                        : winner == 'Équipe Rouge'
                            ? AppTheme.teamRedColor
                            : AppTheme.teamBlueColor)
                    .withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            winner == 'Égalité' ? Icons.handshake : Icons.emoji_events,
            size: 50,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),

        // Titre résultat
        Text(
          winner == 'Égalité' ? 'Égalité !' : '$winner gagne !',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: winner == 'Égalité'
                ? AppTheme.primaryColor
                : winner == 'Équipe Rouge'
                    ? AppTheme.teamRedColor
                    : AppTheme.teamBlueColor,
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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Scores finaux',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                    child: _buildScoreItem(
                        'Équipe Rouge', _scoreTeam1, AppTheme.teamRedColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                    child: _buildScoreItem(
                        'Équipe Bleue', _scoreTeam2, AppTheme.teamBlueColor)),
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
      padding: const EdgeInsets.all(12),
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
              size: 18,
            ),
          Text(
            teamName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: teamColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: teamColor,
            ),
          ),
          Text(
            'points',
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Statistiques',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Statistiques
            _buildStatRow('Durée de partie', _gameDuration ?? '5:00'),
            _buildStatRow('Challenges terminés',
                '$_challengesCompleted/$_totalChallenges'),
            _buildStatRow('Images générées', '$_imagesGenerated'),
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
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
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
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _rematch(context),
            icon: const Icon(Icons.replay, size: 20),
            label: const Text('Rejouer'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Bouton Retour à l'accueil
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => _backToHome(context),
            icon: const Icon(Icons.home, size: 20),
            label: const Text('Retour à l\'accueil'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getWinner() {
    if (_scoreTeam1 > _scoreTeam2) return 'Équipe Rouge';
    if (_scoreTeam2 > _scoreTeam1) return 'Équipe Bleue';
    return 'Égalité';
  }

  void _rematch(BuildContext context) {
    // Retourner au lobby pour une nouvelle partie
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  void _backToHome(BuildContext context) {
    // Retourner à l'accueil
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }
}
