import 'package:flutter/material.dart';

/// Widget pour une ligne d'input avec dropdown + text field
/// Utilisé pour les challenges (article + input)
/// Principe SOLID: Single Responsibility - Uniquement la ligne d'input
class ChallengeInputRow extends StatelessWidget {
  final String dropdownValue;
  final List<String> dropdownItems;
  final ValueChanged<String?> onDropdownChanged;
  final TextEditingController textController;
  final String hintText;
  final String? Function(String?)? validator;

  const ChallengeInputRow({
    super.key,
    required this.dropdownValue,
    required this.dropdownItems,
    required this.onDropdownChanged,
    required this.textController,
    required this.hintText,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DropdownButton<String>(
          value: dropdownValue,
          items: dropdownItems.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
          onChanged: onDropdownChanged,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: textController,
            decoration: InputDecoration(
              hintText: hintText,
              border: const OutlineInputBorder(),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}
