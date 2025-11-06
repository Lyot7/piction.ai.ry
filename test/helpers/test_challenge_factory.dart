import 'package:piction_ai_ry/models/challenge.dart';

/// Factory pour créer des challenges de test facilement
class TestChallengeFactory {
  /// Crée un challenge avec des valeurs par défaut
  static Challenge create({
    String? id,
    String? gameSessionId,
    String? article1,
    String? input1,
    String? preposition,
    String? article2,
    String? input2,
    List<String>? forbiddenWords,
    String? prompt,
    String? imageUrl,
    String? answer,
    bool? isResolved,
    String? drawerId,
    String? guesserId,
    String? currentPhase,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return Challenge(
      id: id ?? '1',
      gameSessionId: gameSessionId ?? 'test-session',
      article1: article1 ?? 'Un',
      input1: input1 ?? 'chat',
      preposition: preposition ?? 'Sur',
      article2: article2 ?? 'Une',
      input2: input2 ?? 'table',
      forbiddenWords: forbiddenWords ?? const ['minou', 'meuble', 'bois'],
      prompt: prompt,
      imageUrl: imageUrl,
      answer: answer,
      isResolved: isResolved,
      drawerId: drawerId,
      guesserId: guesserId,
      currentPhase: currentPhase,
      createdAt: createdAt,
      completedAt: completedAt,
    );
  }

  /// Crée une liste de challenges de test
  static List<Challenge> createList(int count) {
    return List.generate(
      count,
      (i) => create(
        id: '$i',
        input1: 'input$i',
        input2: 'output$i',
      ),
    );
  }

  /// Crée un challenge avec une image
  static Challenge withImage({
    String? id,
    String? imageUrl,
  }) {
    return create(
      id: id ?? '1',
      imageUrl: imageUrl ?? 'https://example.com/image1.png',
    );
  }

  /// Crée un challenge résolu
  static Challenge resolved({
    String? id,
    String? answer,
  }) {
    return create(
      id: id ?? '1',
      imageUrl: 'https://example.com/image.png',
      answer: answer ?? 'correct answer',
      isResolved: true,
      currentPhase: 'resolved',
    );
  }
}
