import 'package:flutter/material.dart';
import 'themes/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/join_room_screen.dart';
import 'services/game_service.dart';
import 'services/deep_link_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser les services - mais sans bloquer le démarrage
  try {
    await GameService().initialize();
    await DeepLinkService().initialize();
  } catch (e) {
    // Continuer même en cas d'erreur d'initialisation
    debugPrint('Erreur initialisation services: $e');
  }
  
  runApp(const PictionApp());
}

/// Wrapper pour fermer le clavier en tapant en dehors
class KeyboardDismissWrapper extends StatelessWidget {
  final Widget child;
  
  const KeyboardDismissWrapper({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: child,
    );
  }
}

/// Application principale Piction.ia.ry
class PictionApp extends StatelessWidget {
  const PictionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Piction.ia.ry',
      theme: AppTheme.lightTheme,
      home: const KeyboardDismissWrapper(child: AuthWrapper()),
      debugShowCheckedModeBanner: false,
      routes: {
        '/home': (context) => const KeyboardDismissWrapper(child: HomeScreen()),
        '/auth': (context) => const KeyboardDismissWrapper(child: AuthScreen()),
        '/join': (context) => const KeyboardDismissWrapper(child: JoinRoomScreen()),
      },
      onGenerateRoute: (settings) {
        // Gestion du deep linking pour rejoindre une room
        if (settings.name?.startsWith('/join/') == true) {
          final roomId = settings.name?.split('/').last;
          if (roomId != null && roomId.isNotEmpty) {
            return MaterialPageRoute(
              builder: (context) => KeyboardDismissWrapper(
                child: JoinRoomScreen(initialRoomId: roomId),
              ),
            );
          }
        }
        return null;
      },
    );
  }
}

/// Wrapper pour gérer l'authentification
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _pendingRoomId;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _error;
  late GameService _gameService;

  @override
  void initState() {
    super.initState();
    _gameService = GameService();
    _checkAuthStatus();
    _checkForPendingRoom();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _gameService.playerStream.listen((player) {
      if (mounted) {
        setState(() {
          _isLoggedIn = player != null;
        });
      }
    });
  }

  Future<void> _checkAuthStatus() async {
    try {
      setState(() {
        _isLoggedIn = _gameService.isLoggedIn;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _checkForPendingRoom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final deepLinkService = DeepLinkService();
        final pendingRoomId = deepLinkService.getPendingRoomId();
        
        if (pendingRoomId != null) {
          setState(() {
            _pendingRoomId = pendingRoomId;
          });
        }
      } catch (e) {
        // Ignore les erreurs de deep linking
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Erreur: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isLoading = true;
                  });
                  _checkAuthStatus();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoggedIn) {
      // Si connecté et qu'il y a un roomId en attente, naviguer vers JoinRoom
      if (_pendingRoomId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final roomId = _pendingRoomId!;
          setState(() {
            _pendingRoomId = null;
          });
          
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => JoinRoomScreen(initialRoomId: roomId),
            ),
          );
        });
      }
      return const HomeScreen();
    } else {
      // Si pas connecté, montrer l'écran d'auth avec indication du lien en attente
      return AuthScreen(
        pendingRoomId: _pendingRoomId,
        onAuthSuccess: () {
          setState(() {
            _isLoggedIn = true;
          });
        },
      );
    }
  }
}
