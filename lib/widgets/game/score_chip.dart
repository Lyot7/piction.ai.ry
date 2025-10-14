import 'package:flutter/material.dart';

/// Widget pour afficher le score d'une équipe
/// Principe SOLID: Single Responsibility - Uniquement l'affichage du score
class ScoreChip extends StatelessWidget {
  final String label;
  final int score;
  final Color color;

  const ScoreChip({
    super.key,
    required this.label,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 8),
      label: Text('$label: $score'),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }
}
