import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../themes/app_theme.dart';
import 'game_screen.dart';

/// Écran de création des challenges avant le début du jeu
class ChallengeCreationScreen extends StatefulWidget {
  const ChallengeCreationScreen({super.key});

  @override
  State<ChallengeCreationScreen> createState() => _ChallengeCreationScreenState();
}

class _ChallengeCreationScreenState extends State<ChallengeCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<Challenge> _challenges = List.generate(4, (index) => Challenge());
  
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
                  ...AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 300),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      verticalOffset: 30.0,
                      child: FadeInAnimation(child: widget),
                    ),
                    children: List.generate(
                      4,
                      (index) => _buildChallengeCard(index),
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
      color: AppTheme.primaryColor.withOpacity(0.1),
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
                onChanged: (value) => _challenges[index].input1 = value,
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
                onChanged: (value) => _challenges[index].input2 = value,
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
                  onChanged: (value) {
                    if (i == 0) _challenges[index].forbidden1 = value;
                    if (i == 1) _challenges[index].forbidden2 = value;
                    if (i == 2) _challenges[index].forbidden3 = value;
                  },
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
    return _challenges.every((challenge) => 
      challenge.input1.isNotEmpty &&
      challenge.input2.isNotEmpty &&
      challenge.forbidden1.isNotEmpty &&
      challenge.forbidden2.isNotEmpty &&
      challenge.forbidden3.isNotEmpty
    );
  }

  void _submitChallenges() {
    if (_formKey.currentState?.validate() == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(challenges: _challenges),
        ),
      );
    }
  }
}

/// Modèle pour représenter un challenge
class Challenge {
  String input1 = '';
  String input2 = '';
  String forbidden1 = '';
  String forbidden2 = '';
  String forbidden3 = '';

  bool get isComplete =>
    input1.isNotEmpty &&
    input2.isNotEmpty &&
    forbidden1.isNotEmpty &&
    forbidden2.isNotEmpty &&
    forbidden3.isNotEmpty;

  String get description => 'Un/Une $input1 Sur/Dans Un/Une $input2';
  
  List<String> get forbiddenWords => [forbidden1, forbidden2, forbidden3];

  @override
  String toString() => '$description (Interdits: ${forbiddenWords.join(', ')})';
}