import 'dart:async';
import 'package:flutter/material.dart';
import 'themes/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/join_room_screen.dart';
import 'services/game_facade.dart';
import 'services/deep_link_service.dart';
import 'models/player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Créer les services (injection de dépendances)
  final gameFacade = GameFacade();
  final deepLinkService = DeepLinkService();

  // Initialiser les services - mais sans bloquer le démarrage
  try {
    await gameFacade.initialize();
    await deepLinkService.initialize();
  } catch (e) {
    // Continuer même en cas d'erreur d'initialisation
    debugPrint('Erreur initialisation services: $e');
  }

  runApp(PictionApp(
    gameFacade: gameFacade,
    deepLinkService: deepLinkService,
  ));
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
  final GameFacade gameFacade;
  final DeepLinkService deepLinkService;

  const PictionApp({
    super.key,
    required this.gameFacade,
    required this.deepLinkService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Piction.ia.ry',
      theme: AppTheme.lightTheme,
      home: KeyboardDismissWrapper(
        child: AuthWrapper(
          gameFacade: gameFacade,
          deepLinkService: deepLinkService,
        ),
      ),
      debugShowCheckedModeBanner: false,
      routes: {
        '/home': (context) => KeyboardDismissWrapper(
          child: HomeScreen(gameFacade: gameFacade),
        ),
        '/auth': (context) => KeyboardDismissWrapper(
          child: AuthScreen(gameFacade: gameFacade),
        ),
        '/join': (context) => KeyboardDismissWrapper(
          child: JoinRoomScreen(
            gameFacade: gameFacade,
            deepLinkService: deepLinkService,
          ),
        ),
      },
      onGenerateRoute: (settings) {
        // Gestion du deep linking pour rejoindre une room
        if (settings.name?.startsWith('/join/') == true) {
          final roomId = settings.name?.split('/').last;
          if (roomId != null && roomId.isNotEmpty) {
            return MaterialPageRoute(
              builder: (context) => KeyboardDismissWrapper(
                child: JoinRoomScreen(
                  gameFacade: gameFacade,
                  deepLinkService: deepLinkService,
                  initialRoomId: roomId,
                ),
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
  final GameFacade gameFacade;
  final DeepLinkService deepLinkService;

  const AuthWrapper({
    super.key,
    required this.gameFacade,
    required this.deepLinkService,
  });

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _pendingRoomId;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _error;
  late final StreamSubscription<Player?> _playerSubscription;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _checkForPendingRoom();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _playerSubscription = widget.gameFacade.playerStream.listen((player) {
      if (mounted) {
        setState(() {
          _isLoggedIn = player != null;
        });
      }
    });
  }

  @override
  void dispose() {
    _playerSubscription.cancel();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Immediate state update - no artificial delays
      setState(() {
        _isLoggedIn = widget.gameFacade.currentPlayer != null;
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
        final pendingRoomId = widget.deepLinkService.getPendingRoomId();
        
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
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => JoinRoomScreen(
                gameFacade: widget.gameFacade,
                deepLinkService: widget.deepLinkService,
                initialRoomId: roomId,
              ),
              transitionDuration: const Duration(milliseconds: 150),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        });
      }
      return HomeScreen(gameFacade: widget.gameFacade);
    } else {
      // Si pas connecté, montrer l'écran d'auth avec indication du lien en attente
      return AuthScreen(
        gameFacade: widget.gameFacade,
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
