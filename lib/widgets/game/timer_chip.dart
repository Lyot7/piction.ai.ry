import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';

/// Widget pour afficher le timer du jeu
/// Principe SOLID: Single Responsibility - Uniquement l'affichage du timer
class TimerChip extends StatelessWidget {
  final int remainingSeconds;

  const TimerChip({
    super.key,
    required this.remainingSeconds,
  });

  String _formatTime() {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Color _getTimerColor() {
    // Rouge si < 60 secondes, sinon couleur normale
    if (remainingSeconds < 60) {
      return AppTheme.errorColor;
    }
    return AppTheme.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        Icons.timer,
        size: 18,
        color: _getTimerColor(),
      ),
      label: Text(
        _formatTime(),
        style: TextStyle(
          color: _getTimerColor(),
          fontWeight: remainingSeconds < 60 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      backgroundColor: remainingSeconds < 60
          ? AppTheme.errorColor.withValues(alpha: 0.1)
          : AppTheme.backgroundColor,
    );
  }
}
