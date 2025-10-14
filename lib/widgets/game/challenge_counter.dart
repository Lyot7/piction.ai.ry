import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';

/// Widget pour afficher le compteur de challenges
/// Principe SOLID: Single Responsibility - Uniquement l'affichage du compteur
class ChallengeCounter extends StatelessWidget {
  final int current;
  final int total;

  const ChallengeCounter({
    super.key,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$current/$total',
        style: TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
