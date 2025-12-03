/// Interface pour la facade d'état du jeu (ISP)
/// Responsabilité unique: Gestion de l'état et des transitions de jeu
abstract class IGameStateFacade {
  /// Statut actuel du jeu (lobby, challenge, playing, finished)
  String get currentStatus;

  /// Phase actuelle (drawing/guessing)
  String? get currentPhase;

  /// Vérifie si le jeu est actif
  bool get isGameActive;

  /// Vérifie si le jeu est terminé
  bool get isGameFinished;

  /// Stream du statut du jeu
  Stream<String> get statusStream;

  /// Stream de la phase du jeu
  Stream<String?> get phaseStream;

  /// Récupère le rôle du joueur actuel
  String? getCurrentPlayerRole();

  /// Démarre le jeu
  void startGame();

  /// Remet à l'état lobby
  void resetToLobby();

  /// Synchronise l'état avec la session actuelle
  /// Appelle checkTransitions() pour mettre à jour statusStream/phaseStream
  Future<void> syncWithSession();

  /// Démarre l'écoute automatique des changements de session
  void startAutoSync();

  /// Arrête l'écoute automatique
  void stopAutoSync();
}
