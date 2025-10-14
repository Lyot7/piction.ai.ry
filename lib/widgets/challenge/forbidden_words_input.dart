import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';

/// Widget pour saisir les 3 mots interdits d'un challenge
/// Principe SOLID: Single Responsibility - Uniquement la saisie des mots interdits
class ForbiddenWordsInput extends StatelessWidget {
  final List<TextEditingController> controllers;
  final String? Function(String?)? validator;

  const ForbiddenWordsInput({
    super.key,
    required this.controllers,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  controller: controllers[i],
                  decoration: InputDecoration(
                    hintText: 'Mot ${i + 1}',
                    prefixIcon: Icon(
                      Icons.block,
                      color: AppTheme.errorColor,
                      size: 16,
                    ),
                  ),
                  validator: validator,
                ),
              ),
              if (i < 2) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}
