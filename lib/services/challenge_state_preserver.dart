import '../models/challenge.dart';

/// Service pour préserver l'état local des challenges lors des refresh backend
///
/// **Principe SOLID: Single Responsibility**
/// - Responsabilité unique: Gérer la fusion sélective des données local/backend
/// - Garantit que les prompts locaux ne sont JAMAIS écrasés
///
/// **Stratégie de merge:**
/// - Prompts: TOUJOURS préserver la version locale (sauf si null)
/// - ImageUrls: TOUJOURS utiliser la version backend (source de vérité)
/// - Autres champs: Préserver la version locale
class ChallengeStatePreserver {
  /// Merge sélectif entre challenges locaux et backend
  ///
  /// **Règles:**
  /// 1. Pour chaque challenge local, chercher le matching backend par ID
  /// 2. Si trouvé: préserver prompt local + mettre à jour imageUrl backend
  /// 3. Si non trouvé: garder challenge local tel quel
  /// 4. Ne JAMAIS ajouter de nouveaux challenges depuis le backend
  ///
  /// **Résultat:** Liste de challenges avec prompts locaux + imageUrls backend
  List<Challenge> mergeWithBackend({
    required List<Challenge> localChallenges,
    required List<Challenge> backendChallenges,
  }) {
    // Si local est vide, rien à préserver
    if (localChallenges.isEmpty) {
      return [];
    }

    // Si backend est vide, retourner local inchangé
    if (backendChallenges.isEmpty) {
      return List.from(localChallenges);
    }

    // Créer une map des challenges backend pour lookup rapide O(1)
    final backendMap = <String, Challenge>{};
    for (final backendChallenge in backendChallenges) {
      backendMap[backendChallenge.id] = backendChallenge;
    }

    // Merger chaque challenge local avec son équivalent backend
    final mergedChallenges = <Challenge>[];

    for (final localChallenge in localChallenges) {
      final backendChallenge = backendMap[localChallenge.id];

      if (backendChallenge != null) {
        // Challenge trouvé dans backend: merge sélectif
        mergedChallenges.add(
          Challenge(
            id: localChallenge.id,
            gameSessionId: localChallenge.gameSessionId,
            article1: localChallenge.article1,
            input1: localChallenge.input1,
            preposition: localChallenge.preposition,
            article2: localChallenge.article2,
            input2: localChallenge.input2,
            forbiddenWords: localChallenge.forbiddenWords,
            // ✅ CRITIQUE: Préserver prompt local (sauf si null → utiliser backend)
            prompt: localChallenge.prompt ?? backendChallenge.prompt,
            // ✅ CRITIQUE: Utiliser imageUrl backend (source de vérité)
            imageUrl: backendChallenge.imageUrl,
            answer: localChallenge.answer,
            isResolved: backendChallenge.isResolved,
            drawerId: localChallenge.drawerId,
            guesserId: localChallenge.guesserId,
            currentPhase: backendChallenge.currentPhase,
            createdAt: localChallenge.createdAt,
            completedAt: backendChallenge.completedAt,
          ),
        );
      } else {
        // Challenge non trouvé dans backend: garder local tel quel
        mergedChallenges.add(localChallenge);
      }
    }

    return mergedChallenges;
  }

  /// Crée un snapshot (copie profonde) de l'état actuel
  ///
  /// Utilisé pour sauvegarder l'état local avant un refresh backend
  List<Challenge> createSnapshot(List<Challenge> challenges) {
    return challenges.map<Challenge>((challenge) {
      return Challenge(
        id: challenge.id,
        gameSessionId: challenge.gameSessionId,
        article1: challenge.article1,
        input1: challenge.input1,
        preposition: challenge.preposition,
        article2: challenge.article2,
        input2: challenge.input2,
        forbiddenWords: List.from(challenge.forbiddenWords),
        prompt: challenge.prompt,
        imageUrl: challenge.imageUrl,
        answer: challenge.answer,
        isResolved: challenge.isResolved,
        drawerId: challenge.drawerId,
        guesserId: challenge.guesserId,
        currentPhase: challenge.currentPhase,
        createdAt: challenge.createdAt,
        completedAt: challenge.completedAt,
      );
    }).toList();
  }

  /// Restaure un snapshot précédemment sauvegardé
  ///
  /// Retourne une copie du snapshot (pas la référence)
  List<Challenge> restoreFromSnapshot(List<Challenge> snapshot) {
    return createSnapshot(snapshot);
  }
}
