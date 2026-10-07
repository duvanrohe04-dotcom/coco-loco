import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// URL del backend. Se fija al compilar:
/// `flutter build apk --dart-define=API_URL=https://tu-servidor.com`
/// Si está vacía, el juego funciona solo con perfiles locales.
const apiUrl = String.fromEnvironment('API_URL');

bool get onlineEnabled => apiUrl.isNotEmpty;

class ApiException implements Exception {
  ApiException(this.message, {this.status});

  final String message;

  /// Código HTTP, o null si no hubo respuesta (sin red, tiempo agotado...).
  final int? status;

  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

/// Perfil tal como lo devuelve el servidor.
class RemoteProfile {
  RemoteProfile({required this.username, required this.character, required this.stars, required this.streaks});

  factory RemoteProfile.fromJson(Map<String, dynamic> j) => RemoteProfile(
        username: j['username'] as String,
        character: j['character'] as String,
        stars: _intMap(j['stars']),
        streaks: _intMap(j['streaks']),
      );

  final String username;
  final String character;
  final Map<int, int> stars;
  final Map<int, int> streaks;

  static Map<int, int> _intMap(Object? raw) => {
        for (final e in (raw as Map? ?? const {}).entries) int.parse('${e.key}'): (e.value as num).toInt(),
      };
}

class AuthResult {
  AuthResult(this.token, this.profile);

  final String token;
  final RemoteProfile profile;
}

class LeaderboardEntry {
  LeaderboardEntry({required this.username, required this.character, required this.stars, required this.bestStreak});

  final String username;
  final String character;
  final int stars;
  final int bestStreak;
}

/// Cliente mínimo de la API (ver /backend/README.md).
class Api {
  Api._();

  static const _timeout = Duration(seconds: 12);
  static final _base = Uri.parse(apiUrl.endsWith('/') ? apiUrl.substring(0, apiUrl.length - 1) : apiUrl);

  static Future<AuthResult> register(String username, String password) => _auth('register', username, password);

  static Future<AuthResult> login(String username, String password) => _auth('login', username, password);

  static Future<AuthResult> _auth(String route, String username, String password) async {
    final j = await _send('POST', '/api/$route', body: {'username': username, 'password': password});
    return AuthResult(j['token'] as String, RemoteProfile.fromJson(j['profile'] as Map<String, dynamic>));
  }

  static Future<RemoteProfile> me(String token) async => RemoteProfile.fromJson(await _send('GET', '/api/me', token: token));

  static Future<void> setCharacter(String token, String character) =>
      _send('PUT', '/api/me', token: token, body: {'character': character});

  static Future<void> pushProgress(String token, int level, int stars, int streak) =>
      _send('PUT', '/api/progress', token: token, body: {'level': level, 'stars': stars, 'streak': streak});

  /// Envía todo el progreso local y devuelve el resultado fusionado del servidor.
  static Future<RemoteProfile> mergeProgress(String token, Map<int, int> stars, Map<int, int> streaks) async {
    final j = await _send('POST', '/api/progress/merge', token: token, body: {
      'stars': {for (final e in stars.entries) '${e.key}': e.value},
      'streaks': {for (final e in streaks.entries) '${e.key}': e.value},
    });
    return RemoteProfile.fromJson(j);
  }

  static Future<void> logout(String token) => _send('POST', '/api/logout', token: token);

  static Future<void> deleteAccount(String token) => _send('DELETE', '/api/me', token: token);

  static Future<List<LeaderboardEntry>> leaderboard() async {
    final j = await _send('GET', '/api/leaderboard');
    return [
      for (final p in (j['players'] as List).cast<Map<String, dynamic>>())
        LeaderboardEntry(
          username: p['username'] as String,
          character: p['character'] as String,
          stars: (p['stars'] as num).toInt(),
          bestStreak: (p['bestStreak'] as num).toInt(),
        ),
    ];
  }

  static Future<Map<String, dynamic>> _send(String method, String path, {String? token, Map<String, Object?>? body}) async {
    final req = http.Request(method, _base.replace(path: path))
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);

    final http.Response res;
    try {
      res = await http.Response.fromStream(await req.send().timeout(_timeout)).timeout(_timeout);
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado en responder');
    } catch (_) {
      throw ApiException('No se pudo conectar con el servidor. Revisa tu internet.');
    }

    Map<String, dynamic> json = const {};
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      // Respuesta que no es JSON (p. ej. página de error de un proxy).
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return json;
    throw ApiException(json['error'] as String? ?? 'Error del servidor (${res.statusCode})', status: res.statusCode);
  }
}
