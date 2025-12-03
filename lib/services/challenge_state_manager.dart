import 'package:flutter/foundation.dart';
import '../models/challenge.dart';
import '../interfaces/facades/challenge_facade_interface.dart';
import '../utils/logger.dart';

/// État des challenges avec leurs métadonnées
class ChallengeState {
  final List<Challenge> challenges;
  final Set<String> resolvedIds;
  final Map<String, String?> imageUrls;
  final bool isLoading;
  final String? errorMessage;

  const ChallengeState({
    this.challenges = const [],
    this.resolvedIds = const {},
    this.imageUrls = const {},
    this.isLoading = false,
    this.errorMessage,
  });

  ChallengeState copyWith({
    List<Challenge>? challenges,
    Set<String>? resolvedIds,
    Map<String, String?>? imageUrls,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ChallengeState(
      challenges: challenges ?? this.challenges,
      resolvedIds: resolvedIds ?? this.resolvedIds,
      imageUrls: imageUrls ?? this.imageUrls,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Nombre de challenges avec images
  int get challengesWithImages => challenges.where(
    (c) => c.imageUrl != null && c.imageUrl!.isNotEmpty
  ).length;

  /// Vérifie si toutes les images sont prêtes
  bool get allImagesReady => challengesWithImages == challenges.length && challenges.isNotEmpty;

  /// Vérifie si tous les challenges sont résolus
  bool get allChallengesResolved => resolvedIds.length == challenges.length && challenges.isNotEmpty;

  /// Récupère un challenge par ID
  Challenge? getChallengeById(String id) {
    try {
      return challenges.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Vérifie si un challenge est résolu
  bool isChallengeResolved(String id) => resolvedIds.contains(id);
}

/// Manager pour gérer l'état des challenges
///
/// Principe SOLID: Single Responsibility Principle
/// Ce service gère UNE responsabilité: l'état des challenges
///
/// Migré vers IChallengeFacade (SOLID DIP) - n'utilise plus GameFacade
class ChallengeStateManager extends ChangeNotifier {
  final IChallengeFacade _challengeFacade;
  ChallengeState _state = const ChallengeState();

  ChallengeStateManager(this._challengeFacade);

  /// État actuel (read-only)
  ChallengeState get state => _state;

  /// Challenges actuels (shortcut)
  List<Challenge> get challenges => _state.challenges;

  /// Charge les challenges pour la phase drawing
  Future<void> loadDrawingChallenges() async {
    _setState(_state.copyWith(isLoading: true));

    try {
      await _challengeFacade.refreshMyChallenges();
      final challenges = _challengeFacade.myChallenges;

      AppLogger.info('[ChallengeStateManager] ${challenges.length} challenges de dessin chargés');

      _setState(_state.copyWith(
        challenges: challenges,
        isLoading: false,
        errorMessage: null,
      ));
    } catch (e) {
      AppLogger.error('[ChallengeStateManager] Erreur chargement challenges drawing', e);
      _setState(_state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Charge les challenges pour la phase guessing
  Future<void> loadGuessingChallenges() async {
    _setState(_state.copyWith(isLoading: true));

    try {
      await _challengeFacade.refreshChallengesToGuess();
      final challenges = _challengeFacade.challengesToGuess;

      AppLogger.info('[ChallengeStateManager] ${challenges.length} challenges à deviner chargés');

      _setState(_state.copyWith(
        challenges: challenges,
        isLoading: false,
        errorMessage: null,
      ));
    } catch (e) {
      AppLogger.error('[ChallengeStateManager] Erreur chargement challenges guessing', e);
      _setState(_state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Rafraîchit les challenges actuels (pour récupérer les URLs des images)
  ///
  /// Returns true si succès, false si échec
  Future<bool> refreshChallenges() async {
    try {
      await _challengeFacade.refreshMyChallenges();
      final challenges = _challengeFacade.myChallenges;

      AppLogger.info('[ChallengeStateManager] Challenges rafraîchis');

      _setState(_state.copyWith(
        challenges: challenges,
        errorMessage: null,
      ));

      return true;
    } catch (e) {
      AppLogger.error('[ChallengeStateManager] Erreur rafraîchissement', e);

      // Ne pas écraser les challenges existants en cas d'erreur
      _setState(_state.copyWith(
        errorMessage: e.toString(),
      ));

      return false;
    }
  }

  /// Marque un challenge comme résolu
  void markChallengeAsResolved(String challengeId) {
    final newResolvedIds = Set<String>.from(_state.resolvedIds)..add(challengeId);

    AppLogger.info('[ChallengeStateManager] Challenge $challengeId marqué comme résolu');

    _setState(_state.copyWith(resolvedIds: newResolvedIds));
  }

  /// Réinitialise l'état
  void reset() {
    AppLogger.info('[ChallengeStateManager] Reset de l\'état');
    _setState(const ChallengeState());
  }

  /// Met à jour l'URL d'une image pour un challenge
  void updateImageUrl(String challengeId, String imageUrl) {
    final newImageUrls = Map<String, String?>.from(_state.imageUrls);
    newImageUrls[challengeId] = imageUrl;

    AppLogger.info('[ChallengeStateManager] URL mise à jour pour challenge $challengeId');

    _setState(_state.copyWith(imageUrls: newImageUrls));

    // Mettre à jour également dans la liste des challenges
    final updatedChallenges = _state.challenges.map((c) {
      if (c.id == challengeId) {
        return c.copyWith(imageUrl: imageUrl);
      }
      return c;
    }).toList();

    _setState(_state.copyWith(challenges: updatedChallenges));
  }

  /// Met à jour l'état de manière immutable
  void _setState(ChallengeState newState) {
    _state = newState;
    notifyListeners();
  }
}
