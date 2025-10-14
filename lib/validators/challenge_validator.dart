/// Validateur pour les formulaires de création de challenges
/// Principe SOLID: Single Responsibility - Uniquement la validation de challenges
class ChallengeValidator {
  /// Valide qu'un champ n'est pas vide
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName requis';
    }
    return null;
  }

  /// Valide un input de challenge (objet ou lieu)
  static String? validateInput(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ce champ est requis';
    }

    if (value.trim().length < 2) {
      return 'Minimum 2 caractères';
    }

    return null;
  }

  /// Valide un mot interdit
  static String? validateForbiddenWord(String? value, int index) {
    if (value == null || value.trim().isEmpty) {
      return 'Mot ${index + 1} requis';
    }

    if (value.trim().length < 2) {
      return 'Minimum 2 caractères';
    }

    return null;
  }

  /// Valide que tous les champs d'un challenge sont remplis
  static bool validateChallengeComplete(
    String? input1,
    String? input2,
    String? forbidden1,
    String? forbidden2,
    String? forbidden3,
  ) {
    return input1 != null && input1.trim().isNotEmpty &&
           input2 != null && input2.trim().isNotEmpty &&
           forbidden1 != null && forbidden1.trim().isNotEmpty &&
           forbidden2 != null && forbidden2.trim().isNotEmpty &&
           forbidden3 != null && forbidden3.trim().isNotEmpty;
  }

  /// Valide que tous les challenges d'un formulaire sont complets
  static bool validateAllChallenges(List<List<String>> challengesData) {
    for (final challengeData in challengesData) {
      if (challengeData.length < 5) return false;

      for (final field in challengeData) {
        if (field.trim().isEmpty) return false;
      }
    }

    return true;
  }

  /// Valide qu'il n'y a pas de doublons dans les mots interdits
  static bool validateNoDuplicateForbiddenWords(
    String word1,
    String word2,
    String word3,
  ) {
    final words = [
      word1.toLowerCase().trim(),
      word2.toLowerCase().trim(),
      word3.toLowerCase().trim(),
    ];

    return words.toSet().length == words.length;
  }

  /// Obtient un message d'erreur pour les doublons
  static String? getDuplicateErrorMessage(
    String word1,
    String word2,
    String word3,
  ) {
    if (!validateNoDuplicateForbiddenWords(word1, word2, word3)) {
      return 'Les mots interdits doivent être différents';
    }
    return null;
  }
}
