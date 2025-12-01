import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../themes/app_theme.dart';

/// Widget réutilisable pour afficher le statut des joueurs en attente
///
/// Affiche:
/// - Nombre de joueurs prêts / total (ex: "3/4 joueurs prêts")
/// - Liste des joueurs avec icône de statut
/// - Animation de progression
class WaitingPlayersCard extends StatelessWidget {
  final List<Player> players;
  final int Function(Player) getPlayerStatus; // 0 = waiting, 1 = ready
  final String readyLabel;
  final String waitingLabel;

  const WaitingPlayersCard({
    super.key,
    required this.players,
    required this.getPlayerStatus,
    this.readyLabel = 'Prêt',
    this.waitingLabel = 'En attente',
  });

  @override
  Widget build(BuildContext context) {
    final readyCount = players.where((p) => getPlayerStatus(p) == 1).length;
    final totalCount = players.length;
    final allReady = readyCount == totalCount;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: allReady ? Colors.green : AppTheme.primaryColor,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec progression
            Row(
              children: [
                Icon(
                  allReady ? Icons.check_circle : Icons.hourglass_empty,
                  color: allReady ? Colors.green : AppTheme.primaryColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allReady ? 'Tous les joueurs sont prêts !' : 'En attente des joueurs...',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: allReady ? Colors.green : AppTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$readyCount/$totalCount joueurs prêts',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Barre de progression
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: totalCount > 0 ? readyCount / totalCount : 0,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  allReady ? Colors.green : AppTheme.primaryColor,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Liste des joueurs
            ...players.map((player) {
              final isReady = getPlayerStatus(player) == 1;
              final statusColor = isReady ? Colors.green : Colors.orange;
              final statusIcon = isReady ? Icons.check_circle : Icons.access_time;
              final statusText = isReady ? readyLabel : waitingLabel;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    // Indicateur de statut animé
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                        boxShadow: !isReady
                            ? [
                                BoxShadow(
                                  color: statusColor.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Avatar de l'équipe
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: player.color == 'red'
                          ? Colors.red.withValues(alpha: 0.2)
                          : Colors.blue.withValues(alpha: 0.2),
                      child: Icon(
                        Icons.person,
                        size: 20,
                        color: player.color == 'red' ? Colors.red : Colors.blue,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Nom du joueur
                    Expanded(
                      child: Text(
                        player.name.isNotEmpty ? player.name : 'Joueur ${player.id}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),

                    // Icône et texte de statut
                    Icon(
                      statusIcon,
                      size: 20,
                      color: statusColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
