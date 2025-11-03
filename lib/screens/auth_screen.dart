import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import '../services/game_facade.dart';
import 'join_room_screen.dart';

/// Écran d'authentification (connexion/inscription)
class AuthScreen extends StatefulWidget {
  final GameFacade gameFacade;
  final String? pendingRoomId;
  final VoidCallback? onAuthSuccess;

  const AuthScreen({
    super.key,
    required this.gameFacade,
    this.pendingRoomId,
    this.onAuthSuccess,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Connexion avec juste le nom d'utilisateur
      await widget.gameFacade.loginWithUsername(_nameController.text);

      if (mounted) {
        // Notifier le parent que l'auth a réussi
        if (widget.onAuthSuccess != null) {
          widget.onAuthSuccess!();
        }

        // Si un lien de room est en attente, naviguer vers JoinRoom
        if (widget.pendingRoomId != null) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => JoinRoomScreen(
                gameFacade: widget.gameFacade,
                initialRoomId: widget.pendingRoomId!,
              ),
              transitionDuration: const Duration(milliseconds: 150),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        } else {
          // Sinon, navigation vers l'écran d'accueil
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.1),
              AppTheme.backgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - MediaQuery.of(context).viewInsets.bottom - 48,
                  ),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo et titre
                          _buildHeader(),
                          const SizedBox(height: 48),
                          
                          // Formulaire
                          _buildForm(),
                          const SizedBox(height: 24),
                          
                          // Message d'erreur
                          if (_errorMessage != null) _buildErrorMessage(_errorMessage!),
                          
                          // Bouton d'action
                          _buildActionButton(),
                          
                          // Badge de partie en attente
                          if (widget.pendingRoomId != null) ...[
                            const SizedBox(height: 24),
                            _buildPendingRoomBadge(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Icône du jeu
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
        
        // Titre
        Text(
          'Piction.ia.ry',
          style: AppTheme.lightTheme.textTheme.displayMedium?.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        // Sous-titre avec indication de room si applicable
        Text(
          widget.pendingRoomId != null 
            ? 'Connectez-vous pour rejoindre la partie ${widget.pendingRoomId}'
            : 'Entrez votre nom pour jouer',
          style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
            color: widget.pendingRoomId != null ? AppTheme.primaryColor : AppTheme.textSecondary,
            fontWeight: widget.pendingRoomId != null ? FontWeight.w600 : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Champ nom
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom d\'utilisateur',
                prefixIcon: Icon(Icons.person),
                hintText: 'Entrez votre nom',
              ),
              validator: (value) {
                // Validation simple avant soumission
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer votre nom';
                }
                if (value.length < 3) {
                  return 'Le nom doit contenir au moins 3 caractères';
                }
                return null;
              },
              onChanged: (_) {
                // Réinitialiser l'erreur API quand l'utilisateur modifie le nom
                if (_errorMessage != null) {
                  setState(() {
                    _errorMessage = null;
                  });
                }
              },
            ),
          ],
        ),
      ),
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

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _authenticate,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
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
                'Commencer à jouer',
                style: TextStyle(fontSize: 16),
              ),
      ),
    );
  }

  Widget _buildPendingRoomBadge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.group,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invitation à une partie',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Vous rejoindrez automatiquement la partie ${widget.pendingRoomId} après connexion',
                  style: TextStyle(
                    color: AppTheme.primaryColor.withValues(alpha: 0.8),
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
}
