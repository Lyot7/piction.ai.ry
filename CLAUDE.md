# Piction.ia.ry - Claude Code Project Rules

## PROJECT CONTEXT
You're developing **Piction.ia.ry**, a Flutter mobile collaborative game app where:

### GAME RULES (Official from Formateur)

**Players**: 4 joueurs répartis en 2 équipes de 2 (2v2)

**Roles**: Chaque équipe a 2 rôles qui s'inversent à chaque tour:
- **Dessinateur (Drawer)**: Écrit le prompt pour générer l'image
- **Devineur (Guesser)**: Devine le challenge à partir de l'image

**Score**: Chaque équipe commence avec **100 points**

**Préparation**:
- Chaque joueur crée **3 challenges** sous la forme:
  - "Un/Une" [INPUT1] "Sur/Dans Un/Une" [INPUT2]
  - Exemple: "Un chat sur une table"
- Chaque challenge inclut **3 mots interdits**
- Les challenges sont envoyés à **l'équipe adverse**

**Phase de jeu (5 minutes)**:
1. Le **dessinateur** reçoit le premier challenge
2. Le dessinateur écrit un **prompt** pour StableDiffusion
   - ⚠️ Le prompt **NE PEUT PAS** contenir les mots à deviner ni les mots interdits
3. Le dessinateur envoie l'image au devineur
   - Possibilité de **régénérer jusqu'à 2 fois** (coût: **-10 points** par régénération)
4. Le **devineur** tente de résoudre le challenge
   - Chaque **proposition erronée** coûte **-1 point**
   - Chaque **mot trouvé** rapporte **+25 points**
5. Lorsque le devineur a résolu son challenge, les **rôles sont inversés**
6. La partie s'arrête quand:
   - Toutes les équipes ont terminé leurs challenges, OU
   - Le temps (5 min) est écoulé

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
2. **LobbyScreen**: Show 4 connected players, team/role assignment (display initial roles)
3. **ChallengeCreationScreen**: **3 forms** for challenges (format: "Un/Une [INPUT1] Sur/Dans Un/Une [INPUT2]" + 3 forbidden words)
4. **GameScreen**:
   - **Drawer mode**: Challenge display, prompt input (with validation), image generation, regenerate button
   - **Guesser mode**: Image display, answer input, format hint, score feedback
   - Common: 5min timer, team scores, role indicator, turn indicator
5. **ResultsScreen**: Final team scores, replay/home buttons

## CRITICAL FEATURES

### GAME FLOW (State transitions)
- **lobby** → **challenge**: Manual via 'Start Game'
- **challenge** → **playing**: Auto when all players sent **3 challenges**
- **playing**: Cycles through challenges with role alternation:
  1. Drawer receives challenge
  2. Drawer writes prompt → validates (no forbidden/target words)
  3. Drawer generates image (optional regen x2)
  4. Guesser sees image and guesses
  5. When resolved → **roles switch** → next challenge
- **playing** → **finished**: Auto when all challenges done OR 5min elapsed

Handle these transitions in GameService with states:
- **lobby**: waiting for players
- **challenge**: players creating challenges
- **playing**: active game with role alternation
- **finished**: game end

### GAME MANAGEMENT
- **5-minute timer**: Auto-stop at time end
- **Team scores**: Each team starts at 100 points (shared score)
- **Role tracking**: Track current drawer/guesser per team
- **Role alternation**: Auto switch after each challenge resolution
- **Prompt validation**: Check forbidden words AND target words not in prompt
- **Turn indicator**: Show who's playing (drawer/guesser)

### CHALLENGE FORMAT
- **Structure**: "Un/Une" [INPUT1] "Sur/Dans Un/Une" [INPUT2]
- **Target words**: INPUT1 and INPUT2 (words to guess)
- **Forbidden words**: 3 additional words that cannot be used in prompt
- **Validation**: Prompt must not contain any of: INPUT1, INPUT2, forbidden words
- **Distribution**: Challenges sent to **opposing team**

### AI INTEGRATION
- **StableDiffusion API**: Image generation from drawer's prompt
- **Latency handling**: Loading indicators during generation
- **Regeneration**: Max 2 times per challenge, costs **-10 points** per regen
- **Prompt input**: Drawer manually writes prompt (not auto-generated)

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

## SPECIALIZED AGENTS & MCP TOOLS

This project has access to specialized agents and MCP (Model Context Protocol) tools that enhance development capabilities. Use these tools **proactively** when their expertise matches the task at hand.

### AVAILABLE AGENTS

#### 1. mobile-developer 📱
**Use for**: Flutter/React Native mobile development tasks
**Invoke when**:
- Implementing mobile-specific features (push notifications, deep linking)
- Handling platform-specific code (iOS/Android native modules)
- Optimizing app performance and bundle size
- Managing offline-first data sync
- Setting up platform-specific build configurations
- Implementing responsive layouts for various screen sizes

**Example scenarios**:
- "Create a QR code sharing widget with platform-specific sharing"
- "Optimize image caching for offline gameplay"
- "Set up deep linking for room joining via URL"
- "Implement background timer for game state sync"

#### 2. ui-ux-designer 🎨
**Use for**: User experience and interface design decisions
**Invoke when**:
- Designing user flows and navigation patterns
- Creating wireframes for new screens
- Improving accessibility and inclusive design
- Establishing design system components
- Planning information architecture
- Conducting usability analysis

**Example scenarios**:
- "Design user flow for challenge creation and submission"
- "Improve accessibility of timer and score display"
- "Create consistent design patterns for game state feedback"
- "Design onboarding experience for new players"

#### 3. task-decomposition-expert 🧩
**Use for**: Complex multi-step projects and workflow planning
**Invoke when**:
- Breaking down large features into manageable tasks
- Planning architecture for complex integrations
- Orchestrating multi-phase development work
- Identifying dependencies and parallel work opportunities
- Optimizing development workflows

**Example scenarios**:
- "Plan implementation of real-time multiplayer synchronization"
- "Break down complete game flow from lobby to results"
- "Design architecture for StableDiffusion API integration with retry logic"

#### 4. mcp-expert 🔌
**Use for**: MCP server configuration and integration (rarely needed for this project)
**Invoke when**:
- Configuring new MCP servers for API integrations
- Setting up external service connections
- Optimizing MCP performance and security

**Note**: Less frequently used for this mobile-first Flutter app.

#### 5. frontend-developer ⚛️
**Available but limited relevance**: React specialist
**Note**: This agent focuses on React/web development. For Flutter work, prefer the **mobile-developer** agent instead.

#### 6. performance-engineer
@performance-engineer.md


### ENABLED MCP SERVERS

#### context7
**Purpose**: Enhanced context management and retrieval
**Use for**: Managing complex codebase context and semantic search

### AGENT USAGE BEST PRACTICES

#### When to Use Agents
✅ **DO use agents for**:
- Complex features requiring specialized expertise
- Multi-step implementations with multiple considerations
- Design decisions requiring UX expertise
- Mobile platform-specific implementations
- Breaking down ambiguous or large requirements

❌ **DON'T use agents for**:
- Simple single-file edits
- Straightforward bug fixes
- Basic widget creation
- Standard Flutter patterns you understand
- Tasks you can complete directly in 1-2 steps

#### Invoking Agents Efficiently
```
# Good: Specific, actionable request with context
"Use mobile-developer agent to implement a background service
that syncs game state every 30 seconds while maintaining
battery efficiency."

# Bad: Vague or too simple
"Fix the button color" (too simple, do directly)
"Make the app better" (too vague, no clear task)
```

#### Parallel Agent Invocation
When tasks are independent, invoke multiple agents in parallel:
```
# Example: Launching parallel work
1. mobile-developer: Implement offline data persistence
2. ui-ux-designer: Design error state feedback patterns
```

### INTEGRATION WITH DEVELOPMENT WORKFLOW

#### Pre-Development Phase
1. **Planning**: Use `task-decomposition-expert` for complex features
2. **Design**: Use `ui-ux-designer` for user flows and wireframes
3. **Break down tasks**: Create implementation roadmap

#### Development Phase
1. **Implementation**: Use `mobile-developer` for Flutter-specific work
2. **Follow SIMPLICITY FIRST**: Agents should simplify, not complicate
3. **Verify with QA**: Run `flutter analyze` after agent work
4. **Test builds**: Ensure agent-generated code compiles

#### Quality Assurance
- Agents must follow ALL project rules (simplicity, testing, linting)
- Agent output is NOT exempt from `flutter analyze` requirements
- Always verify agent work compiles and passes tests

### WHEN NOT TO USE AGENTS

Stay true to the **SIMPLICITY FIRST** philosophy:
- If you can solve it directly in <5 minutes, do it yourself
- If the task requires only basic Flutter knowledge, skip agents
- If adding an agent adds complexity without clear benefit, avoid it
- Remember: **"How can I make this simpler?"**

### AGENT SELECTION QUICK REFERENCE

| Task Type | Recommended Agent | Rationale |
|-----------|------------------|-----------|
| Flutter widget creation | mobile-developer | Mobile-specific patterns |
| User flow design | ui-ux-designer | UX expertise |
| Complex feature planning | task-decomposition-expert | Systematic breakdown |
| Platform-specific code | mobile-developer | Native integration |
| Multi-screen navigation | ui-ux-designer | Information architecture |
| Performance optimization | mobile-developer | Mobile performance |
| Accessibility improvements | ui-ux-designer | Inclusive design |
| API integration planning | task-decomposition-expert | Integration orchestration |

### EXAMPLE WORKFLOWS

#### Implementing New Game Feature
1. **Plan** (task-decomposition-expert): Break down feature requirements
2. **Design** (ui-ux-designer): Create user flow and wireframes
3. **Implement** (mobile-developer): Build Flutter components
4. **Verify**: Run `flutter analyze` and test builds
5. **Polish**: Iterate based on testing

#### Fixing Mobile-Specific Bug
1. **Analyze**: Review error logs and reproduction steps
2. **Solve directly** if simple, OR use mobile-developer if platform-specific
3. **Verify**: Test on both iOS and Android
4. **QA**: Ensure fix doesn't break other features

Remember: Agents are powerful tools, but direct implementation is often faster and simpler. Use judgment to decide when specialized expertise adds value.