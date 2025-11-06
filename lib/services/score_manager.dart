import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// Représente une équipe dans le jeu
enum Team {
  red,
  blue;

  /// Convertit en string pour l'API
  String toApiString() => name;

  /// Crée depuis un string de l'API
  static Team fromString(String value) {
    return Team.values.firstWhere(
      (team) => team.name.toLowerCase() == value.toLowerCase(),
      orElse: () => Team.red,
    );
  }
}

/// Événement de changement de score
class ScoreChangeEvent {
  final Team team;
  final int previousScore;
  final int newScore;
  final int delta;
  final String reason;
  final DateTime timestamp;

  const ScoreChangeEvent({
    required this.team,
    required this.previousScore,
    required this.newScore,
    required this.delta,
    required this.reason,
    required this.timestamp,
  });

  bool get isPositive => delta > 0;
  bool get isNegative => delta < 0;

  @override
  String toString() {
    final sign = delta > 0 ? '+' : '';
    return '[${team.name.toUpperCase()}] $previousScore → $newScore ($sign$delta) - $reason';
  }
}

/// Service responsable de gérer les scores des équipes
///
/// Principe SOLID:
/// - Single Responsibility Principle: UNE responsabilité - gérer les scores
/// - Open/Closed Principle: Extensible via callbacks sans modifier le code
/// - Dependency Inversion Principle: Dépend de callbacks, pas de concrétions
class ScoreManager extends ChangeNotifier {
  /// Score initial pour chaque équipe (règle du jeu: 100 points)
  static const int initialScore = 100;

  /// Scores des équipes
  final Map<Team, int> _scores = {
    Team.red: initialScore,
    Team.blue: initialScore,
  };

  /// Historique des changements de score
  final List<ScoreChangeEvent> _history = [];

  /// Callback optionnel pour les changements de score
  final void Function(ScoreChangeEvent)? onScoreChange;

  ScoreManager({
    this.onScoreChange,
  }) {
    AppLogger.info('[ScoreManager] Initialized with red=$initialScore, blue=$initialScore');
  }

  /// Récupère le score d'une équipe
  int getScore(Team team) => _scores[team] ?? initialScore;

  /// Récupère tous les scores
  Map<Team, int> get scores => Map.unmodifiable(_scores);

  /// Historique des changements (read-only)
  List<ScoreChangeEvent> get history => List.unmodifiable(_history);

  /// Score de l'équipe rouge
  int get redScore => getScore(Team.red);

  /// Score de l'équipe bleue
  int get blueScore => getScore(Team.blue);

  /// Ajoute des points à une équipe
  ///
  /// [team] - L'équipe qui gagne des points
  /// [points] - Nombre de points à ajouter (doit être positif)
  /// [reason] - Raison du gain de points (pour l'historique)
  void addPoints(Team team, int points, {String reason = 'Points ajoutés'}) {
    if (points <= 0) {
      AppLogger.warning('[ScoreManager] Tentative d\'ajouter $points points (doit être positif)');
      return;
    }

    _changeScore(team, points, reason: reason);
  }

  /// Retire des points à une équipe
  ///
  /// [team] - L'équipe qui perd des points
  /// [points] - Nombre de points à retirer (doit être positif)
  /// [reason] - Raison de la perte de points (pour l'historique)
  void subtractPoints(Team team, int points, {String reason = 'Points perdus'}) {
    if (points <= 0) {
      AppLogger.warning('[ScoreManager] Tentative de retirer $points points (doit être positif)');
      return;
    }

    _changeScore(team, -points, reason: reason);
  }

  /// Change le score d'une équipe
  ///
  /// Méthode interne qui gère les changements de score
  void _changeScore(Team team, int delta, {required String reason}) {
    final previousScore = getScore(team);
    final newScore = (previousScore + delta).clamp(0, double.infinity).toInt();

    _scores[team] = newScore;

    final event = ScoreChangeEvent(
      team: team,
      previousScore: previousScore,
      newScore: newScore,
      delta: delta,
      reason: reason,
      timestamp: DateTime.now(),
    );

    _history.add(event);

    final emoji = delta > 0 ? '📈' : '📉';
    AppLogger.info('$emoji [ScoreManager] $event');

    // Notifier les listeners
    onScoreChange?.call(event);
    notifyListeners();
  }

  /// Actions de jeu prédéfinies selon les règles officielles
  ///
  /// Ces méthodes encapsulent la logique métier des points

  /// Mot trouvé: +25 points
  void wordFound(Team team, String word) {
    addPoints(team, 25, reason: 'Mot "$word" trouvé');
  }

  /// Mauvaise réponse: -1 point
  void wrongGuess(Team team) {
    subtractPoints(team, 1, reason: 'Mauvaise réponse');
  }

  /// Régénération d'image: -10 points
  void imageRegenerated(Team team) {
    subtractPoints(team, 10, reason: 'Régénération d\'image');
  }

  /// Challenge complété: bonus de +50 points (INPUT1 + INPUT2)
  ///
  /// Appelé quand les deux mots sont trouvés
  void challengeCompleted(Team team) {
    // Les 50 points sont déjà donnés via 2x wordFound(+25)
    // Cette méthode existe pour la cohérence mais ne fait rien
    AppLogger.success('🎉 [ScoreManager] Challenge complété par ${team.name}!');
  }

  /// Réinitialise les scores au début d'une nouvelle partie
  void reset() {
    _scores[Team.red] = initialScore;
    _scores[Team.blue] = initialScore;
    _history.clear();

    AppLogger.info('[ScoreManager] Scores réinitialisés');
    notifyListeners();
  }

  /// Définit directement le score d'une équipe
  ///
  /// Utile pour synchroniser avec le backend
  void setScore(Team team, int score, {String reason = 'Synchronisation'}) {
    final previousScore = getScore(team);
    final delta = score - previousScore;

    if (delta == 0) {
      return; // Pas de changement
    }

    _changeScore(team, delta, reason: reason);
  }

  /// Synchronise les scores avec les valeurs du backend
  void syncFromApi(Map<String, int> apiScores) {
    for (final entry in apiScores.entries) {
      try {
        final team = Team.fromString(entry.key);
        setScore(team, entry.value, reason: 'Sync API');
      } catch (e) {
        AppLogger.error('[ScoreManager] Erreur sync équipe ${entry.key}', e);
      }
    }
  }

  /// Retourne l'équipe gagnante (ou null si égalité)
  Team? getWinner() {
    if (redScore > blueScore) return Team.red;
    if (blueScore > redScore) return Team.blue;
    return null; // Égalité
  }

  /// Vérifie si une équipe a un score négatif
  bool hasNegativeScore() {
    return redScore < 0 || blueScore < 0;
  }

  /// Récupère les statistiques de la partie
  Map<String, dynamic> getStats() {
    return {
      'redScore': redScore,
      'blueScore': blueScore,
      'winner': getWinner()?.name,
      'totalEvents': _history.length,
      'redEvents': _history.where((e) => e.team == Team.red).length,
      'blueEvents': _history.where((e) => e.team == Team.blue).length,
    };
  }
}
