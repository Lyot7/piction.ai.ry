import 'dart:async';
import '../models/player.dart';
import '../models/game_session.dart';
import '../models/challenge.dart';

/// Service pour gérer les streams de l'application
/// Principe SOLID: Single Responsibility - Uniquement les streams
class StreamService {
  // Streams pour notifier les changements
  final StreamController<Player?> _playerController = StreamController<Player?>.broadcast();
  final StreamController<GameSession?> _gameSessionController = StreamController<GameSession?>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();
  final StreamController<List<Challenge>> _challengesController = StreamController<List<Challenge>>.broadcast();

  // Getters pour les streams
  Stream<Player?> get playerStream => _playerController.stream;
  Stream<GameSession?> get gameSessionStream => _gameSessionController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<List<Challenge>> get challengesStream => _challengesController.stream;

  // Méthodes pour émettre des événements
  void emitPlayer(Player? player) {
    if (!_playerController.isClosed) {
      _playerController.add(player);
    }
  }

  void emitGameSession(GameSession? session) {
    if (!_gameSessionController.isClosed) {
      _gameSessionController.add(session);
    }
  }

  void emitStatus(String status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void emitChallenges(List<Challenge> challenges) {
    if (!_challengesController.isClosed) {
      _challengesController.add(challenges);
    }
  }

  /// Nettoie les ressources
  void dispose() {
    _playerController.close();
    _gameSessionController.close();
    _statusController.close();
    _challengesController.close();
  }
}
