import 'package:shared_preferences/shared_preferences.dart';

import '../../interfaces/token_storage_interface.dart';

/// Service de gestion des tokens JWT (SRP)
/// Responsabilité unique: Stockage et récupération des tokens
class TokenService implements ITokenStorage {
  static const String _jwtKey = 'jwt_token';
  static const String _playerIdKey = 'player_id';

  String? _jwt;
  String? _playerId;

  @override
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _jwt = prefs.getString(_jwtKey);
    _playerId = prefs.getString(_playerIdKey);
  }

  @override
  Future<void> saveJwt(String jwt) async {
    _jwt = jwt;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_jwtKey, jwt);
  }

  @override
  String? get jwt => _jwt;

  @override
  Future<void> savePlayerId(String playerId) async {
    _playerId = playerId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playerIdKey, playerId);
  }

  @override
  String? get playerId => _playerId;

  @override
  Future<void> clear() async {
    _jwt = null;
    _playerId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_jwtKey);
    await prefs.remove(_playerIdKey);
  }

  @override
  bool get hasToken => _jwt != null;
}
