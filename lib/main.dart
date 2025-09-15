import 'package:flutter/material.dart';
import 'themes/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'services/game_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialise le service de jeu
  await GameService().initialize();
  
  runApp(const PictionApp());
}

/// Application principale Piction.ia.ry
class PictionApp extends StatelessWidget {
  const PictionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Piction.ia.ry',
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/home': (context) => const HomeScreen(),
        '/auth': (context) => const AuthScreen(),
      },
    );
  }
}

/// Wrapper pour gérer l'authentification
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: GameService().playerStream.map((player) => player != null),
      initialData: GameService().isLoggedIn,
      builder: (context, snapshot) {
        final isLoggedIn = snapshot.data ?? false;
        
        if (isLoggedIn) {
          return const HomeScreen();
        } else {
          return const AuthScreen();
        }
      },
    );
  }
}
