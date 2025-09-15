# 🎨 Piction.ia.ry

**Jeu collaboratif de devinettes avec IA générative**

Une application mobile Flutter où 4 joueurs s'affrontent en 2 équipes pour deviner des images générées par intelligence artificielle.

## 🎮 Comment jouer

- **4 joueurs** répartis en **2 équipes de 2**
- Chaque équipe a un **Dessinateur** et un **Devineur** (rôles alternants)
- Le dessinateur écrit un **prompt IA** pour générer une image
- Le devineur doit trouver : **"Un/Une [OBJET] Sur/Dans Un/Une [LIEU]"**
- **5 minutes** par manche
- **Système de points** :
  - 100 points de base par équipe
  - +25 points par mot trouvé
  - -1 point par mauvaise réponse
  - -10 points par régénération d'image (max 2 fois)

## 🚀 Fonctionnalités

### ✅ Implémentées
- ✨ Interface utilisateur complète avec thème moderne
- 🏠 Écran d'accueil avec règles du jeu
- 👥 Lobby pour organiser les équipes
- 📝 Création de challenges personnalisés
- 🎯 Écran de jeu avec timer en temps réel
- 🏆 Écran de résultats avec statistiques
- 📱 Navigation fluide entre les écrans
- 🎭 Animations avec flutter_staggered_animations

### 🔄 En cours de développement
- 🤖 Intégration API StableDiffusion
- 🌐 Multijoueur en ligne
- 💾 Sauvegarde des parties

## 🛠️ Technologies

- **Flutter** 3.9.2+
- **Dart** 
- **Material Design 3**
- **Packages** :
  - `http` - Requêtes API
  - `cached_network_image` - Cache des images
  - `shared_preferences` - Stockage local
  - `flutter_staggered_animations` - Animations

## 📁 Structure du projet

```
lib/
├── main.dart                 # Point d'entrée
├── screens/                 # Écrans de l'application
│   ├── home_screen.dart
│   ├── lobby_screen.dart
│   ├── challenge_creation_screen.dart
│   ├── game_screen.dart
│   └── results_screen.dart
├── themes/                  # Thème et styles
│   └── app_theme.dart
├── widgets/                 # Composants réutilisables
├── models/                  # Modèles de données
├── services/                # Services API
└── utils/                   # Utilitaires
```

## 🚀 Installation et lancement

### Prérequis
- Flutter SDK 3.9.2+
- Dart SDK
- IDE (VS Code, Android Studio, etc.)

### Installation
```bash
# Cloner le repository
git clone https://github.com/votre-username/piction.ai.ry.git
cd piction.ai.ry

# Installer les dépendances
flutter pub get

# Lancer l'application
flutter run
```

### Tests
```bash
flutter test
flutter analyze
```

## 🎨 Design System

### Couleurs principales
- **Primary** : `#6366F1` (Indigo)
- **Secondary** : `#EC4899` (Rose)
- **Accent** : `#10B981` (Vert)
- **Équipe 1** : `#3B82F6` (Bleu)
- **Équipe 2** : `#F59E0B` (Orange)

### Philosophie
- **Simplicité avant tout** - Une fonctionnalité = Un écran
- **Code lisible** - Privilégier la clarté à la performance prématurée
- **Architecture minimale** - Éviter la sur-ingénierie

## 📄 Critères d'évaluation (M2 DFS 2025/2026)

### Phase 1 (10 points)
- [x] Tous les écrans designés (2pts)
- [x] Thème défini et utilisé (2pts)
- [x] Interface intuitive et facile à naviguer (1pt)
- [x] Modèles de données créés (1pt)
- [x] Démarrage et lancement du jeu (2pts)
- [ ] Envoi et réception des challenges à l'API (2pts)

### Phase 2 (10 points)
- [ ] Application fonctionnelle de bout en bout (4pts)
- [x] Navigation et enchaînement des écrans (2pts)
- [ ] Gestion des processus asynchrones (4pts)

## 📝 TODO

- [ ] Intégration réelle de l'API StableDiffusion
- [ ] Validation des mots interdits dans les prompts
- [ ] Gestion multijoueur réseau
- [ ] Persistance des parties
- [ ] Tests unitaires et d'intégration
- [ ] Optimisations des performances
- [ ] Support multilingue

## 👥 Équipe

Développé dans le cadre du cours **Développement Mobile M2 DFS 2025/2026**.

## 📄 Licence

Ce projet est développé à des fins éducatives.