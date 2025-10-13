import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';
import '../themes/app_theme.dart';

/// Widget pour afficher un QR code partageable
class ShareQRWidget extends StatelessWidget {
  final String roomId;
  final String title;
  final String subtitle;

  const ShareQRWidget({
    super.key,
    required this.roomId,
    this.title = 'Rejoindre la partie',
    this.subtitle = 'Scannez ce QR code ou partagez le lien',
  });

  String get shareUrl => 'https://pictioniary.app/join/$roomId';
  String get deepLink => 'pictioniary://join/$roomId';

  void _shareRoom() {
    Share.share(
      'Rejoins ma partie Piction.ia.ry ! 🎨\n\n'
      'Lien: $shareUrl\n\n'
      'Ou scanne ce QR code pour rejoindre directement la partie !',
      subject: 'Invitation Piction.ia.ry - Partie $roomId',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titre
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          
          // Sous-titre
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // QR Code interactif
          GestureDetector(
            onTap: _shareRoom,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: PrettyQrView.data(
                data: shareUrl,
                decoration: const PrettyQrDecoration(
                  background: Colors.white,
                  shape: PrettyQrSmoothSymbol(
                    color: AppTheme.primaryColor,
                    roundFactor: 0.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Instructions d'interaction
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.touch_app,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Touchez pour partager',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Room ID pour référence
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                Text(
                  'Code de la partie',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  roomId,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Bouton de partage principal
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _shareRoom,
              icon: const Icon(Icons.share),
              label: const Text('Partager la partie'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}