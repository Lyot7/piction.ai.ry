import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../themes/app_theme.dart';
import '../models/challenge.dart' as models;
import '../services/game_service.dart';
import 'game_screen.dart';

/// Écran de création des challenges avant le début du jeu
class ChallengeCreationScreen extends StatefulWidget {
  const ChallengeCreationScreen({super.key});

  @override
  State<ChallengeCreationScreen> createState() => _ChallengeCreationScreenState();
}

class _ChallengeCreationScreenState extends State<ChallengeCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Contrôleurs pour les champs de texte
  final List<List<TextEditingController>> _controllers = [];

  @override
  void initState() {
    super.initState();
    // Initialiser les contrôleurs pour chaque challenge
    for (int i = 0; i < 4; i++) {
      _controllers.add([
        TextEditingController(), // input1
        TextEditingController(), // input2
        TextEditingController(), // forbidden1
        TextEditingController(), // forbidden2
        TextEditingController(), // forbidden3
      ]);
    }
  }

  @override
  void dispose() {
    // Nettoyer les contrôleurs
    for (final controllerGroup in _controllers) {
      for (final controller in controllerGroup) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Création des Challenges'),
        actions: [
          TextButton.icon(
            onPressed: _canSubmit() ? _submitChallenges : null,
            icon: const Icon(Icons.send, color: Colors.white),
            label: const Text(
              'Valider',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: AnimationLimiter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instructions
                  _buildInstructions(),
                  const SizedBox(height: 24),
                  
                  // Challenges
                  ...List.generate(
                    4,
                    (index) => SlideAnimation(
                      verticalOffset: 30.0,
                      child: FadeInAnimation(child: _buildChallengeCard(index)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Instructions',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Créez 4 challenges sous la forme "Un/Une [OBJET] Sur/Dans Un/Une [LIEU]"',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez 3 mots interdits par challenge pour compliquer la tâche !',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '💡 Exemple: "Un chat sur une table" + mots interdits: félin, meubles, bois',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre du challenge
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Challenge ${index + 1}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Formulaire de challenge
              _buildChallengeForm(index),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeForm(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Challenge principal
        Row(
          children: [
            Text(
              'Un/Une',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _controllers[index][0],
                decoration: const InputDecoration(
                  hintText: 'objet...',
                ),
                validator: (value) => value?.isEmpty == true ? 'Requis' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Text(
              'Sur/Dans Un/Une',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _controllers[index][1],
                decoration: const InputDecoration(
                  hintText: 'lieu...',
                ),
                validator: (value) => value?.isEmpty == true ? 'Requis' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Mots interdits
        Text(
          'Mots interdits',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppTheme.errorColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            for (int i = 0; i < 3; i++) ...[
              Expanded(
                child: TextFormField(
                  controller: _controllers[index][2 + i],
                  decoration: InputDecoration(
                    hintText: 'Mot ${i + 1}',
                    prefixIcon: Icon(
                      Icons.block,
                      color: AppTheme.errorColor,
                      size: 16,
                    ),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Requis' : null,
                ),
              ),
              if (i < 2) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  bool _canSubmit() {
    for (int i = 0; i < 4; i++) {
      final controllers = _controllers[i];
      if (controllers.length < 6) return false;
      
      if (controllers[0].text.trim().isEmpty || // firstWord
          controllers[1].text.trim().isEmpty || // secondWord
          controllers[2].text.trim().isEmpty || // thirdWord
          controllers[3].text.trim().isEmpty || // fourthWord
          controllers[4].text.trim().isEmpty || // fifthWord
          controllers[5].text.trim().isEmpty) { // forbiddenWords
        return false;
      }
    }
    return true;
  }

  Future<void> _submitChallenges() async {
    if (_formKey.currentState?.validate() == true) {
      try {
        final gameService = GameService();
        
        // Envoyer chaque challenge à l'API
        for (int i = 0; i < 4; i++) {
          final challenge = _buildChallengeFromForm(i);
          await gameService.sendChallenge(
            challenge.firstWord,
            challenge.secondWord,
            challenge.thirdWord,
            challenge.fourthWord,
            challenge.fifthWord,
            challenge.forbiddenWords,
          );
        }
        
        // Navigation vers l'écran de jeu
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const GameScreen(challenges: []),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'envoi des challenges: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  /// Construit un challenge à partir du formulaire
  models.Challenge _buildChallengeFromForm(int index) {
    final controllers = _controllers[index];
    return models.Challenge(
      id: '', // L'API générera l'ID
      gameSessionId: '', // Sera défini par l'API
      firstWord: controllers[0].text.trim(),
      secondWord: controllers[1].text.trim(),
      thirdWord: controllers[2].text.trim(),
      fourthWord: controllers[3].text.trim(),
      fifthWord: controllers[4].text.trim(),
      forbiddenWords: controllers[5].text.split(',').map((word) => word.trim()).where((word) => word.isNotEmpty).toList(),
    );
  }
}
