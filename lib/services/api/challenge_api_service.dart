import 'dart:convert';

import '../../interfaces/challenge_api_interface.dart';
import '../../interfaces/http_client_interface.dart';
import '../../models/challenge.dart';
import '../../utils/logger.dart';

/// Service de gestion des challenges (SRP)
/// Responsabilité unique: Opérations CRUD sur les challenges
class ChallengeApiService implements IChallengeApi {
  final IHttpClient _httpClient;

  ChallengeApiService({required IHttpClient httpClient})
      : _httpClient = httpClient;

  @override
  Future<Challenge> sendChallenge(
    String gameSessionId,
    String article1,
    String input1,
    String preposition,
    String article2,
    String input2,
    List<String> forbiddenWords,
  ) async {
    // Nettoyer et valider les mots
    final cleanInput1 = input1.trim().toLowerCase();
    final cleanInput2 = input2.trim().toLowerCase();
    final cleanForbidden = forbiddenWords
        .map((word) => word.trim().toLowerCase())
        .where((word) => word.isNotEmpty)
        .toList();

    if (cleanForbidden.length < 3) {
      throw Exception('3 mots interdits sont requis');
    }

    // Vérifier unicité
    final allWords = [cleanInput1, cleanInput2, ...cleanForbidden];
    final uniqueWords = allWords.toSet();
    if (uniqueWords.length != allWords.length) {
      throw Exception('Tous les mots doivent être différents');
    }

    if (cleanInput1.isEmpty || cleanInput2.isEmpty) {
      throw Exception('Les mots à deviner ne peuvent pas être vides');
    }

    // Normaliser les mots
    final normalizedInput1 = _normalizeWord(cleanInput1);
    final normalizedInput2 = _normalizeWord(cleanInput2);
    final normalizedForbidden = cleanForbidden.map(_normalizeWord).toList();

    final payload = {
      'first_word': article1.toLowerCase(),
      'second_word': normalizedInput1,
      'third_word': preposition.toLowerCase(),
      'fourth_word': article2.toLowerCase(),
      'fifth_word': normalizedInput2,
      'forbidden_words': normalizedForbidden,
    };

    AppLogger.info(
        '[ChallengeApiService] Envoi challenge: ${jsonEncode(payload)}');

    final response = await _httpClient.post(
      '/game_sessions/$gameSessionId/challenges',
      body: payload,
    );

    _handleResponse(response);
    final data = jsonDecode(response.body);
    return Challenge.fromJson(data);
  }

  @override
  Future<List<Challenge>> getMyChallenges(String gameSessionId) async {
    final response =
        await _httpClient.get('/game_sessions/$gameSessionId/myChallenges');
    _handleResponse(response);

    final data = jsonDecode(response.body);
    final challengesList = data is List ? data : (data['items'] ?? []);

    return challengesList
        .map<Challenge>((json) => Challenge.fromJson(json))
        .toList();
  }

  @override
  Future<List<Challenge>> getMyChallengesToGuess(String gameSessionId) async {
    final response = await _httpClient
        .get('/game_sessions/$gameSessionId/myChallengesToGuess');
    _handleResponse(response);

    final data = jsonDecode(response.body);
    final challengesList = data is List ? data : (data['items'] ?? []);

    return challengesList
        .map<Challenge>((json) => Challenge.fromJson(json))
        .toList();
  }

  @override
  Future<void> answerChallenge(
    String gameSessionId,
    String challengeId,
    String answer,
    bool isResolved,
  ) async {
    final response = await _httpClient.post(
      '/game_sessions/$gameSessionId/challenges/$challengeId/answer',
      body: {
        'answer': answer,
        'is_resolved': isResolved,
      },
    );
    _handleResponse(response);
  }

  @override
  Future<List<Challenge>> listSessionChallenges(String gameSessionId) async {
    final response =
        await _httpClient.get('/game_sessions/$gameSessionId/challenges');
    _handleResponse(response);

    final data = jsonDecode(response.body);
    final challengesList = data is List ? data : (data['items'] ?? []);

    return challengesList
        .map<Challenge>((json) => Challenge.fromJson(json))
        .toList();
  }

  String _normalizeWord(String word) {
    const accents = 'àâäéèêëïîôùûüÿçñ';
    const replacements = 'aaaeeeeiioouuyyn';
    var normalized = word.toLowerCase();

    for (int i = 0; i < accents.length; i++) {
      normalized = normalized.replaceAll(accents[i], replacements[i]);
    }

    return normalized.replaceAll(RegExp(r'[^a-z]'), '');
  }

  void _handleResponse(dynamic response) {
    if (response.statusCode >= 400) {
      final errorMessage = 'Erreur ${response.statusCode}: ${response.body}';
      throw Exception(errorMessage);
    }
  }
}
