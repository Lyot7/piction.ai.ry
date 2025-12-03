import 'service_container.dart';
import 'service_registration.dart';

/// Locator global pour accéder aux services (DIP)
/// Point d'accès unique au conteneur DI
class Locator {
  static final ServiceContainer _container = ServiceContainer();

  /// Initialise tous les services
  static Future<void> initialize() async {
    await ServiceRegistration.registerAll(_container);
  }

  /// Récupère un service du conteneur
  static T get<T>() => _container.get<T>();

  /// Vérifie si un service est enregistré
  static bool isRegistered<T>() => _container.isRegistered<T>();

  /// Réinitialise le conteneur (pour les tests)
  static void reset() => _container.reset();

  /// Accès direct au conteneur (pour cas avancés)
  static ServiceContainer get container => _container;
}
