import 'dart:async';

import '../../interfaces/challenge_api_interface.dart';
import '../../interfaces/facades/challenge_facade_interface.dart';
import '../../interfaces/facades/session_facade_interface.dart';
import '../../interfaces/image_api_interface.dart';
import '../../models/challenge.dart';
import '../../utils/logger.dart';

/// Facade de challenges (ISP + SRP)
/// Responsabilité unique: Gestion des challenges
class ChallengeFacade implements IChallengeFacade {
  final IChallengeApi _challengeApi;
  final IImageApi _imageApi;
  final ISessionFacade _sessionFacade;

  List<Challenge> _myChallenges = [];
  List<Challenge> _challengesToGuess = [];
  final StreamController<List<Challenge>> _challengesController =
      StreamController<List<Challenge>>.broadcast();

  ChallengeFacade({
    required IChallengeApi challengeApi,
    required IImageApi imageApi,
    required ISessionFacade sessionFacade,
  })  : _challengeApi = challengeApi,
        _imageApi = imageApi,
        _sessionFacade = sessionFacade;

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
    return await _challengeApi.sendChallenge(
      gameSessionId,
      article1,
      input1,
      preposition,
      article2,
      input2,
      forbiddenWords,
    );
  }

  @override
  Future<List<Challenge>> getMyChallenges(String gameSessionId) async {
    final challenges = await _challengeApi.getMyChallenges(gameSessionId);
    _myChallenges = challenges;
    _challengesController.add(challenges);
    return challenges;
  }

  @override
  Future<List<Challenge>> getMyChallengesToGuess(String gameSessionId) async {
    return await _challengeApi.getMyChallengesToGuess(gameSessionId);
  }

  @override
  Future<void> refreshMyChallenges() async {
    final session = _sessionFacade.currentGameSession;
    if (session == null) return;

    try {
      _myChallenges = await _challengeApi.getMyChallenges(session.id);
      _challengesController.add(_myChallenges);
    } catch (e) {
      AppLogger.error('[ChallengeFacade] Erreur refresh challenges', e);
      throw Exception('Erreur lors de l\'actualisation des challenges: $e');
    }
  }

  @override
  Future<void> refreshChallengesToGuess() async {
    final session = _sessionFacade.currentGameSession;
    if (session == null) return;

    try {
      _challengesToGuess =
          await _challengeApi.getMyChallengesToGuess(session.id);
      _challengesController.add(_challengesToGuess);
    } catch (e) {
      AppLogger.error('[ChallengeFacade] Erreur refresh challenges to guess', e);
      throw Exception('Erreur lors de l\'actualisation des challenges à deviner: $e');
    }
  }

  @override
  Future<String> generateImageForChallenge(
    String gameSessionId,
    String challengeId,
    String prompt,
  ) async {
    return await _imageApi.generateImageForChallenge(
      gameSessionId,
      challengeId,
      prompt,
    );
  }

  @override
  Future<void> answerChallenge(
    String gameSessionId,
    String challengeId,
    String answer,
    bool isResolved,
  ) async {
    await _challengeApi.answerChallenge(
      gameSessionId,
      challengeId,
      answer,
      isResolved,
    );
  }

  @override
  Future<List<Challenge>> listSessionChallenges(String gameSessionId) async {
    return await _challengeApi.listSessionChallenges(gameSessionId);
  }

  @override
  List<Challenge> get myChallenges => _myChallenges;

  @override
  List<Challenge> get challengesToGuess => _challengesToGuess;

  @override
  Stream<List<Challenge>> get challengesStream => _challengesController.stream;

  void dispose() {
    _challengesController.close();
  }
}
