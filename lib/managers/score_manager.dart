import 'dart:async';
import '../utils/logger.dart';

/// Manager pour la gestion des scores des équipes
/// Principe SOLID: Single Responsibility - Uniquement les scores
class ScoreManager {
  // Scores par équipe (commence à 100)
  int _redTeamScore = 100;
  int _blueTeamScore = 100;

  int get redTeamScore => _redTeamScore;
  int get blueTeamScore => _blueTeamScore;

  // Stream pour notifier les changements de score
  final StreamController<Map<String, int>> _scoreController =
      StreamController<Map<String, int>>.broadcast();
  Stream<Map<String, int>> get scoreStream => _scoreController.stream;

  /// Initialise les scores à 100 pour chaque équipe
  void initializeScores() {
    _redTeamScore = 100;
    _blueTeamScore = 100;
    _notifyScoreChange();
    AppLogger.info('[ScoreManager] Scores initialisés à 100-100');
  }

  /// Applique un delta de score à l'équipe spécifiée
  void applyScoreDelta(String teamColor, int delta) {
    if (teamColor == 'red') {
      _redTeamScore += delta;
      if (_redTeamScore < 0) _redTeamScore = 0;
    } else if (teamColor == 'blue') {
      _blueTeamScore += delta;
      if (_blueTeamScore < 0) _blueTeamScore = 0;
    }

    _notifyScoreChange();
    AppLogger.info('[ScoreManager] Score $teamColor: delta $delta -> nouveau score: ${teamColor == 'red' ? _redTeamScore : _blueTeamScore}');
  }

  /// Ajoute des points pour une bonne réponse (+25 points)
  void addCorrectAnswerPoints(String teamColor) {
    applyScoreDelta(teamColor, 25);
    AppLogger.success('[ScoreManager] Bonne réponse! +25 points pour équipe $teamColor');
  }

  /// Retire des points pour une mauvaise réponse (-1 point)
  void subtractWrongAnswerPoints(String teamColor) {
    applyScoreDelta(teamColor, -1);
    AppLogger.info('[ScoreManager] Mauvaise réponse. -1 point pour équipe $teamColor');
  }

  /// Retire des points pour une régénération d'image (-10 points)
  void subtractRegenerationPoints(String teamColor) {
    applyScoreDelta(teamColor, -10);
    AppLogger.info('[ScoreManager] Régénération d\'image. -10 points pour équipe $teamColor');
  }

  /// Définit directement le score d'une équipe
  void setTeamScore(String teamColor, int score) {
    if (teamColor == 'red') {
      _redTeamScore = score < 0 ? 0 : score;
    } else if (teamColor == 'blue') {
      _blueTeamScore = score < 0 ? 0 : score;
    }

    _notifyScoreChange();
  }

  /// Obtient le score d'une équipe spécifique
  int getTeamScore(String teamColor) {
    return teamColor == 'red' ? _redTeamScore : _blueTeamScore;
  }

  /// Obtient les scores sous forme de Map
  Map<String, int> getScores() {
    return {
      'red': _redTeamScore,
      'blue': _blueTeamScore,
    };
  }

  /// Détermine l'équipe gagnante
  String? getWinningTeam() {
    if (_redTeamScore > _blueTeamScore) {
      return 'red';
    } else if (_blueTeamScore > _redTeamScore) {
      return 'blue';
    }
    return null; // Égalité
  }

  /// Notifie les listeners du changement de score
  void _notifyScoreChange() {
    _scoreController.add(getScores());
  }

  /// Réinitialise les scores
  void reset() {
    initializeScores();
  }

  /// Nettoie les ressources
  void dispose() {
    _scoreController.close();
  }
}
