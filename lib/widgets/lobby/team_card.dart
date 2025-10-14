import 'package:flutter/material.dart';
import '../../models/game_session.dart';
import '../../models/player.dart';
import 'player_slot.dart';

/// Widget pour afficher une carte d'équipe avec ses joueurs
/// Principe SOLID: Single Responsibility - Affichage d'une équipe
class TeamCard extends StatelessWidget {
  final String teamName;
  final String teamColor;
  final Color color;
  final GameSession session;
  final String? currentPlayerId;
  final Map<String, String> playersTransitioning;
  final VoidCallback? onTap;

  const TeamCard({
    super.key,
    required this.teamName,
    required this.teamColor,
    required this.color,
    required this.session,
    this.currentPlayerId,
    this.playersTransitioning = const {},
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Joueurs actuellement dans l'équipe (en excluant ceux en transition)
    final teamPlayers = session.players
        .where((p) => p.color == teamColor && !playersTransitioning.containsKey(p.id))
        .toList();

    // Joueurs en transition VERS cette équipe
    final playersTransitioningToThisTeam = playersTransitioning.entries
        .where((entry) => entry.value == teamColor)
        .map((entry) {
          return session.players.firstWhere(
            (p) => p.id == entry.key,
            orElse: () => Player(
              id: entry.key,
              name: 'Chargement...',
              color: teamColor,
              role: null,
              isHost: false,
            ),
          );
        })
        .toList();

    final totalCount = teamPlayers.length + playersTransitioningToThisTeam.length;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.05),
                color.withValues(alpha: 0.02),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // En-tête de l'équipe avec compteur
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.group,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      teamName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '$totalCount/2',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Liste des slots (2 max)
              ...List.generate(2, (index) {
                // D'abord afficher les joueurs réels
                if (index < teamPlayers.length) {
                  return PlayerSlot(
                    player: teamPlayers[index],
                    teamColor: color,
                    isCurrentPlayer: currentPlayerId != null &&
                        teamPlayers[index].id == currentPlayerId,
                    isLoading: false,
                  );
                }
                // Ensuite les joueurs en transition
                else if (index < totalCount) {
                  final transitionIndex = index - teamPlayers.length;
                  return PlayerSlot(
                    player: playersTransitioningToThisTeam[transitionIndex],
                    teamColor: color,
                    isLoading: true,
                  );
                }
                // Enfin les slots vides
                else {
                  return PlayerSlot(
                    player: null,
                    teamColor: color,
                    isLoading: false,
                  );
                }
              }),
            ],
          ),
        ),
      ),
    );
  }
}
