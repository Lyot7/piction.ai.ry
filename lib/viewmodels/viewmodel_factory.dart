import '../di/locator.dart';
import '../interfaces/facades/auth_facade_interface.dart';
import '../interfaces/facades/challenge_facade_interface.dart';
import '../interfaces/facades/game_state_facade_interface.dart';
import '../interfaces/facades/score_facade_interface.dart';
import '../interfaces/facades/session_facade_interface.dart';
import 'game_view_model.dart';
import 'lobby_view_model.dart';

/// Factory pour créer les ViewModels avec leurs dépendances (DIP)
/// Centralise la création des ViewModels en utilisant le DI container
class ViewModelFactory {
  /// Crée une instance de GameViewModel avec toutes ses dépendances
  static GameViewModel createGameViewModel() {
    return GameViewModel(
      sessionFacade: Locator.get<ISessionFacade>(),
      challengeFacade: Locator.get<IChallengeFacade>(),
      gameStateFacade: Locator.get<IGameStateFacade>(),
      scoreFacade: Locator.get<IScoreFacade>(),
    );
  }

  /// Crée une instance de LobbyViewModel avec toutes ses dépendances
  static LobbyViewModel createLobbyViewModel() {
    return LobbyViewModel(
      authFacade: Locator.get<IAuthFacade>(),
      sessionFacade: Locator.get<ISessionFacade>(),
    );
  }
}
