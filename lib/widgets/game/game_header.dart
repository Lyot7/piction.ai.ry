import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';
import 'timer_chip.dart';
import 'score_chip.dart';
import 'challenge_counter.dart';

/// Widget pour afficher l'en-tête du jeu (timer, scores, compteur)
/// Principe SOLID: Single Responsibility - Uniquement l'en-tête du jeu
class GameHeader extends StatelessWidget {
  final int remainingSeconds;
  final int redTeamScore;
  final int blueTeamScore;
  final int currentChallengeIndex;
  final int totalChallenges;

  const GameHeader({
    super.key,
    required this.remainingSeconds,
    required this.redTeamScore,
    required this.blueTeamScore,
    required this.currentChallengeIndex,
    required this.totalChallenges,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TimerChip(remainingSeconds: remainingSeconds),
        const SizedBox(width: 8),
        ScoreChip(
          label: 'Rouge',
          score: redTeamScore,
          color: AppTheme.teamRedColor,
        ),
        const SizedBox(width: 8),
        ScoreChip(
          label: 'Bleue',
          score: blueTeamScore,
          color: AppTheme.teamBlueColor,
        ),
        const Spacer(),
        ChallengeCounter(
          current: currentChallengeIndex + 1,
          total: totalChallenges,
        ),
      ],
    );
  }
}
