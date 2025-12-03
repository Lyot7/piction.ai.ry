/// Interface pour la facade de scores (ISP)
/// Responsabilité unique: Gestion des scores des équipes
abstract class IScoreFacade {
  /// Met à jour le score d'une équipe
  void applyScoreDelta(String teamColor, int delta);

  /// Définit directement le score d'une équipe
  void setTeamScore(String teamColor, int score);

  /// Initialise les scores à 100
  void initializeScores();

  /// Score de l'équipe rouge
  int get redTeamScore;

  /// Score de l'équipe bleue
  int get blueTeamScore;

  /// Stream des scores
  Stream<Map<String, int>> get scoreStream;
}
