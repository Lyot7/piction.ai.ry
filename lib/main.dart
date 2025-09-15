import 'package:flutter/material.dart';
import 'themes/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/join_room_screen.dart';
import 'services/game_service.dart';
import 'services/deep_link_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialise les services
  await GameService().initialize();
  await DeepLinkService().initialize();
  
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
        '/join': (context) => const JoinRoomScreen(),
      },
      onGenerateRoute: (settings) {
        // Gestion du deep linking pour rejoindre une room
        if (settings.name?.startsWith('/join/') == true) {
          final roomId = settings.name?.split('/').last;
          if (roomId != null && roomId.isNotEmpty) {
            return MaterialPageRoute(
              builder: (context) => JoinRoomScreen(initialRoomId: roomId),
            );
          }
        }
        return null;
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
