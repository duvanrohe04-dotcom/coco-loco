import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/characters.dart';
import 'api.dart';
import 'progress.dart';

/// Perfil de jugador. Puede ser local (solo en este dispositivo) o una cuenta en línea.
class Profile {
  Profile({required this.id, required this.name, required this.character, this.remote = false});

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        name: j['name'] as String,
        character: _characterByName(j['character'] as String?),
        remote: j['remote'] == true,
      );

  final String id;
  String name;
  Character character;

  /// Cuenta en el servidor: su progreso se sincroniza.
  final bool remote;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'character': character.name, 'remote': remote};
}

Character _characterByName(String? name) => Character.values.firstWhere((c) => c.name == name, orElse: () => Character.mochi);

/// Perfiles y sesión activa.
///
/// - Perfiles locales: viven solo en este dispositivo, sin contraseña.
/// - Cuentas en línea (si la app se compiló con `API_URL`): usuario y contraseña
///   verificados por el servidor; el progreso se guarda también en la nube.
class Session extends ChangeNotifier {
  static const minName = 2, maxName = 14, maxProfiles = 8;
  static const _kProfiles = 'profiles';
  static const _kCurrent = 'current';

  SharedPreferences? _prefs;
  final List<Profile> profiles = [];
  Profile? current;

  bool get isSignedIn => current != null;

  String? _token(Profile p) => _prefs?.getString('token.${p.id}');

  bool hasToken(Profile p) => _token(p) != null;

  /// Hay una cuenta en línea abierta con sesión válida en este dispositivo.
  bool get isOnline => current != null && current!.remote && _token(current!) != null;

  /// Lee los perfiles guardados y retoma la última sesión.
  Future<void> load() async {
    // Puede llamarse de nuevo (reintento al arrancar): empieza limpio para no duplicar perfiles.
    profiles.clear();
    current = null;
    try {
      final prefs = _prefs = await SharedPreferences.getInstance();
      for (final raw in prefs.getStringList(_kProfiles) ?? const <String>[]) {
        try {
          profiles.add(Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>));
        } catch (_) {
          // Entrada dañada: se ignora.
        }
      }
      final id = prefs.getString(_kCurrent);
      final found = profiles.where((p) => p.id == id);
      if (found.isNotEmpty) {
        final p = found.first;
        if (p.remote && _token(p) == null) {
          prefs.remove(_kCurrent); // sesión en línea caducada: vuelve al login
        } else {
          _activate(p);
        }
      }
    } catch (_) {
      // Sin almacenamiento (modo privado, etc.): se juega igual, sin guardar.
    }
    selectedCharacter
      ..removeListener(_onCharacterChanged)
      ..addListener(_onCharacterChanged);
    progress.onRecorded = _pushProgress;
    if (isOnline) unawaited(syncNow()); // sin esperar: el juego abre al instante
  }

  /// null si el nombre es válido; si no, el motivo.
  String? validateName(String raw, {Profile? except}) {
    final name = raw.trim();
    if (name.length < minName) return 'Escribe al menos $minName letras';
    if (name.length > maxName) return 'Máximo $maxName letras';
    final taken = profiles.any((p) => p != except && !p.remote && p.name.toLowerCase() == name.toLowerCase());
    return taken ? 'Ese nombre ya existe' : null;
  }

  bool get canCreate => profiles.length < maxProfiles;

  Profile create(String name, Character character) {
    final p = Profile(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name.trim(), character: character);
    profiles.add(p);
    _saveProfiles();
    signIn(p);
    return p;
  }

  /// Crea una cuenta nueva o entra a una existente en el servidor.
  /// Devuelve null si salió bien, o el mensaje de error para mostrar.
  Future<String?> signInOnline(String username, String password, {required bool register}) async {
    try {
      final auth = register ? await Api.register(username, password) : await Api.login(username, password);
      final id = 'online:${auth.profile.username.toLowerCase()}';
      var p = profiles.where((x) => x.id == id).firstOrNull;
      if (p == null) {
        p = Profile(id: id, name: auth.profile.username, character: _characterByName(auth.profile.character), remote: true);
        profiles.add(p);
      } else {
        p.name = auth.profile.username;
      }
      await _prefs?.setString('token.$id', auth.token);
      _saveProfiles();
      p.character = _characterByName(auth.profile.character);
      signIn(p);
      progress.mergeRemote(auth.profile.stars, auth.profile.streaks);
      unawaited(syncNow()); // sube lo que ya había jugado en este dispositivo
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  void signIn(Profile p) {
    _activate(p);
    _prefs?.setString(_kCurrent, p.id);
    notifyListeners();
  }

  void signOut() {
    final p = current;
    final token = p == null || !p.remote ? null : _token(p);
    if (p != null && token != null) {
      // Cierra también la sesión en el servidor (si falla, el token caduca solo).
      unawaited(Api.logout(token).catchError((Object _) {}));
      _prefs?.remove('token.${p.id}');
    }
    current = null;
    progress.attach(_prefs, null);
    _prefs?.remove(_kCurrent);
    notifyListeners();
  }

  void rename(Profile p, String name) {
    if (p.remote) return; // el nombre de una cuenta en línea no cambia
    p.name = name.trim();
    _saveProfiles();
    notifyListeners();
  }

  /// Borra el perfil. Una cuenta en línea también se borra del servidor.
  /// Devuelve null si salió bien, o el motivo del fallo.
  Future<String?> delete(Profile p) async {
    final token = p.remote ? _token(p) : null;
    if (token != null) {
      try {
        await Api.deleteAccount(token);
      } on ApiException catch (e) {
        if (!e.isUnauthorized) return e.message; // sin red: no se borra a medias
      }
    }
    final wasCurrent = identical(current, p);
    profiles.remove(p);
    _saveProfiles();
    final prefs = _prefs;
    if (prefs != null) {
      await Progress.forget(prefs, p.id);
      await prefs.remove('token.${p.id}');
    }
    if (wasCurrent) {
      current = null;
      progress.attach(_prefs, null);
      _prefs?.remove(_kCurrent);
    }
    notifyListeners();
    return null;
  }

  /// Fusiona el progreso local con el del servidor (el mejor valor gana).
  Future<void> syncNow() async {
    final p = current;
    final token = p == null ? null : _token(p);
    if (p == null || token == null) return;
    try {
      final remote = await Api.mergeProgress(token, progress.starsSnapshot, progress.streaksSnapshot);
      if (!identical(current, p)) return; // cambió de jugador mientras tanto
      progress.mergeRemote(remote.stars, remote.streaks);
    } on ApiException catch (e) {
      if (e.isUnauthorized) _expire(p);
      // Sin conexión: se reintentará en el próximo arranque o al jugar.
    }
  }

  void _expire(Profile p) {
    _prefs?.remove('token.${p.id}');
    if (identical(current, p)) {
      current = null;
      progress.attach(_prefs, null);
      _prefs?.remove(_kCurrent);
      notifyListeners();
    }
  }

  void _pushProgress(int level, int stars, int streak) {
    final p = current;
    final token = p == null || !p.remote ? null : _token(p);
    if (p == null || token == null) return;
    Api.pushProgress(token, level, stars, streak).catchError((Object e) {
      if (e is ApiException && e.isUnauthorized) _expire(p);
      // Si no hay red, syncNow() lo subirá la próxima vez.
    });
  }

  void _activate(Profile p) {
    current = p;
    selectedCharacter.value = p.character;
    progress.attach(_prefs, p.id);
  }

  void _onCharacterChanged() {
    final p = current;
    if (p == null || p.character == selectedCharacter.value) return;
    p.character = selectedCharacter.value;
    _saveProfiles();
    final token = p.remote ? _token(p) : null;
    if (token != null) {
      Api.setCharacter(token, p.character.name).catchError((Object _) {});
    }
    notifyListeners();
  }

  void _saveProfiles() => _prefs?.setStringList(_kProfiles, [for (final p in profiles) jsonEncode(p.toJson())]);
}

final session = Session();
