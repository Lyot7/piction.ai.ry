# Piction.ia.ry - Claude Code Project Rules

## PROJECT CONTEXT
You're developing **Piction.ia.ry**, a Flutter mobile collaborative game app where:
- 4 players in 2 teams compete
- Each team has 2 roles: "Drawer" and "Guesser" (alternating each turn)
- Drawer writes a prompt to generate an image via StableDiffusion
- Guesser tries to solve the challenge: "A [INPUT1] On/In A [INPUT2]"
- Scoring: 100 base points, -10 per image regeneration, -1 per wrong answer, +25 per correct word

## DEVELOPMENT PHILOSOPHY

### SIMPLICITY FIRST
- **One feature = One screen**: Each screen has clear, unique purpose
- **Minimal architecture**: Avoid over-engineering, prefer direct solutions
- **Readable code**: Prefer clarity over premature optimization
- **Reusable components**: Create custom widgets only when necessary

### PROJECT STRUCTURE
```
lib/
├── main.dart
├── screens/          # App screens
├── widgets/          # Reusable components
├── models/           # Data models
├── services/         # API services and business logic
├── utils/            # Utilities and helpers
└── themes/           # Theme and styles
```

## TECHNICAL CONSTRAINTS

### FLUTTER FUNDAMENTALS
- **StatelessWidget** by default: Use StatefulWidget only when state really changes
- **Widget build()**: Keep build() methods short and readable
- **setState()**: Use only for UI state changes, not business logic
- **Controllers**: Use TextEditingController and dispose() properly
- **Navigation**: Use Navigator.push/pop, keep route stack simple

### DATA MANAGEMENT
- **SharedPreferences**: For light session data (user preferences, scores)
- **Simple models**: Basic Dart classes, avoid complex ORMs
- **Local state**: Keep state at widget level that needs it

### ASYNC OPERATIONS
- **async/await**: Use for all network operations
- **FutureBuilder**: To display async data
- **try/catch**: Always handle async operation errors
- **Timer.periodic**: For 5-minute game timer

### API & NETWORK
- **http package**: For StableDiffusion API calls
- **CachedNetworkImage**: To display and cache generated images
- **Error handling**: Always handle slow/unavailable network cases

## REQUIRED SCREENS

1. **HomeScreen**: Create/Join game buttons
2. **LobbyScreen**: Show 4 connected players, team/role assignment
3. **ChallengeCreationScreen**: 4 forms for challenges, forbidden words list
4. **GameScreen**: Generated image display, answer input, 5min timer, score, regenerate buttons
5. **ResultsScreen**: Final scores, replay/home buttons

## CRITICAL FEATURES

### GAME FLOW (State transitions)
- null → challenge: Manual via 'Start Game'
- challenge → drawing: Auto when all players sent 3 challenges
- drawing → guessing: Auto when all players drew their challenge
- guessing → finished: Auto when all answered or 5min elapsed

Handle these transitions in GameService with states:
- challenge: preparation phase
- drawing: AI drawing phase  
- guessing: guessing phase
- finished: game end

### GAME MANAGEMENT
- **5-minute timer**: Auto-stop at time end
- **Point system**: Real-time calculation and display
- **Word validation**: Check forbidden words not used in prompts
- **Role alternation**: Auto management of drawer/guesser switching

### AI INTEGRATION
- **StableDiffusion API**: Image generation from prompts
- **Latency handling**: Loading indicators during generation
- **Regeneration**: Max 2 times per challenge, costs 10 points

## BEST PRACTICES

### NAMING
- **Files**: snake_case (game_screen.dart)
- **Classes**: PascalCase (GameScreen)
- **Variables/methods**: camelCase (currentScore)
- **Constants**: UPPER_CASE (MAX_PLAYERS)

### WIDGETS
```dart
// ✅ GOOD: Simple focused widget
class ScoreDisplay extends StatelessWidget {
  final int score;
  const ScoreDisplay({super.key, required this.score});
  
  @override
  Widget build(BuildContext context) {
    return Text('Score: $score');
  }
}
```

### STATE MANAGEMENT
```dart
// ✅ GOOD: Simple local state
class TimerWidget extends StatefulWidget {
  @override
  _TimerWidgetState createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  Timer? _timer;
  int _seconds = 300; // 5 minutes
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
```

## RECOMMENDED PACKAGES
- `http`: API requests
- `cached_network_image`: Image caching
- `shared_preferences`: Local storage
- `flutter_staggered_animations`: Animations
- Avoid third-party packages unless absolutely necessary

## DEVELOPMENT INSTRUCTIONS

### ALWAYS
- Start with simplest solution and iterate
- One problem at a time
- Compilable code at each step
- Comment complex parts
- Handle error cases

### NEVER
- Add unrequested features
- Over-complicate architecture
- Forget dispose() for controllers/timers
- Neglect network error handling

### RECOMMENDED DEVELOPMENT ORDER
1. Basic structure and navigation
2. Simple data models
3. Static screens with theme
4. StableDiffusion API integration
5. Game logic and timer
6. UI polish and animations
7. Testing and debugging

Always think **"How can I make this simpler?"** rather than **"How can I make this more sophisticated?"**

## TESTING
- Use `flutter test` for unit tests
- Use `flutter drive` for integration tests
- Run tests before committing changes

## BUILD & LINT
- **MANDATORY**: Always run `flutter analyze` after every code modification to check for errors
- **MANDATORY**: Always run `flutter build apk --debug` or `flutter build ios --debug` after significant changes to verify compilation
- **MANDATORY**: Fix all warnings and errors before committing
- **MOBILE ONLY**: This is a mobile-only application - no macOS, Windows, or Linux support needed

## QUALITY ASSURANCE RULE
**CRITICAL**: Before marking any task as completed, you MUST:
1. Run `flutter analyze` and ensure 0 issues
2. Test build compilation with `flutter build apk --debug` (if Android SDK available) or `flutter build ios --debug`
3. Fix any compilation errors immediately
4. Never commit broken code