/// Enums pour le jeu Piction.ia.ry
///
/// Ces enums remplacent les magic strings utilisées dans toute l'application
/// pour améliorer la type safety et réduire les erreurs.
library;

/// Statut de la session de jeu
enum GameStatus {
  /// En attente de joueurs dans le lobby
  lobby,

  /// Phase de création des challenges
  challenge,

  /// Partie en cours (5 minutes de jeu)
  playing,

  /// Partie terminée
  finished;

  /// Convertit depuis une string (pour API/JSON)
  static GameStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'lobby':
        return GameStatus.lobby;
      case 'challenge':
        return GameStatus.challenge;
      case 'playing':
        return GameStatus.playing;
      case 'finished':
        return GameStatus.finished;
      default:
        throw ArgumentError('Invalid game status: $value');
    }
  }

  /// Convertit vers une string (pour API/JSON)
  String toApiString() {
    switch (this) {
      case GameStatus.lobby:
        return 'lobby';
      case GameStatus.challenge:
        return 'challenge';
      case GameStatus.playing:
        return 'playing';
      case GameStatus.finished:
        return 'finished';
    }
  }

  /// Nom affiché à l'utilisateur
  String get displayName {
    switch (this) {
      case GameStatus.lobby:
        return 'Lobby';
      case GameStatus.challenge:
        return 'Création des défis';
      case GameStatus.playing:
        return 'En jeu';
      case GameStatus.finished:
        return 'Terminé';
    }
  }
}

/// Couleur d'équipe
enum TeamColor {
  /// Équipe rouge
  red,

  /// Équipe bleue
  blue;

  /// Convertit depuis une string (pour API/JSON)
  static TeamColor fromString(String value) {
    switch (value.toLowerCase()) {
      case 'red':
        return TeamColor.red;
      case 'blue':
        return TeamColor.blue;
      default:
        throw ArgumentError('Invalid team color: $value');
    }
  }

  /// Convertit vers une string (pour API/JSON)
  String toApiString() {
    switch (this) {
      case TeamColor.red:
        return 'red';
      case TeamColor.blue:
        return 'blue';
    }
  }

  /// Nom affiché à l'utilisateur
  String get displayName {
    switch (this) {
      case TeamColor.red:
        return 'Rouge';
      case TeamColor.blue:
        return 'Bleue';
    }
  }

  /// Couleur Flutter pour l'UI
  int get colorValue {
    switch (this) {
      case TeamColor.red:
        return 0xFFE53935; // red[600]
      case TeamColor.blue:
        return 0xFF1E88E5; // blue[600]
    }
  }
}

/// Rôle du joueur dans l'équipe
enum PlayerRole {
  /// Dessinateur : écrit le prompt pour générer l'image
  drawer,

  /// Devineur : devine le challenge à partir de l'image
  guesser;

  /// Convertit depuis une string (pour API/JSON)
  static PlayerRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'drawer':
        return PlayerRole.drawer;
      case 'guesser':
        return PlayerRole.guesser;
      default:
        throw ArgumentError('Invalid player role: $value');
    }
  }

  /// Convertit vers une string (pour API/JSON)
  String toApiString() {
    switch (this) {
      case PlayerRole.drawer:
        return 'drawer';
      case PlayerRole.guesser:
        return 'guesser';
    }
  }

  /// Nom affiché à l'utilisateur
  String get displayName {
    switch (this) {
      case PlayerRole.drawer:
        return 'Dessinateur';
      case PlayerRole.guesser:
        return 'Devineur';
    }
  }

  /// Rôle opposé (pour l'inversion des rôles)
  PlayerRole get opposite {
    switch (this) {
      case PlayerRole.drawer:
        return PlayerRole.guesser;
      case PlayerRole.guesser:
        return PlayerRole.drawer;
    }
  }
}

/// Phase de jeu pendant la partie
enum GamePhase {
  /// Phase de dessination: Tous les joueurs génèrent des images
  drawing,

  /// Phase de devination: Les équipes devinent les challenges de leurs coéquipiers
  guessing;

  /// Convertit depuis une string (pour API/JSON)
  static GamePhase fromString(String value) {
    switch (value.toLowerCase()) {
      case 'drawing':
        return GamePhase.drawing;
      case 'guessing':
        return GamePhase.guessing;
      default:
        throw ArgumentError('Invalid game phase: $value');
    }
  }

  /// Convertit vers une string (pour API/JSON)
  String toApiString() {
    switch (this) {
      case GamePhase.drawing:
        return 'drawing';
      case GamePhase.guessing:
        return 'guessing';
    }
  }

  /// Nom affiché à l'utilisateur
  String get displayName {
    switch (this) {
      case GamePhase.drawing:
        return 'Phase de Dessination';
      case GamePhase.guessing:
        return 'Phase de Devination';
    }
  }
}

/// Extensions pour faciliter les conversions
extension GameStatusExtension on String {
  /// Convertit une string en GameStatus
  GameStatus toGameStatus() => GameStatus.fromString(this);
}

extension TeamColorExtension on String {
  /// Convertit une string en TeamColor
  TeamColor toTeamColor() => TeamColor.fromString(this);
}

extension PlayerRoleExtension on String {
  /// Convertit une string en PlayerRole
  PlayerRole toPlayerRole() => PlayerRole.fromString(this);
}

extension GamePhaseExtension on String {
  /// Convertit une string en GamePhase
  GamePhase toGamePhase() => GamePhase.fromString(this);
}
