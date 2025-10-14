import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';
import 'challenge_input_row.dart';
import 'forbidden_words_input.dart';

/// Widget pour un formulaire de création de challenge
/// Principe SOLID: Single Responsibility - Un seul formulaire de challenge
class ChallengeForm extends StatelessWidget {
  final int index;
  final String article1;
  final String preposition;
  final String article2;
  final ValueChanged<String?> onArticle1Changed;
  final ValueChanged<String?> onPrepositionChanged;
  final ValueChanged<String?> onArticle2Changed;
  final TextEditingController input1Controller;
  final TextEditingController input2Controller;
  final List<TextEditingController> forbiddenWordControllers;
  final String? Function(String?)? validator;

  const ChallengeForm({
    super.key,
    required this.index,
    required this.article1,
    required this.preposition,
    required this.article2,
    required this.onArticle1Changed,
    required this.onPrepositionChanged,
    required this.onArticle2Changed,
    required this.input1Controller,
    required this.input2Controller,
    required this.forbiddenWordControllers,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
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

              // Challenge principal - Première partie: "Un/Une [OBJET]"
              ChallengeInputRow(
                dropdownValue: article1,
                dropdownItems: const ['Un', 'Une'],
                onDropdownChanged: onArticle1Changed,
                textController: input1Controller,
                hintText: 'objet (ex: chat, livre, voiture)...',
                validator: validator,
              ),
              const SizedBox(height: 16),

              // Challenge principal - Deuxième partie: "Sur/Dans Un/Une [LIEU]"
              Row(
                children: [
                  DropdownButton<String>(
                    value: preposition,
                    items: const [
                      DropdownMenuItem(value: 'Sur', child: Text('Sur')),
                      DropdownMenuItem(value: 'Dans', child: Text('Dans')),
                    ],
                    onChanged: onPrepositionChanged,
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: article2,
                    items: const [
                      DropdownMenuItem(value: 'Un', child: Text('Un')),
                      DropdownMenuItem(value: 'Une', child: Text('Une')),
                    ],
                    onChanged: onArticle2Changed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: input2Controller,
                      decoration: const InputDecoration(
                        hintText: 'lieu (ex: table, maison, jardin)...',
                        border: OutlineInputBorder(),
                      ),
                      validator: validator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Mots interdits
              ForbiddenWordsInput(
                controllers: forbiddenWordControllers,
                validator: validator,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
