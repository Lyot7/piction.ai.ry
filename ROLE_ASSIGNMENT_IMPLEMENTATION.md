# 🎯 Implémentation de l'Attribution des Rôles - Piction.ia.ry

## 📋 Résumé

Ce document décrit l'implémentation complète du système d'attribution des rôles pour Piction.ia.ry, résolvant le problème où les joueurs n'avaient pas de rôles assignés avant le début du jeu.

## 🔴 Problème Identifié

### Symptômes
- Les joueurs rejoignaient le lobby mais n'avaient pas de rôles assignés
- Le champ `role` restait `null` pour tous les joueurs
- Le LobbyScreen était préparé pour afficher les rôles, mais ils n'existaient pas
- Le jeu ne pouvait pas démarrer correctement sans rôles

### Cause Racine
- Aucune logique d'attribution de rôles lors du join
- `startGameSession()` n'assignait pas les rôles avant de lancer le jeu
- Dépendance implicite sur le backend pour assigner les rôles (non implémenté)

## ✅ Solution Implémentée

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     GameService                              │
│                                                               │
│  startGameSession()                                          │
│  ├─ 1. Appelle backend /game_sessions/{id}/start            │
│  ├─ 2. Refresh session (récupérer rôles backend si existe) │
│  ├─ 3. Vérifier si rôles assignés                           │
│  │     ├─ OUI → Log succès                                  │
│  │     └─ NON → Utiliser RoleAssignment.assignInitialRoles()│
│  ├─ 4. Valider que les rôles sont corrects                  │
│  └─ 5. Mettre à jour le statut → 'challenge'                │
│                                                               │
│  switchAllRoles()                                            │
│  ├─ 1. Utiliser RoleAssignment.switchAllRoles()             │
│  ├─ 2. Mettre à jour la session locale                      │
│  └─ 3. Log de l'état après inversion                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              RoleAssignment (Utility)                        │
│                                                               │
│  assignInitialRoles(session)                                 │
│  ├─ Vérifier que session.isReadyToStart                     │
│  ├─ Pour chaque équipe (red, blue):                         │
│  │     ├─ Premier joueur → role = 'drawer'                  │
│  │     └─ Deuxième joueur → role = 'guesser'                │
│  └─ Retourner session avec rôles assignés                   │
│                                                               │
│  allPlayersHaveRoles(session)                                │
│  └─ Vérifie que tous les joueurs ont un rôle non-null       │
│                                                               │
│  areRolesValid(session)                                      │
│  └─ Vérifie: 1 drawer + 1 guesser par équipe                │
│                                                               │
│  switchAllRoles(session)                                     │
│  └─ Inverse tous les rôles (drawer ↔ guesser)               │
└─────────────────────────────────────────────────────────────┘
```

### Fichiers Créés

#### 1. **`lib/utils/role_assignment.dart`**
Utilitaire complet pour la gestion des rôles avec :
- `assignInitialRoles()` : Attribue drawer/guesser selon l'ordre de join
- `allPlayersHaveRoles()` : Vérifie que tous les joueurs ont un rôle
- `areRolesValid()` : Valide la distribution (1 drawer + 1 guesser par team)
- `switchAllRoles()` : Inverse les rôles de tous les joueurs

#### 2. **`test/unit/utils/role_assignment_test.dart`**
Suite de tests complète (6 tests, tous passent ✅) :
- Attribution correcte drawer/guesser
- Détection des rôles manquants
- Validation des rôles
- Inversion des rôles
- Gestion des équipes incomplètes
- Scénarios mixtes

### Fichiers Modifiés

#### 1. **`lib/services/game_service.dart`**

**Modification de `startGameSession()` :**
```dart
// Avant:
await _apiService.startGameSession(_currentGameSession!.id);
_currentStatus = 'challenge';
_statusController.add(_currentStatus);

// Après:
await _apiService.startGameSession(_currentGameSession!.id);
await refreshGameSession(_currentGameSession!.id);

// Si backend n'a pas assigné les rôles, le faire localement
if (!RoleAssignment.allPlayersHaveRoles(_currentGameSession!)) {
  _currentGameSession = RoleAssignment.assignInitialRoles(_currentGameSession!);
  _gameSessionController.add(_currentGameSession);
}

// Valider et logger
RoleAssignment.areRolesValid(_currentGameSession!);
```

**Modification de `switchAllRoles()` :**
```dart
// Avant:
await refreshGameSession(_currentGameSession!.id);

// Après:
_currentGameSession = RoleAssignment.switchAllRoles(_currentGameSession!);
_gameSessionController.add(_currentGameSession);
```

## 🎮 Flux de Jeu

### 1. Lobby → Début du Jeu

```
┌──────────────────┐
│  4 joueurs       │
│  2 red, 2 blue   │
│  role = null     │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Host clique     │
│  "Commencer"     │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────┐
│  GameService.startGameSession()      │
│  1. POST /game_sessions/{id}/start   │
│  2. Refresh session                  │
│  3. Vérifier rôles backend           │
│  4. Si null → Assigner localement    │
│  5. Valider rôles                    │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────┐
│  Résultat:       │
│  Red team:       │
│    P1: drawer    │
│    P2: guesser   │
│  Blue team:      │
│    P1: drawer    │
│    P2: guesser   │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Navigation →    │
│  ChallengeScreen │
└──────────────────┘
```

### 2. Inversion des Rôles (Pendant le Jeu)

```
┌──────────────────┐
│  Challenge       │
│  résolu          │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────┐
│  GameService.switchAllRoles()        │
│  1. RoleAssignment.switchAllRoles()  │
│  2. Update local session             │
│  3. Notify via stream                │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────┐
│  Résultat:       │
│  Red team:       │
│    P1: guesser   │ ← était drawer
│    P2: drawer    │ ← était guesser
│  Blue team:      │
│    P1: guesser   │ ← était drawer
│    P2: drawer    │ ← était guesser
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Prochain        │
│  challenge       │
└──────────────────┘
```

## 🧪 Tests

### Résultats
```bash
$ flutter test test/unit/utils/role_assignment_test.dart

✅ All tests passed!

6 tests:
- should assign drawer to first player and guesser to second player in each team
- should detect when all players have roles
- should validate roles correctly
- should switch all roles correctly
- should not assign roles to incomplete teams
- should handle mixed scenarios with partial roles
```

### Couverture
- ✅ Attribution initiale des rôles
- ✅ Validation de la distribution
- ✅ Détection des rôles manquants
- ✅ Inversion des rôles
- ✅ Gestion des cas limites
- ✅ Équipes incomplètes

## 📊 Analyse de Code

### Quality Assurance
```bash
$ flutter analyze

No issues found! (ran in 3.0s)
```

**Résultat :** ✅ 0 erreurs, 0 avertissements, 0 suggestions

### Principes SOLID Respectés

1. **Single Responsibility**
   - `RoleAssignment` : uniquement la gestion des rôles
   - Séparation claire de la logique métier

2. **Open/Closed**
   - `RoleAssignment` peut être étendu sans modification
   - Méthodes statiques réutilisables

3. **Dependency Inversion**
   - `GameService` dépend de l'abstraction `RoleAssignment`
   - Pas de couplage fort avec l'implémentation

## 🚀 Utilisation

### Dans le Code

```dart
// Assigner les rôles initiaux
final sessionWithRoles = RoleAssignment.assignInitialRoles(session);

// Vérifier que tous ont des rôles
if (RoleAssignment.allPlayersHaveRoles(session)) {
  // OK, continuer
}

// Valider la distribution
if (RoleAssignment.areRolesValid(session)) {
  // OK, 1 drawer + 1 guesser par team
}

// Inverser les rôles
final sessionWithSwitchedRoles = RoleAssignment.switchAllRoles(session);
```

### Logs

Lors du démarrage d'un jeu, vous verrez :
```
ℹ️ INFO: [GameService] Démarrage de la session test-session-123
ℹ️ INFO: [GameService] Rafraîchissement après démarrage pour récupérer les rôles
⚠️ WARNING: [GameService] Le backend n'a pas assigné les rôles, attribution locale
ℹ️ INFO: [RoleAssignment] Attribution des rôles initiaux
ℹ️ INFO: [RoleAssignment] Équipe red: Alice = drawer, Bob = guesser
ℹ️ INFO: [RoleAssignment] Équipe blue: Charlie = drawer, Diana = guesser
✅ SUCCESS: [RoleAssignment] Rôles assignés avec succès
ℹ️ INFO: [GameService] État final des joueurs:
ℹ️ INFO: [GameService]   - Alice: red team, drawer
ℹ️ INFO: [GameService]   - Bob: red team, guesser
ℹ️ INFO: [GameService]   - Charlie: blue team, drawer
ℹ️ INFO: [GameService]   - Diana: blue team, guesser
```

## 📈 Améliorations Futures (Optionnel)

### Court Terme
- [ ] Ajouter un indicateur visuel dans le lobby avant le start
- [ ] Animation lors de l'inversion des rôles
- [ ] Notification push lors du changement de rôle

### Long Terme
- [ ] Permettre au host de choisir manuellement les rôles initiaux
- [ ] Historique des rôles par challenge
- [ ] Statistiques par rôle (performance drawer vs guesser)

## 🎓 Règles du Jeu Respectées

✅ **Chaque équipe a 2 rôles qui s'inversent à chaque tour**
- Premier joueur = Dessinateur (drawer)
- Deuxième joueur = Devineur (guesser)

✅ **Affichage dans le lobby**
- Le LobbyScreen affiche déjà les rôles (lignes 587-606)
- Maintenant les rôles existent et seront affichés

✅ **Inversion automatique**
- `switchAllRoles()` inverse les rôles après chaque challenge résolu

## 🔍 Vérification

### Checklist de Test Manuel

Avant de lancer le jeu, vérifiez :
1. ✅ 4 joueurs dans le lobby
2. ✅ 2 joueurs par équipe (rouge et bleue)
3. ✅ Cliquer sur "Commencer"
4. ✅ Vérifier les logs console
5. ✅ Confirmer que les rôles sont assignés
6. ✅ Naviguer vers ChallengeCreationScreen

Pendant le jeu :
1. ✅ Résoudre un challenge
2. ✅ Vérifier que les rôles s'inversent
3. ✅ Confirmer dans les logs
4. ✅ Continuer le jeu

## 📞 Support

Si vous rencontrez des problèmes :
1. Vérifiez les logs console (recherchez `[RoleAssignment]` et `[GameService]`)
2. Assurez-vous que `flutter analyze` ne remonte aucune erreur
3. Relancez les tests avec `flutter test test/unit/utils/role_assignment_test.dart`

## 🎉 Conclusion

L'implémentation est **complète et testée** :
- ✅ 0 erreurs `flutter analyze`
- ✅ 6/6 tests unitaires passent
- ✅ Logs détaillés pour debug
- ✅ Respecte les principes SOLID
- ✅ Suit les règles du jeu

Le système fonctionne en **mode hybride** :
- **Priorité au backend** : Si le backend assigne les rôles, on les utilise
- **Fallback frontend** : Sinon, attribution locale automatique

Vous pouvez maintenant **tester le jeu complet** en créant une room, ajoutant 4 joueurs, et lançant la partie ! 🎮
