import '../interfaces/auth_api_interface.dart';
import '../interfaces/challenge_api_interface.dart';
import '../interfaces/facades/auth_facade_interface.dart';
import '../interfaces/facades/challenge_facade_interface.dart';
import '../interfaces/facades/game_state_facade_interface.dart';
import '../interfaces/facades/score_facade_interface.dart';
import '../interfaces/facades/session_facade_interface.dart';
import '../interfaces/facades/timer_facade_interface.dart';
import '../interfaces/http_client_interface.dart';
import '../interfaces/image_api_interface.dart';
import '../interfaces/player_api_interface.dart';
import '../interfaces/session_api_interface.dart';
import '../interfaces/token_storage_interface.dart';
import '../managers/game_state_manager.dart';
import '../managers/role_manager.dart';
import '../managers/score_manager.dart';
import '../managers/team_manager.dart';
import '../managers/timer_manager.dart';
import '../services/api/auth_api_service.dart';
import '../services/api/challenge_api_service.dart';
import '../services/api/image_api_service.dart';
import '../services/api/player_api_service.dart';
import '../services/api/session_api_service.dart';
import '../services/auth/token_service.dart';
import '../services/facades/auth_facade.dart';
import '../services/facades/challenge_facade.dart';
import '../services/facades/game_state_facade.dart';
import '../services/facades/score_facade.dart';
import '../services/facades/session_facade.dart';
import '../services/facades/timer_facade.dart';
import '../services/http/http_service.dart';
import 'service_container.dart';

/// Configuration des services dans le conteneur DI
/// Centralise l'enregistrement de toutes les dépendances
class ServiceRegistration {
  static const String _baseUrl = 'https://pictioniary.wevox.cloud/api';

  /// Enregistre tous les services dans le conteneur
  static Future<void> registerAll(ServiceContainer container) async {
    // 1. Token Storage (Singleton - état partagé)
    final tokenService = TokenService();
    await tokenService.initialize();
    container.registerSingleton<ITokenStorage>(tokenService);

    // 2. HTTP Client (Singleton - réutilisable)
    container.registerLazySingleton<IHttpClient>(
      () => HttpService(
        baseUrl: _baseUrl,
        tokenStorage: container.get<ITokenStorage>(),
      ),
    );

    // 3. Player API (Singleton - cache partagé)
    container.registerLazySingleton<IPlayerApi>(
      () => PlayerApiService(
        httpClient: container.get<IHttpClient>(),
      ),
    );

    // 4. Auth API (Singleton - état d'authentification)
    container.registerLazySingleton<IAuthApi>(
      () => AuthApiService(
        httpClient: container.get<IHttpClient>(),
        tokenStorage: container.get<ITokenStorage>(),
      ),
    );

    // 5. Session API (Singleton - dépend de PlayerApi)
    container.registerLazySingleton<ISessionApi>(
      () => SessionApiService(
        httpClient: container.get<IHttpClient>(),
        playerApi: container.get<IPlayerApi>(),
      ),
    );

    // 6. Challenge API (Singleton)
    container.registerLazySingleton<IChallengeApi>(
      () => ChallengeApiService(
        httpClient: container.get<IHttpClient>(),
      ),
    );

    // 7. Image API (Singleton)
    container.registerLazySingleton<IImageApi>(
      () => ImageApiService(
        httpClient: container.get<IHttpClient>(),
      ),
    );

    // === MANAGERS (SOLID) ===

    // 8. Team Manager (SOLID DIP - utilise ISessionApi)
    container.registerLazySingleton<TeamManager>(
      () => TeamManager(container.get<ISessionApi>()),
    );

    // 9. Role Manager
    container.registerSingleton<RoleManager>(RoleManager());

    // 13. Game State Manager (SOLID DIP - utilise IChallengeApi)
    container.registerLazySingleton<GameStateManager>(
      () => GameStateManager(container.get<IChallengeApi>()),
    );

    // 14. Score Manager
    container.registerSingleton<ScoreManager>(ScoreManager());

    // 15. Timer Manager
    container.registerSingleton<TimerManager>(TimerManager());

    // === FACADES (ISP - Interfaces Ségrégées) ===

    // 16. Auth Facade
    container.registerLazySingleton<IAuthFacade>(
      () => AuthFacade(authApi: container.get<IAuthApi>()),
    );

    // 17. Session Facade
    container.registerLazySingleton<ISessionFacade>(
      () => SessionFacade(
        sessionApi: container.get<ISessionApi>(),
        authFacade: container.get<IAuthFacade>(),
        teamManager: container.get<TeamManager>(),
        roleManager: container.get<RoleManager>(),
      ),
    );

    // 18. Challenge Facade
    container.registerLazySingleton<IChallengeFacade>(
      () => ChallengeFacade(
        challengeApi: container.get<IChallengeApi>(),
        imageApi: container.get<IImageApi>(),
        sessionFacade: container.get<ISessionFacade>(),
      ),
    );

    // 19. Game State Facade
    container.registerLazySingleton<IGameStateFacade>(
      () => GameStateFacade(
        gameStateManager: container.get<GameStateManager>(),
        roleManager: container.get<RoleManager>(),
        authFacade: container.get<IAuthFacade>(),
        sessionFacade: container.get<ISessionFacade>(),
      ),
    );

    // 20. Score Facade
    container.registerLazySingleton<IScoreFacade>(
      () => ScoreFacade(scoreManager: container.get<ScoreManager>()),
    );

    // 21. Timer Facade
    container.registerLazySingleton<ITimerFacade>(
      () => TimerFacade(timerManager: container.get<TimerManager>()),
    );
  }

  /// Réinitialise tous les services (utile pour les tests)
  static void resetAll(ServiceContainer container) {
    container.reset();
  }
}
