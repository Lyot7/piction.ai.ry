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
    // Backend format:
    // first_word = article1, second_word = input1, third_word = preposition,
    // fourth_word = article2, fifth_word = input2
    // forbidden_words = liste des 3 mots interdits
    final List<String> forbidden = [];
    if (json['forbidden_words'] != null) {
      if (json['forbidden_words'] is List) {
        // Si c'est une liste, on la parse
        forbidden.addAll(
          (json['forbidden_words'] as List<dynamic>)
              .map((word) => word.toString())
              .toList()
        );
      } else if (json['forbidden_words'] is String) {
        // Si c'est une string (possiblement JSON), essayer de la parser
        final stringValue = json['forbidden_words'].toString();
        try {
          // Tenter de parser comme JSON
          final dynamic parsed = jsonDecode(stringValue);
          if (parsed is List) {
            forbidden.addAll(
              parsed
                  .map((word) => word.toString())
                  .toList()
            );
          } else {
            forbidden.add(stringValue);
          }
        } catch (e) {
          // Si ce n'est pas du JSON valide, ajouter tel quel
          forbidden.add(stringValue);
        }
      }
    }

    // Log pour debug: voir ce que contient le JSON
    final challengeId = (json['id'] ?? json['_id'] ?? json['challengeId'] ?? '').toString();
    final imageUrl = json['imageUrl'] ?? json['image_url'] ?? json['image_path'];

    // Log toutes les clés possibles pour l'image
    print('[Challenge.fromJson] Challenge ID: $challengeId');
    print('[Challenge.fromJson] imageUrl field: ${json['imageUrl']}');
    print('[Challenge.fromJson] image_url field: ${json['image_url']}');
    print('[Challenge.fromJson] image_path field: ${json['image_path']}');
    print('[Challenge.fromJson] Final imageUrl: $imageUrl');

    return Challenge(
      id: challengeId,
      gameSessionId: (json['gameSessionId'] ?? '').toString(),
      article1: json['article1'] ?? json['article_1'] ?? json['first_word'] ?? 'Un',
      input1: json['input1'] ?? json['input_1'] ?? json['second_word'] ?? '',
      preposition: json['preposition'] ?? json['third_word'] ?? 'Sur',
      article2: json['article2'] ?? json['article_2'] ?? json['fourth_word'] ?? 'Une',
      input2: json['input2'] ?? json['input_2'] ?? json['fifth_word'] ?? '',
      forbiddenWords: forbidden,
      prompt: json['prompt'],
      imageUrl: imageUrl,
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
      // Format backend: first_word=article1, second_word=input1, etc.
      'first_word': article1,
      'second_word': input1,
      'third_word': preposition,
      'fourth_word': article2,
      'fifth_word': input2,
      'forbidden_words': forbiddenWords,
      if (prompt != null) 'prompt': prompt,
      if (imageUrl != null) 'image_path': imageUrl,  // Backend uses image_path
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
