import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import '../di/locator.dart';
import '../interfaces/facades/session_facade_interface.dart';
import '../models/game_session.dart';
import '../widgets/share_qr_widget.dart';
import 'lobby_screen.dart';

/// Écran de création d'une nouvelle room
/// Migré vers Locator (SOLID DIP) - n'utilise plus GameFacade prop drilling
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  GameSession? _createdGameSession;
  bool _isLoading = false;
  String? _errorMessage;

  ISessionFacade get _sessionFacade => Locator.get<ISessionFacade>();

  Future<void> _createRoom() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Créer la session et rejoindre l'équipe rouge
      final gameSession = await _sessionFacade.createGameSession();
      await _sessionFacade.joinGameSession(gameSession.id, 'red');

      // Rafraîchir pour récupérer les joueurs enrichis
      await _sessionFacade.refreshGameSession(gameSession.id);
      final updatedSession = _sessionFacade.currentGameSession;

      if (updatedSession == null) {
        throw Exception('Impossible de récupérer la session');
      }

      if (mounted) {
        setState(() {
          _createdGameSession = updatedSession;
          _isLoading = false;
        });

        // Rediriger immédiatement vers le lobby
        _goToLobby();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _goToLobby() {
    if (_createdGameSession != null) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => LobbyScreen(
            gameSession: _createdGameSession!,
          ),
          transitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_createdGameSession == null ? 'Créer une Room' : 'Partie créée'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: _createdGameSession != null ? [
          TextButton(
            onPressed: _goToLobby,
            child: const Text(
              'Continuer',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ] : null,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _createdGameSession == null 
              ? _buildCreationView()
              : _buildQRShareView(),
          ),
        ),
      ),
    );
  }

  Widget _buildCreationView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Icône et titre
        _buildHeader(),
        const SizedBox(height: 32),
        
        // Message d'erreur
        if (_errorMessage != null) ...[
          _buildErrorMessage(_errorMessage!),
          const SizedBox(height: 24),
        ],
        
        // Bouton de création
        _buildCreateButton(),
        const SizedBox(height: 24),
        
        // Informations sur les rooms
        _buildRoomInfo(),
      ],
    );
  }

  Widget _buildQRShareView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Message de succès
        _buildSuccessHeader(),
        const SizedBox(height: 24),
        
        // Widget QR Code
        ShareQRWidget(
          roomId: _createdGameSession!.id,
          title: 'Partagez votre partie',
          subtitle: 'Invitez vos amis à rejoindre la partie',
        ),
        const SizedBox(height: 24),
        
        // Bouton pour continuer vers le lobby
        _buildContinueButton(),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.add_home_work,
            size: 48,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Créer une Room',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Vous rejoindrez automatiquement la room en tant que joueur',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }


  Widget _buildErrorMessage(String errorMessage) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: AppTheme.errorColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(
                color: AppTheme.errorColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createRoom,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Créer la Room',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildRoomInfo() {
    return Card(
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Comment ça marche ?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoItem('1. Créez votre room', 'Vous rejoignez automatiquement en tant que joueur'),
            _buildInfoItem('2. Partagez le code ou QR code', 'Les 3 autres joueurs peuvent vous rejoindre'),
            _buildInfoItem('3. Attendez 4 joueurs', 'Vous pourrez démarrer la partie une fois complète'),
            _buildInfoItem('4. Choisissez votre équipe', 'Organisez-vous en 2 équipes de 2 joueurs'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 12),
            decoration: BoxDecoration(
              color: Colors.blue[700],
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            size: 48,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Partie créée avec succès !',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Partagez le QR code ci-dessous avec vos amis',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _goToLobby,
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Aller au Lobby'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
