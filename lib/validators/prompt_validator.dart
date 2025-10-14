import '../models/challenge.dart';

/// Validateur pour les prompts de génération d'images
/// Principe SOLID: Single Responsibility - Uniquement la validation de prompts
class PromptValidator {
  /// Valide qu'un prompt ne contient pas de mots interdits
  static bool validate(String prompt, Challenge challenge) {
    if (prompt.trim().isEmpty) {
      return false;
    }

    return !challenge.promptContainsForbiddenWords(prompt);
  }

  /// Vérifie si le prompt est vide
  static bool isEmpty(String prompt) {
    return prompt.trim().isEmpty;
  }

  /// Vérifie si le prompt contient des mots interdits
  static bool containsForbiddenWords(String prompt, Challenge challenge) {
    return challenge.promptContainsForbiddenWords(prompt);
  }

  /// Obtient la liste des mots interdits trouvés dans le prompt
  static List<String> findForbiddenWords(String prompt, Challenge challenge) {
    final promptLower = prompt.toLowerCase();
    final foundWords = <String>[];

    for (final word in challenge.allForbiddenWords) {
      if (promptLower.contains(word.toLowerCase())) {
        foundWords.add(word);
      }
    }

    return foundWords;
  }

  /// Obtient un message d'erreur approprié
  static String? getErrorMessage(String prompt, Challenge challenge) {
    if (isEmpty(prompt)) {
      return 'Le prompt ne peut pas être vide';
    }

    if (containsForbiddenWords(prompt, challenge)) {
      final forbiddenWords = findForbiddenWords(prompt, challenge);
      if (forbiddenWords.length == 1) {
        return 'Le prompt contient un mot interdit : ${forbiddenWords.first}';
      } else {
        return 'Le prompt contient des mots interdits : ${forbiddenWords.join(", ")}';
      }
    }

    return null; // Pas d'erreur
  }
}
