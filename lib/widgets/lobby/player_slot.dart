import 'package:flutter/material.dart';
import '../../models/player.dart';

/// Widget pour afficher un slot de joueur dans une équipe
/// Principe SOLID: Single Responsibility - Affichage d'un slot joueur
/// ✅ SOLID: isHost est passé en paramètre (inversion de dépendance)
class PlayerSlot extends StatelessWidget {
  final Player? player;
  final Color teamColor;
  final bool isCurrentPlayer;
  final bool isLoading;
  final bool isHost; // ✅ SOLID: Reçu depuis le parent qui utilise session.isPlayerHost()

  const PlayerSlot({
    super.key,
    this.player,
    required this.teamColor,
    this.isCurrentPlayer = false,
    this.isLoading = false,
    this.isHost = false,
  });

  @override
  Widget build(BuildContext context) {
    // État de chargement : card grisée avec loader
    if (isLoading && player != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey[400]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player!.name,
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Changement en cours...',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[500]!),
              ),
            ),
          ],
        ),
      );
    }

    // État normal
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: player != null
            ? (isCurrentPlayer
                  ? teamColor.withValues(alpha: 0.15)
                  : Colors.grey[50])
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: player != null
              ? (isCurrentPlayer ? teamColor : Colors.grey[300]!)
              : Colors.grey[200]!,
          width: isCurrentPlayer ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: player != null ? teamColor : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: player != null
                ? const Icon(Icons.person, color: Colors.white, size: 16)
                : Icon(Icons.person_outline, color: Colors.grey[500], size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player?.name ?? 'Cliquez pour rejoindre',
                  style: TextStyle(
                    fontWeight: isCurrentPlayer
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: player != null
                        ? (isCurrentPlayer ? teamColor : Colors.black87)
                        : Colors.grey[500],
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                // Rôle retiré de l'UI (attribution silencieuse pour backend uniquement)
              ],
            ),
          ),
          if (isCurrentPlayer)
            Icon(Icons.check_circle, color: teamColor, size: 16),
          // ✅ SOLID: Utilise le paramètre isHost au lieu de player.isHost
          if (player != null && isHost)
            const Icon(Icons.star, color: Colors.amber, size: 16),
        ],
      ),
    );
  }
}
