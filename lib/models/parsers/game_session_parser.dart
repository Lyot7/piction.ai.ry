import '../game_session.dart';
import '../player.dart';
import '../../utils/logger.dart';

/// Interface pour le pattern Strategy de parsing (LSP)
/// Chaque parser peut parser un format spécifique de JSON
abstract class GameSessionParser {
  /// Parse le JSON en GameSession
  GameSession parse(Map<String, dynamic> json);

  /// Vérifie si ce parser peut parser le JSON donné
  bool canParse(Map<String, dynamic> json);
}

/// Parser pour le format standard avec champ 'players'
class StandardFormatParser implements GameSessionParser {
  @override
  bool canParse(Map<String, dynamic> json) {
    return json.containsKey('players') && json['players'] is List;
  }

  @override
  GameSession parse(Map<String, dynamic> json) {
    AppLogger.log('[StandardFormatParser] Parsing standard format');

    final List<Player> players = (json['players'] as List<dynamic>)
        .map((playerJson) {
          final Map<String, dynamic> data = playerJson as Map<String, dynamic>;
          // Support pour format avec player_id au lieu de id
          if (data['player_id'] != null && data['id'] == null) {
            return Player.fromJson({...data, 'id': data['player_id']});
          }
          return Player.fromJson(data);
        })
        .toList();

    return _buildSession(json, players);
  }

  GameSession _buildSession(Map<String, dynamic> json, List<Player> players) {
    return GameSession(
      id: _parseId(json),
      status: json['status'] ?? 'lobby',
      players: _enrichWithChallengeCount(players, json),
      teamScores: _parseScores(json),
      currentTurn: json['currentTurn'] ?? json['current_turn'] ?? 0,
      gamePhase: json['gamePhase'] ?? json['game_phase'],
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      startedAt: _parseDate(json['startedAt'] ?? json['started_at']),
      hostId: _parseHostId(json),
    );
  }

  String _parseId(Map<String, dynamic> json) {
    return (json['id'] ?? json['_id'] ?? json['gameSessionId'] ?? '').toString();
  }

  Map<String, int> _parseScores(Map<String, dynamic> json) {
    if (json['teamScores'] != null && json['teamScores'] is Map) {
      final Map teamScoresJson = json['teamScores'];
      return {
        'red': teamScoresJson['red'] ?? 100,
        'blue': teamScoresJson['blue'] ?? 100,
      };
    }
    return {'red': 100, 'blue': 100};
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String? _parseHostId(Map<String, dynamic> json) {
    return (json['host_id'] ??
            json['hostId'] ??
            json['created_by'] ??
            json['createdBy'])
        ?.toString();
  }

  List<Player> _enrichWithChallengeCount(
      List<Player> players, Map<String, dynamic> json) {
    if (json['challenges'] == null || json['challenges'] is! List) {
      return players;
    }

    final challenges = json['challenges'] as List<dynamic>;
    final Map<String, int> challengesCount = {};

    for (final challenge in challenges) {
      if (challenge is Map<String, dynamic>) {
        final challengerId = challenge['challenger_id']?.toString();
        if (challengerId != null) {
          challengesCount[challengerId] = (challengesCount[challengerId] ?? 0) + 1;
        }
      }
    }

    return players.map((p) {
      final count = challengesCount[p.id] ?? 0;
      return p.copyWith(challengesSent: count);
    }).toList();
  }
}

/// Parser pour le format avec red_team/blue_team
class TeamFormatParser implements GameSessionParser {
  @override
  bool canParse(Map<String, dynamic> json) {
    return !json.containsKey('players') &&
        (json.containsKey('red_team') || json.containsKey('blue_team'));
  }

  @override
  GameSession parse(Map<String, dynamic> json) {
    AppLogger.log('[TeamFormatParser] Parsing team format');

    final List<Player> players = [];

    // Parser red_team
    final redTeam = json['red_team'] as List<dynamic>? ?? [];
    for (final member in redTeam) {
      players.add(_parseTeamMember(member, 'red'));
    }

    // Parser blue_team
    final blueTeam = json['blue_team'] as List<dynamic>? ?? [];
    for (final member in blueTeam) {
      players.add(_parseTeamMember(member, 'blue'));
    }

    return _buildSession(json, players);
  }

  Player _parseTeamMember(dynamic member, String color) {
    if (member is Map<String, dynamic>) {
      final playerData = {...member};
      if (playerData['player_id'] != null && playerData['id'] == null) {
        playerData['id'] = playerData['player_id'];
      }
      playerData['color'] = color;
      return Player.fromJson(playerData);
    } else {
      // Format ID simple
      return Player(
        id: member.toString(),
        name: '', // Sera rempli par enrichissement
        color: color,
      );
    }
  }

  GameSession _buildSession(Map<String, dynamic> json, List<Player> players) {
    // Réutiliser la logique du StandardFormatParser
    final standardParser = StandardFormatParser();
    final enrichedPlayers = standardParser._enrichWithChallengeCount(players, json);

    return GameSession(
      id: standardParser._parseId(json),
      status: json['status'] ?? 'lobby',
      players: enrichedPlayers,
      teamScores: standardParser._parseScores(json),
      currentTurn: json['currentTurn'] ?? json['current_turn'] ?? 0,
      gamePhase: json['gamePhase'] ?? json['game_phase'],
      createdAt: standardParser._parseDate(json['createdAt'] ?? json['created_at']),
      startedAt: standardParser._parseDate(json['startedAt'] ?? json['started_at']),
      hostId: standardParser._parseHostId(json),
    );
  }
}

/// Composite parser qui sélectionne la bonne stratégie (LSP)
/// Les parsers sont interchangeables grâce à Liskov Substitution
class CompositeGameSessionParser {
  final List<GameSessionParser> _parsers = [
    StandardFormatParser(),
    TeamFormatParser(),
  ];

  /// Parse le JSON en utilisant le bon parser
  GameSession parse(Map<String, dynamic> json) {
    for (final parser in _parsers) {
      if (parser.canParse(json)) {
        return parser.parse(json);
      }
    }

    AppLogger.warning('[CompositeParser] No parser found, using standard');
    // Fallback: utiliser le parser standard même si le format n'est pas reconnu
    return StandardFormatParser().parse(json);
  }

  /// Ajoute un nouveau parser (OCP - Open for extension)
  void addParser(GameSessionParser parser) {
    _parsers.add(parser);
  }
}
