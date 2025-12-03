/// Conteneur d'injection de dépendances simple (DIP)
/// Permet d'enregistrer et de récupérer des services
class ServiceContainer {
  static final ServiceContainer _instance = ServiceContainer._internal();
  factory ServiceContainer() => _instance;
  ServiceContainer._internal();

  final Map<Type, dynamic> _singletons = {};
  final Map<Type, Function> _factories = {};

  /// Enregistre une instance singleton
  void registerSingleton<T>(T instance) {
    _singletons[T] = instance;
  }

  /// Enregistre une factory (nouvelle instance à chaque appel)
  void registerFactory<T>(T Function() factory) {
    _factories[T] = factory;
  }

  /// Enregistre une factory lazy singleton (créé au premier appel)
  void registerLazySingleton<T>(T Function() factory) {
    _factories[T] = () {
      if (!_singletons.containsKey(T)) {
        _singletons[T] = factory();
      }
      return _singletons[T] as T;
    };
  }

  /// Récupère un service enregistré
  T get<T>() {
    // Vérifier les singletons d'abord
    if (_singletons.containsKey(T)) {
      return _singletons[T] as T;
    }

    // Ensuite les factories
    if (_factories.containsKey(T)) {
      return _factories[T]!() as T;
    }

    throw Exception('Service non enregistré: $T');
  }

  /// Vérifie si un service est enregistré
  bool isRegistered<T>() {
    return _singletons.containsKey(T) || _factories.containsKey(T);
  }

  /// Réinitialise le conteneur (utile pour les tests)
  void reset() {
    _singletons.clear();
    _factories.clear();
  }

  /// Supprime un service spécifique
  void unregister<T>() {
    _singletons.remove(T);
    _factories.remove(T);
  }
}
