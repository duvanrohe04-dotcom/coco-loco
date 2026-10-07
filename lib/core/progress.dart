import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/level.dart';

/// Progreso del jugador activo (estrellas y mejor racha por nivel).
/// Cada perfil guarda lo suyo con su propio prefijo; lo gestiona [Session].
class Progress extends ChangeNotifier {
  SharedPreferences? _prefs;
  String? _profileId;
  final Map<int, int> _stars = {};
  final Map<int, int> _streaks = {};

  int starsFor(int level) => _stars[level] ?? 0;

  int bestStreakFor(int level) => _streaks[level] ?? 0;

  bool isUnlocked(int level) => level == 1 || starsFor(level - 1) > 0;

  /// Copias de solo lectura para sincronizar con el servidor.
  Map<int, int> get starsSnapshot => Map.unmodifiable(_stars);

  Map<int, int> get streaksSnapshot => Map.unmodifiable(_streaks);

  /// Se llama al mejorar un resultado (lo usa [Session] para subirlo a la nube).
  void Function(int level, int stars, int streak)? onRecorded;

  int get totalStars => _stars.values.fold(0, (a, b) => a + b);

  int get levelsCompleted => _stars.values.where((s) => s > 0).length;

  int get bestStreak => _streaks.values.fold(0, (a, b) => a > b ? a : b);

  /// Carga el progreso de [profileId] (o lo deja vacío si es null).
  void attach(SharedPreferences? prefs, String? profileId) {
    _prefs = prefs;
    _profileId = profileId;
    _stars.clear();
    _streaks.clear();
    if (prefs != null && profileId != null) {
      _readMap(prefs.getStringList(_key('stars')), _stars);
      _readMap(prefs.getStringList(_key('streaks')), _streaks);
    }
    notifyListeners();
  }

  void record(Level level, int stars, {int streak = 0}) {
    var changed = false;
    if (stars > starsFor(level.number)) {
      _stars[level.number] = stars;
      changed = true;
    }
    if (streak > bestStreakFor(level.number)) {
      _streaks[level.number] = streak;
      changed = true;
    }
    if (!changed) return;
    _save();
    notifyListeners();
    onRecorded?.call(level.number, starsFor(level.number), bestStreakFor(level.number));
  }

  /// Incorpora el progreso del servidor quedándose siempre con el mejor valor.
  void mergeRemote(Map<int, int> stars, Map<int, int> streaks) {
    var changed = false;
    stars.forEach((k, v) {
      if (v > starsFor(k)) {
        _stars[k] = v;
        changed = true;
      }
    });
    streaks.forEach((k, v) {
      if (v > bestStreakFor(k)) {
        _streaks[k] = v;
        changed = true;
      }
    });
    if (!changed) return;
    _save();
    notifyListeners();
  }

  /// Borra el progreso del perfil activo.
  void reset() {
    _stars.clear();
    _streaks.clear();
    _save();
    notifyListeners();
  }

  /// Elimina lo guardado de un perfil (al borrarlo).
  static Future<void> forget(SharedPreferences prefs, String profileId) async {
    await prefs.remove('$profileId.stars');
    await prefs.remove('$profileId.streaks');
  }

  String _key(String name) => '$_profileId.$name';

  static void _readMap(List<String>? raw, Map<int, int> into) {
    for (final entry in raw ?? const <String>[]) {
      final parts = entry.split(':');
      final k = int.tryParse(parts.first);
      final v = parts.length == 2 ? int.tryParse(parts[1]) : null;
      if (k != null && v != null) into[k] = v;
    }
  }

  static List<String> _encode(Map<int, int> m) => [for (final e in m.entries) '${e.key}:${e.value}'];

  void _save() {
    if (_profileId == null) return;
    _prefs?.setStringList(_key('stars'), _encode(_stars));
    _prefs?.setStringList(_key('streaks'), _encode(_streaks));
  }
}

final progress = Progress();
