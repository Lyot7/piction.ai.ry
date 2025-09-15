import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

/// Service pour gérer le deep linking
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  /// Initialise le service de deep linking
  Future<void> initialize() async {
    try {
      // Écouter les liens entrants
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          _handleIncomingLink(uri);
        },
        onError: (err) {
          debugPrint('Erreur deep linking: $err');
        },
      );

      // Vérifier s'il y a un lien initial (app lancée via un lien)
      try {
        final Uri? initialUri = await _appLinks.getInitialAppLink();
        if (initialUri != null) {
          _handleIncomingLink(initialUri);
        }
      } catch (e) {
        debugPrint('Erreur récupération lien initial: $e');
      }
    } catch (e) {
      debugPrint('Erreur initialisation deep linking: $e');
    }
  }

  /// Gère les liens entrants
  void _handleIncomingLink(Uri uri) {
    debugPrint('Lien reçu: $uri');
    
    // Extraire l'ID de la room du lien
    String? roomId;
    
    if (uri.scheme == 'pictioniary') {
      // Format: pictioniary://join/ROOM_ID
      if (uri.host == 'join' && uri.pathSegments.isNotEmpty) {
        roomId = uri.pathSegments.first;
      }
    } else if (uri.scheme == 'https') {
      // Format: https://pictioniary.app/join/ROOM_ID
      if (uri.host == 'pictioniary.app' && 
          uri.pathSegments.length >= 2 && 
          uri.pathSegments[0] == 'join') {
        roomId = uri.pathSegments[1];
      }
    }

    if (roomId != null && roomId.isNotEmpty) {
      _navigateToJoinRoom(roomId);
    }
  }

  /// Navigue vers l'écran de rejoindre une room
  void _navigateToJoinRoom(String roomId) {
    // Utiliser le contexte global ou un système de navigation
    // Pour l'instant, on stocke l'ID de la room pour qu'il soit utilisé
    // quand l'utilisateur navigue vers JoinRoomScreen
    _pendingRoomId = roomId;
  }

  String? _pendingRoomId;

  /// Récupère l'ID de room en attente (si l'app a été lancée via un lien)
  String? getPendingRoomId() {
    final roomId = _pendingRoomId;
    _pendingRoomId = null; // Consommer l'ID
    return roomId;
  }

  /// Génère un lien de partage pour une room
  String generateRoomLink(String roomId) {
    return 'https://pictioniary.app/join/$roomId';
  }

  /// Génère un lien de partage court pour une room
  String generateShortRoomLink(String roomId) {
    return 'pictioniary://join/$roomId';
  }

  /// Libère les ressources
  void dispose() {
    _linkSubscription?.cancel();
  }
}
