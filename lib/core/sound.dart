import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'synth.dart';

/// Reproduce los efectos y la música generados por [synth.dart].
///
/// Todo está envuelto en `try/catch`: si el dispositivo no puede reproducir audio (o el navegador lo
/// bloquea hasta que el usuario toque la pantalla), el juego sigue funcionando en silencio.
class Sound {
  Sound._();

  static final Sound instance = Sound._();

  static const _prefKey = 'sound_on';
  static const double _musicVolume = 0.32;

  /// Sonido activado (efectos y música). Se guarda en el dispositivo.
  final ValueNotifier<bool> enabled = ValueNotifier(true);

  SharedPreferences? _prefs;
  final Map<Sfx, AudioPlayer> _players = {};
  AudioPlayer? _music;
  bool _musicWanted = false;
  bool _musicPaused = false;

  /// Lee si el jugador lo había silenciado.
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      enabled.value = _prefs?.getBool(_prefKey) ?? true;
    } catch (_) {
      // Sin almacenamiento: se queda activado.
    }
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    unawaited(_prefs?.setBool(_prefKey, value).catchError((Object _) => false));
    if (!value) {
      await _safe(() => _music?.pause());
    } else if (_musicWanted && !_musicPaused) {
      await _safe(() => _music?.resume());
    }
  }

  Future<void> toggle() => setEnabled(!enabled.value);

  /// Prepara los efectos para que suenen sin retraso la primera vez.
  Future<void> preload(Iterable<Sfx> kinds) async {
    for (final k in kinds) {
      await _player(k);
    }
  }

  Future<AudioPlayer?> _player(Sfx kind) async {
    final existing = _players[kind];
    if (existing != null) return existing;
    try {
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume(kind == Sfx.bomb || kind == Sfx.hit ? 1.0 : 0.85);
      await p.setSource(BytesSource(sfxWav(kind), mimeType: 'audio/wav'));
      _players[kind] = p;
      return p;
    } catch (e) {
      debugPrint('Sonido (${kind.name}): $e');
      return null;
    }
  }

  /// Reproduce un efecto (sin esperar a que termine).
  void play(Sfx kind) {
    if (!enabled.value) return;
    unawaited(_play(kind));
  }

  Future<void> _play(Sfx kind) async {
    await _safe(() async {
      final p = await _player(kind);
      if (p == null) return;
      await p.stop();
      await p.resume();
    });
  }

  // ---- Música ----

  /// Empieza la música en bucle (si el sonido está activado).
  void startMusic() {
    _musicWanted = true;
    _musicPaused = false;
    unawaited(_startMusic());
  }

  Future<void> _startMusic() async {
    await _safe(() async {
      var m = _music;
      if (m == null) {
        m = _music = AudioPlayer();
        await m.setReleaseMode(ReleaseMode.loop);
        await m.setVolume(_musicVolume);
        await m.setSource(BytesSource(musicWav(), mimeType: 'audio/wav'));
      }
      if (_musicWanted && !_musicPaused && enabled.value) await m.resume();
    });
  }

  /// Detiene la música (al salir del nivel).
  void stopMusic() {
    _musicWanted = false;
    unawaited(_safe(() => _music?.stop()));
  }

  /// Pausa/reanuda la música (pausa del juego o app en segundo plano).
  void pauseMusic() {
    _musicPaused = true;
    unawaited(_safe(() => _music?.pause()));
  }

  void resumeMusic() {
    _musicPaused = false;
    if (_musicWanted && enabled.value) unawaited(_safe(() => _music?.resume()));
  }

  /// La música se vuelve más lenta y grave en cámara lenta.
  void setMusicSlow(bool slow) => unawaited(_safe(() => _music?.setPlaybackRate(slow ? 0.8 : 1.0)));

  Future<void> _safe(FutureOr<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      // El audio nunca debe romper el juego, pero el error queda en la consola para poder diagnosticarlo.
      debugPrint('Sonido: $e');
    }
  }
}
