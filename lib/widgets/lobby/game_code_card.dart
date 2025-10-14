import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../themes/app_theme.dart';

/// Widget pour afficher le code de partie et le QR code
/// Principe SOLID: Single Responsibility - Affichage code + QR
class GameCodeCard extends StatelessWidget {
  final String gameSessionId;
  final String joinLink;
  final VoidCallback onQRTap;
  final VoidCallback onShareTap;

  const GameCodeCard({
    super.key,
    required this.gameSessionId,
    required this.joinLink,
    required this.onQRTap,
    required this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Titre et QR Code sur la même ligne
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section gauche : Titre + Code de la room
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Code de la partie',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        gameSessionId,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Code à partager',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // QR Code cliquable avec taille fixe
                GestureDetector(
                  onTap: onQRTap,
                  child: Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: joinLink,
                      version: QrVersions.auto,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bouton de partage
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onShareTap,
                icon: const Icon(Icons.share),
                label: const Text('Partager la room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
