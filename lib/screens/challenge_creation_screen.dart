import 'dart:async';
import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import '../services/game_facade.dart';
import 'game_screen.dart';

/// Écran de création des challenges avant le début du jeu
class ChallengeCreationScreen extends StatefulWidget {
  final GameFacade gameFacade;

  const ChallengeCreationScreen({
    super.key,
    required this.gameFacade,
  });

  @override
  State<ChallengeCreationScreen> createState() => _ChallengeCreationScreenState();
}

class _ChallengeCreationScreenState extends State<ChallengeCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Contrôleurs pour les champs de texte
  final List<List<TextEditingController>> _controllers = [];

  // Contrôleurs pour les sélecteurs
  final List<String> _articles1 = []; // "Un" ou "Une" pour input1
  final List<String> _prepositions = []; // "Sur" ou "Dans"
  final List<String> _articles2 = []; // "Un" ou "Une" pour input2

  @override
  void initState() {
    super.initState();
    // Initialiser les contrôleurs pour 3 challenges (pas 4!)
    for (int i = 0; i < 3; i++) {
      _controllers.add([
        TextEditingController(), // input1 (objet)
        TextEditingController(), // input2 (lieu)
        TextEditingController(), // forbidden1
        TextEditingController(), // forbidden2
        TextEditingController(), // forbidden3
      ]);
      _articles1.add('Un');  // Valeur par défaut
      _prepositions.add('Sur'); // Valeur par défaut
      _articles2.add('Une'); // Valeur par défaut
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
          IconButton(
            onPressed: _autoFillChallenges,
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Pré-remplir (test)',
          ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Instructions
                _buildInstructions(),
                const SizedBox(height: 24),

                // Challenges (3 au lieu de 4)
                ...List.generate(
                  3,
                  (index) => _buildChallengeCard(index),
                ),
              ],
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
              'Créez 3 challenges sous la forme "Un/Une [OBJET] Sur/Dans Un/Une [LIEU]"',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez 3 mots interdits par challenge. Ces challenges seront envoyés à l\'équipe adverse !',
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
        // Challenge principal - Première partie: "Un/Une [OBJET]"
        Text(
          'Objet',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        // Dropdown pour "Un" ou "Une"
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButton<String>(
            value: _articles1[index],
            underline: const SizedBox(),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'Un', child: Text('Un')),
              DropdownMenuItem(value: 'Une', child: Text('Une')),
            ],
            onChanged: (value) {
              setState(() {
                _articles1[index] = value!;
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        // Champ de texte pour l'objet (pleine largeur)
        TextFormField(
          controller: _controllers[index][0],
          decoration: const InputDecoration(
            hintText: 'objet (ex: chat, livre, voiture)...',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value?.isEmpty == true ? 'Requis' : null,
        ),
        const SizedBox(height: 20),

        // Challenge principal - Deuxième partie: "Sur/Dans Un/Une [LIEU]"
        Text(
          'Lieu',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        // Dropdowns pour "Sur/Dans" et "Un/Une" sur la même ligne
        Row(
          children: [
            // Dropdown pour "Sur" ou "Dans"
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<String>(
                  value: _prepositions[index],
                  underline: const SizedBox(),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'Sur', child: Text('Sur')),
                    DropdownMenuItem(value: 'Dans', child: Text('Dans')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _prepositions[index] = value!;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Dropdown pour "Un" ou "Une"
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButton<String>(
                  value: _articles2[index],
                  underline: const SizedBox(),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'Un', child: Text('Un')),
                    DropdownMenuItem(value: 'Une', child: Text('Une')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _articles2[index] = value!;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Champ de texte pour le lieu (pleine largeur)
        TextFormField(
          controller: _controllers[index][1],
          decoration: const InputDecoration(
            hintText: 'lieu (ex: table, maison, jardin)...',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value?.isEmpty == true ? 'Requis' : null,
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

        Column(
          children: [
            for (int i = 0; i < 3; i++) ...[
              TextFormField(
                controller: _controllers[index][2 + i],
                decoration: InputDecoration(
                  hintText: 'Mot interdit ${i + 1}',
                  prefixIcon: Icon(
                    Icons.block,
                    color: AppTheme.errorColor,
                    size: 20,
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty == true ? 'Requis' : null,
              ),
              if (i < 2) const SizedBox(height: 12),
            ],
          ],
        ),
      ],
    );
  }

  bool _canSubmit() {
    for (int i = 0; i < 3; i++) {
      final controllers = _controllers[i];
      if (controllers.length < 5) return false;

      if (controllers[0].text.trim().isEmpty || // input1
          controllers[1].text.trim().isEmpty || // input2
          controllers[2].text.trim().isEmpty || // forbidden1
          controllers[3].text.trim().isEmpty || // forbidden2
          controllers[4].text.trim().isEmpty) { // forbidden3
        return false;
      }
    }
    return true;
  }

  void _autoFillChallenges() {
    setState(() {
      // Challenge 1: Mots très simples et courants
      _articles1[0] = 'Un';
      _prepositions[0] = 'Sur';
      _articles2[0] = 'Une';
      _controllers[0][0].text = 'chat';
      _controllers[0][1].text = 'table';
      _controllers[0][2].text = 'chien';
      _controllers[0][3].text = 'maison';
      _controllers[0][4].text = 'voiture';

      // Challenge 2: Mots basiques
      _articles1[1] = 'Une';
      _prepositions[1] = 'Dans';
      _articles2[1] = 'Un';
      _controllers[1][0].text = 'pomme';
      _controllers[1][1].text = 'jardin';
      _controllers[1][2].text = 'arbre';
      _controllers[1][3].text = 'soleil';
      _controllers[1][4].text = 'fleur';

      // Challenge 3: Mots simples
      _articles1[2] = 'Un';
      _prepositions[2] = 'Sur';
      _articles2[2] = 'Une';
      _controllers[2][0].text = 'livre';
      _controllers[2][1].text = 'chaise';
      _controllers[2][2].text = 'porte';
      _controllers[2][3].text = 'fenetre';
      _controllers[2][4].text = 'lampe';
    });
  }

  Future<void> _submitChallenges() async {
    if (_formKey.currentState?.validate() == true) {
      try {
        final gameService = widget.gameFacade;

        // Envoyer chaque challenge à l'API (3 challenges)
        for (int i = 0; i < 3; i++) {
          final controllers = _controllers[i];
          final forbiddenWords = [
            controllers[2].text.trim(),
            controllers[3].text.trim(),
            controllers[4].text.trim(),
          ];

          await gameService.sendChallenge(
            gameService.currentGameSession!.id, // gameSessionId
            _articles1[i],              // "Un" ou "Une"
            controllers[0].text.trim(), // input1 (objet)
            _prepositions[i],           // "Sur" ou "Dans"
            _articles2[i],              // "Un" ou "Une"
            controllers[1].text.trim(), // input2 (lieu)
            forbiddenWords,             // 3 mots interdits
          );
        }

        // Attendre que tous les joueurs aient envoyé leurs challenges
        // Le backend passe de "challenge" à "playing" automatiquement
        if (mounted) {
          _showWaitingDialog();
          await _waitForGameToStart(gameService);
        }

        // Navigation vers l'écran de jeu
        if (mounted) {
          Navigator.pop(context); // Fermer le dialog
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => GameScreen(
                gameFacade: widget.gameFacade,
              ),
              transitionDuration: const Duration(milliseconds: 150),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // Fermer le dialog si ouvert
          Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst || !route.willHandlePopInternally);

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

  void _showWaitingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WaitingDialog(gameFacade: widget.gameFacade),
    );
  }

  Future<void> _waitForGameToStart(GameFacade gameFacade) async {
    // Écouter le stream du statut pour une redirection temps-réel
    const maxWaitTime = Duration(minutes: 5);
    final startTime = DateTime.now();

    // Créer une completer pour attendre le changement de status
    final completer = Completer<void>();

    // Écouter le stream du status
    late final StreamSubscription<String> statusSubscription;
    statusSubscription = gameFacade.statusStream.listen((status) {
      if (status == 'playing' && !completer.isCompleted) {
        completer.complete();
        statusSubscription.cancel();
      }
    });

    // Polling en parallèle pour rafraîchir régulièrement
    // ignore: unused_local_variable
    final pollingFuture = Future(() async {
      const pollInterval = Duration(seconds: 2);
      while (!completer.isCompleted) {
        try {
          await gameFacade.refreshGameSession(gameFacade.currentGameSession!.id);

          // Vérifier timeout
          if (DateTime.now().difference(startTime) > maxWaitTime) {
            if (!completer.isCompleted) {
              completer.completeError(
                Exception('Timeout: Le jeu n\'a pas démarré après 5 minutes')
              );
            }
            break;
          }

          await Future.delayed(pollInterval);
        } catch (e) {
          // Ignorer les erreurs transitoires
          await Future.delayed(pollInterval);
        }
      }
    });

    try {
      // Attendre que le status passe à "playing" ou timeout
      await completer.future;
    } finally {
      statusSubscription.cancel();
    }
  }
}

/// Widget d'attente avec indicateur de progression
class _WaitingDialog extends StatefulWidget {
  final GameFacade gameFacade;

  const _WaitingDialog({required this.gameFacade});

  @override
  State<_WaitingDialog> createState() => _WaitingDialogState();
}

class _WaitingDialogState extends State<_WaitingDialog> {
  int _totalPlayers = 4;

  @override
  void initState() {
    super.initState();
    _updateProgress();
  }

  Future<void> _updateProgress() async {
    while (mounted) {
      try {
        // Récupérer la session
        await widget.gameFacade.refreshGameSession(
          widget.gameFacade.currentGameSession!.id,
        );

        final session = widget.gameFacade.currentGameSession;
        if (session != null) {
          // Mettre à jour le nombre total de joueurs
          final playerCount = session.players.length;

          // L'API listSessionChallenges() ne fonctionne qu'en mode "finished"
          // Donc on affiche simplement un indicateur d'attente et le nombre
          // de joueurs restants. Le backend change le status à "playing"
          // automatiquement quand tous les joueurs ont fini.

          if (mounted) {
            setState(() {
              _totalPlayers = playerCount;
            });
          }
        }

        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicateur de progression circulaire indéterminé
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    strokeWidth: 10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hourglass_empty,
                      size: 40,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_totalPlayers - 1}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'joueur(s)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Vos challenges sont créés !',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.accentColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'En attente de ${_totalPlayers - 1} autre(s) joueur(s)...',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'La partie démarre automatiquement quand tous les joueurs auront fini',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
