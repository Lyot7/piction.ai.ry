/// Modèle pour un challenge
class Challenge {
  final String id;
  final String gameSessionId;
  final String firstWord;
  final String secondWord;
  final String thirdWord;
  final String fourthWord;
  final String fifthWord;
  final List<String> forbiddenWords;
  final String? prompt; // Prompt pour la génération d'image
  final String? imageUrl; // URL de l'image générée
  final String? answer; // Réponse du devineur
  final bool? isResolved; // Si le challenge a été résolu
  final String? drawerId; // ID du joueur qui dessine
  final String? guesserId; // ID du joueur qui devine
  final DateTime? createdAt;
  final DateTime? completedAt;

  const Challenge({
    required this.id,
    required this.gameSessionId,
    required this.firstWord,
    required this.secondWord,
    required this.thirdWord,
    required this.fourthWord,
    required this.fifthWord,
    required this.forbiddenWords,
    this.prompt,
    this.imageUrl,
    this.answer,
    this.isResolved,
    this.drawerId,
    this.guesserId,
    this.createdAt,
    this.completedAt,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] ?? json['_id'] ?? json['challengeId'] ?? '',
      gameSessionId: json['gameSessionId'] ?? '',
      firstWord: json['first_word'] ?? '',
      secondWord: json['second_word'] ?? '',
      thirdWord: json['third_word'] ?? '',
      fourthWord: json['fourth_word'] ?? '',
      fifthWord: json['fifth_word'] ?? '',
      forbiddenWords: (json['forbidden_words'] as List<dynamic>?)
          ?.map((word) => word.toString())
          .toList() ?? [],
      prompt: json['prompt'],
      imageUrl: json['imageUrl'] ?? json['image_url'],
      answer: json['answer'],
      isResolved: json['is_resolved'],
      drawerId: json['drawerId'] ?? json['drawer_id'],
      guesserId: json['guesserId'] ?? json['guesser_id'],
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
      'first_word': firstWord,
      'second_word': secondWord,
      'third_word': thirdWord,
      'fourth_word': fourthWord,
      'fifth_word': fifthWord,
      'forbidden_words': forbiddenWords,
      if (prompt != null) 'prompt': prompt,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (answer != null) 'answer': answer,
      if (isResolved != null) 'is_resolved': isResolved,
      if (drawerId != null) 'drawerId': drawerId,
      if (guesserId != null) 'guesserId': guesserId,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    };
  }

  Challenge copyWith({
    String? id,
    String? gameSessionId,
    String? firstWord,
    String? secondWord,
    String? thirdWord,
    String? fourthWord,
    String? fifthWord,
    List<String>? forbiddenWords,
    String? prompt,
    String? imageUrl,
    String? answer,
    bool? isResolved,
    String? drawerId,
    String? guesserId,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return Challenge(
      id: id ?? this.id,
      gameSessionId: gameSessionId ?? this.gameSessionId,
      firstWord: firstWord ?? this.firstWord,
      secondWord: secondWord ?? this.secondWord,
      thirdWord: thirdWord ?? this.thirdWord,
      fourthWord: fourthWord ?? this.fourthWord,
      fifthWord: fifthWord ?? this.fifthWord,
      forbiddenWords: forbiddenWords ?? this.forbiddenWords,
      prompt: prompt ?? this.prompt,
      imageUrl: imageUrl ?? this.imageUrl,
      answer: answer ?? this.answer,
      isResolved: isResolved ?? this.isResolved,
      drawerId: drawerId ?? this.drawerId,
      guesserId: guesserId ?? this.guesserId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Retourne la phrase complète du challenge
  String get fullPhrase => '$firstWord $secondWord $thirdWord $fourthWord $fifthWord';

  /// Vérifie si le challenge a été résolu
  bool get isCompleted => isResolved == true;

  /// Vérifie si le challenge a un prompt (phase drawing)
  bool get hasPrompt => prompt != null && prompt!.isNotEmpty;

  /// Vérifie si le challenge a une image générée
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  @override
  String toString() {
    return 'Challenge(id: $id, phrase: $fullPhrase, resolved: $isResolved)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Challenge && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
