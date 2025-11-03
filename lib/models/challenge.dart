import 'dart:convert';

/// Modèle pour un challenge
/// Format: "Un/Une [INPUT1] Sur/Dans Un/Une [INPUT2]"
class Challenge {
  final String id;
  final String gameSessionId;

  // Structure du challenge
  final String article1;      // "Un" ou "Une"
  final String input1;         // Premier mot à deviner (objet)
  final String preposition;    // "Sur" ou "Dans"
  final String article2;       // "Un" ou "Une"
  final String input2;         // Deuxième mot à deviner (lieu)

  final List<String> forbiddenWords; // 3 mots interdits

  final String? prompt;        // Prompt écrit par le dessinateur
  final String? imageUrl;      // URL de l'image générée
  final String? answer;        // Réponse du devineur
  final bool? isResolved;      // Si le challenge a été résolu
  final String? drawerId;      // ID du joueur qui dessine
  final String? guesserId;     // ID du joueur qui devine
  final String? currentPhase;  // "waiting_prompt" | "prompt_created" | "image_generated" | "guessing" | "resolved"
  final DateTime? createdAt;
  final DateTime? completedAt;

  const Challenge({
    required this.id,
    required this.gameSessionId,
    required this.article1,
    required this.input1,
    required this.preposition,
    required this.article2,
    required this.input2,
    required this.forbiddenWords,
    this.prompt,
    this.imageUrl,
    this.answer,
    this.isResolved,
    this.drawerId,
    this.guesserId,
    this.currentPhase,
    this.createdAt,
    this.completedAt,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    // Parser forbidden_words qui peut être String, List ou null
    List<String> parseForbiddenWords(dynamic forbiddenWordsField) {
      if (forbiddenWordsField == null) return [];

      if (forbiddenWordsField is List) {
        return forbiddenWordsField.map((word) => word.toString()).toList();
      }

      if (forbiddenWordsField is String) {
        // Si c'est un JSON string, essayer de le parser
        try {
          final decoded = jsonDecode(forbiddenWordsField);
          if (decoded is List) {
            return decoded.map((word) => word.toString()).toList();
          }
        } catch (_) {
          // Si pas JSON, retourner la string comme un seul élément
          return [forbiddenWordsField];
        }
      }

      return [];
    }

    return Challenge(
      id: (json['id'] ?? json['_id'] ?? json['challengeId'] ?? '').toString(),
      gameSessionId: (json['gameSessionId'] ?? json['game_session_id'] ?? '').toString(),
      // Backend renvoie: first_word, second_word, third_word, fourth_word, fifth_word
      article1: json['first_word'] ?? json['article1'] ?? json['article_1'] ?? 'Un',
      input1: json['second_word'] ?? json['input1'] ?? json['input_1'] ?? '',
      preposition: json['third_word'] ?? json['preposition'] ?? 'Sur',
      article2: json['fourth_word'] ?? json['article2'] ?? json['article_2'] ?? 'Une',
      input2: json['fifth_word'] ?? json['input2'] ?? json['input_2'] ?? '',
      forbiddenWords: parseForbiddenWords(json['forbidden_words']),
      prompt: json['prompt'],
      imageUrl: json['imageUrl'] ?? json['image_url'],
      answer: json['answer'],
      isResolved: json['is_resolved'] ?? json['isResolved'],
      drawerId: (json['drawerId'] ?? json['drawer_id'] ?? '').toString(),
      guesserId: (json['guesserId'] ?? json['guesser_id'] ?? '').toString(),
      currentPhase: json['currentPhase'] ?? json['current_phase'],
      createdAt: json['createdAt'] != null || json['created_at'] != null
          ? DateTime.tryParse(json['createdAt'] ?? json['created_at'])
          : null,
      completedAt: json['completedAt'] != null || json['completed_at'] != null
          ? DateTime.tryParse(json['completedAt'] ?? json['completed_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gameSessionId': gameSessionId,
      'article1': article1,
      'input1': input1,
      'preposition': preposition,
      'article2': article2,
      'input2': input2,
      'forbidden_words': forbiddenWords,
      if (prompt != null) 'prompt': prompt,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (answer != null) 'answer': answer,
      if (isResolved != null) 'is_resolved': isResolved,
      if (drawerId != null) 'drawerId': drawerId,
      if (guesserId != null) 'guesserId': guesserId,
      if (currentPhase != null) 'currentPhase': currentPhase,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    };
  }

  Challenge copyWith({
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
      id: id ?? this.id,
      gameSessionId: gameSessionId ?? this.gameSessionId,
      article1: article1 ?? this.article1,
      input1: input1 ?? this.input1,
      preposition: preposition ?? this.preposition,
      article2: article2 ?? this.article2,
      input2: input2 ?? this.input2,
      forbiddenWords: forbiddenWords ?? this.forbiddenWords,
      prompt: prompt ?? this.prompt,
      imageUrl: imageUrl ?? this.imageUrl,
      answer: answer ?? this.answer,
      isResolved: isResolved ?? this.isResolved,
      drawerId: drawerId ?? this.drawerId,
      guesserId: guesserId ?? this.guesserId,
      currentPhase: currentPhase ?? this.currentPhase,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Retourne la phrase complète du challenge
  /// Format: "Un/Une [INPUT1] Sur/Dans Un/Une [INPUT2]"
  String get fullPhrase => '$article1 $input1 $preposition $article2 $input2';

  /// Retourne les mots à deviner (targets)
  List<String> get targetWords => [input1, input2];

  /// Retourne tous les mots interdits (targets + forbidden)
  List<String> get allForbiddenWords => [...targetWords, ...forbiddenWords];

  /// Vérifie si le challenge a été résolu
  bool get isCompleted => isResolved == true;

  /// Vérifie si le challenge a un prompt (phase drawing)
  bool get hasPrompt => prompt != null && prompt!.isNotEmpty;

  /// Vérifie si le challenge a une image générée
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// Vérifie si un prompt contient des mots interdits
  bool promptContainsForbiddenWords(String promptText) {
    final lowerPrompt = promptText.toLowerCase();
    return allForbiddenWords.any((word) =>
      lowerPrompt.contains(word.toLowerCase())
    );
  }

  @override
  String toString() {
    return 'Challenge(id: $id, phrase: $fullPhrase, phase: $currentPhase, resolved: $isResolved)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Challenge && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
