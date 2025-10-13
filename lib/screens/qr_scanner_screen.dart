import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../themes/app_theme.dart';

/// Overlay personnalisé pour le scanner QR
class QRScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QRScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(double s) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(cutOutSize);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final mBorderLength =
        borderLength > cutOutSize / 2 + borderWidth ? borderWidthSize / 2 : borderLength;
    final mCutOutSize =
        cutOutSize < width ? cutOutSize : width - borderOffset;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - mCutOutSize / 2 + borderOffset,
      rect.top + height / 2 - mCutOutSize / 2 + borderOffset,
      mCutOutSize - borderOffset * 2,
      mCutOutSize - borderOffset * 2,
    );

    canvas
      ..saveLayer(
        rect,
        backgroundPaint,
      )
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndCorners(
          cutOutRect,
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
        boxPaint,
      )
      ..restore();

    // Top left corner
    canvas.drawPath(
        Path()
          ..moveTo(cutOutRect.left - borderOffset, cutOutRect.top + mBorderLength)
          ..lineTo(cutOutRect.left - borderOffset, cutOutRect.top)
          ..lineTo(cutOutRect.left + mBorderLength, cutOutRect.top),
        borderPaint);

    // Top right corner
    canvas.drawPath(
        Path()
          ..moveTo(cutOutRect.right - mBorderLength, cutOutRect.top)
          ..lineTo(cutOutRect.right + borderOffset, cutOutRect.top)
          ..lineTo(cutOutRect.right + borderOffset, cutOutRect.top + mBorderLength),
        borderPaint);

    // Bottom right corner
    canvas.drawPath(
        Path()
          ..moveTo(cutOutRect.right + borderOffset, cutOutRect.bottom - mBorderLength)
          ..lineTo(cutOutRect.right + borderOffset, cutOutRect.bottom)
          ..lineTo(cutOutRect.right - mBorderLength, cutOutRect.bottom),
        borderPaint);

    // Bottom left corner
    canvas.drawPath(
        Path()
          ..moveTo(cutOutRect.left + mBorderLength, cutOutRect.bottom)
          ..lineTo(cutOutRect.left - borderOffset, cutOutRect.bottom)
          ..lineTo(cutOutRect.left - borderOffset, cutOutRect.bottom - mBorderLength),
        borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QRScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}

/// Écran de scan de QR code pour rejoindre une room
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;
  String? _lastScannedCode;
  String? _permissionError;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _checkCameraPermission() async {
    try {
      // Le controller va automatiquement demander la permission au premier lancement
      await cameraController.start();
    } catch (e) {
      if (mounted) {
        setState(() {
          _permissionError = 'Accès à la caméra refusé. Veuillez autoriser l\'accès dans les Réglages.';
        });
      }
    }
  }

  void _handleQRCode(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code == _lastScannedCode || !_isScanning) return;

    setState(() {
      _isScanning = false;
      _lastScannedCode = code;
    });

    // Extraire l'ID de la room du QR code
    // Le format attendu est : pictioniary://join/ROOM_ID
    String? roomId;
    if (code.startsWith('pictioniary://join/')) {
      roomId = code.substring('pictioniary://join/'.length);
    } else if (code.startsWith('https://pictioniary.app/join/')) {
      roomId = code.substring('https://pictioniary.app/join/'.length);
    } else {
      // Si c'est juste un ID simple
      roomId = code;
    }

    if (roomId.isNotEmpty) {
      Navigator.of(context).pop(roomId);
    } else {
      _showErrorDialog('QR code invalide');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreur'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isScanning = true;
                _lastScannedCode = null;
              });
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  void _toggleFlash() {
    cameraController.toggleTorch();
  }

  void _flipCamera() {
    cameraController.switchCamera();
  }

  Widget _buildScannerOverlay() {
    return Container(
      decoration: ShapeDecoration(
        shape: QRScannerOverlayShape(
          borderColor: AppTheme.primaryColor,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: 250,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: _permissionError == null
            ? [
                IconButton(
                  icon: const Icon(Icons.flash_on),
                  onPressed: _toggleFlash,
                  tooltip: 'Activer/Désactiver le flash',
                ),
                IconButton(
                  icon: const Icon(Icons.flip_camera_ios),
                  onPressed: _flipCamera,
                  tooltip: 'Changer de caméra',
                ),
              ]
            : null,
      ),
      body: Stack(
        children: [
          // Scanner QR (ou message d'erreur si pas de permission)
          if (_permissionError == null)
            MobileScanner(controller: cameraController, onDetect: _handleQRCode)
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _permissionError!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Retourner à l'écran précédent
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Retour'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Overlay personnalisé (uniquement si pas d'erreur)
          if (_permissionError == null) _buildScannerOverlay(),

          // Instructions (uniquement si pas d'erreur)
          if (_permissionError == null)
            Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scannez le QR code d\'une room',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pointez la caméra vers le QR code affiché par le maître du jeu',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Indicateur de scan (uniquement si pas d'erreur)
          if (_isScanning && _permissionError == null)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Recherche...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bouton retour (uniquement si pas d'erreur)
          if (_permissionError == null)
            Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Annuler',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
