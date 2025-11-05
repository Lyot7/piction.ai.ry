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
    // Construire la liste des mots interdits à partir de third_word, fourth_word, fifth_word
    final List<String> forbidden = [];
    if (json['third_word'] != null && json['third_word'].toString().isNotEmpty) {
      forbidden.add(json['third_word'].toString());
    }
    if (json['fourth_word'] != null && json['fourth_word'].toString().isNotEmpty) {
      forbidden.add(json['fourth_word'].toString());
    }
    if (json['fifth_word'] != null && json['fifth_word'].toString().isNotEmpty) {
      forbidden.add(json['fifth_word'].toString());
    }

    // Fallback vers forbidden_words si disponible
    if (forbidden.isEmpty && json['forbidden_words'] != null) {
      forbidden.addAll(
        (json['forbidden_words'] as List<dynamic>)
            .map((word) => word.toString())
            .toList()
      );
    }

    return Challenge(
      id: (json['id'] ?? json['_id'] ?? json['challengeId'] ?? '').toString(),
      gameSessionId: (json['gameSessionId'] ?? '').toString(),
      article1: json['article1'] ?? json['article_1'] ?? 'Un',
      input1: json['input1'] ?? json['input_1'] ?? json['first_word'] ?? '',
      preposition: json['preposition'] ?? 'Sur',
      article2: json['article2'] ?? json['article_2'] ?? 'Une',
      input2: json['input2'] ?? json['input_2'] ?? json['second_word'] ?? '',
      forbiddenWords: forbidden,
      prompt: json['prompt'],
      imageUrl: json['imageUrl'] ?? json['image_url'],
      answer: json['answer'],
      isResolved: json['is_resolved'] ?? json['isResolved'],
      drawerId: (json['drawerId'] ?? json['drawer_id'] ?? '').toString(),
      guesserId: (json['guesserId'] ?? json['guesser_id'] ?? '').toString(),
      currentPhase: json['currentPhase'] ?? json['current_phase'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gameSessionId': gameSessionId,
      'article1': article1,
      'first_word': input1,
      'preposition': preposition,
      'article2': article2,
      'second_word': input2,
      if (forbiddenWords.isNotEmpty) 'third_word': forbiddenWords[0],
      if (forbiddenWords.length > 1) 'fourth_word': forbiddenWords[1],
      if (forbiddenWords.length > 2) 'fifth_word': forbiddenWords[2],
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
