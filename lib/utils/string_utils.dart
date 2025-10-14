/// Utilitaires pour la manipulation de chaînes de caractères
/// Principe SOLID: Single Responsibility - Uniquement les strings
class StringUtils {
  /// Formate un temps en secondes au format MM:SS
  static String formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  /// Capitalise la première lettre d'une chaîne
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Tronque un texte à une longueur maximale avec ellipse
  static String truncate(String text, int maxLength, {String ellipsis = '...'}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  /// Supprime les espaces multiples et trim
  static String normalizeSpaces(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Vérifie si une chaîne contient un mot (insensible à la casse)
  static bool containsWord(String text, String word) {
    final textLower = text.toLowerCase();
    final wordLower = word.toLowerCase();
    return textLower.contains(wordLower);
  }

  /// Vérifie si une chaîne contient l'un des mots d'une liste
  static bool containsAnyWord(String text, List<String> words) {
    return words.any((word) => containsWord(text, word));
  }

  /// Formate un nom d'équipe avec son emoji
  static String formatTeamName(String teamColor) {
    switch (teamColor.toLowerCase()) {
      case 'red':
        return '🔴 Rouge';
      case 'blue':
        return '🔵 Bleue';
      default:
        return teamColor;
    }
  }

  /// Formate un rôle avec son emoji
  static String formatRole(String? role) {
    switch (role?.toLowerCase()) {
      case 'drawer':
        return '🎨 Dessinateur';
      case 'guesser':
        return '🔍 Devineur';
      default:
        return '❓ Non défini';
    }
  }

  /// Formate un statut de jeu
  static String formatGameStatus(String status) {
    switch (status.toLowerCase()) {
      case 'lobby':
        return '⏳ En attente';
      case 'challenge':
        return '📝 Création des challenges';
      case 'playing':
        return '🎮 En cours';
      case 'finished':
        return '🏁 Terminé';
      default:
        return status;
    }
  }

  /// Pluralise un mot en fonction d'un nombre
  static String pluralize(int count, String singular, String plural) {
    return count <= 1 ? singular : plural;
  }

  /// Formate un compteur avec son unité
  static String formatCount(int count, String unit) {
    return '$count ${pluralize(count, unit, "${unit}s")}';
  }
}
