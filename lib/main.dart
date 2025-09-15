import 'package:flutter/material.dart';
import 'themes/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
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
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
