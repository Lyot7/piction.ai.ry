import '../../interfaces/facades/score_facade_interface.dart';
import '../../managers/score_manager.dart';

/// Facade de scores (ISP + SRP)
/// Responsabilité unique: Gestion des scores des équipes
class ScoreFacade implements IScoreFacade {
  final ScoreManager _scoreManager;

  ScoreFacade({required ScoreManager scoreManager})
      : _scoreManager = scoreManager;

  @override
  void applyScoreDelta(String teamColor, int delta) {
    _scoreManager.applyScoreDelta(teamColor, delta);
  }

  @override
  void setTeamScore(String teamColor, int score) {
    _scoreManager.setTeamScore(teamColor, score);
  }

  @override
  void initializeScores() {
    _scoreManager.initializeScores();
  }

  @override
  int get redTeamScore => _scoreManager.redTeamScore;

  @override
  int get blueTeamScore => _scoreManager.blueTeamScore;

  @override
  Stream<Map<String, int>> get scoreStream => _scoreManager.scoreStream;
}
