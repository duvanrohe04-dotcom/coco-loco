import 'dart:math';
import 'dart:typed_data';

/// Sintetizador mínimo: genera los efectos de sonido y la música del juego como archivos WAV en
/// memoria. Así el juego no depende de archivos de audio (ni de sus derechos de autor).

const int sampleRate = 22050;

enum Wave { sine, square, triangle, saw }

enum Sfx { catchCoco, golden, powerUp, shieldBlock, hit, bomb, miss, combo, tick, go, win, lose, click }

double _osc(Wave w, double cycles) {
  final p = cycles - cycles.floorToDouble();
  switch (w) {
    case Wave.sine:
      return sin(2 * pi * p);
    case Wave.square:
      return p < 0.5 ? 1.0 : -1.0;
    case Wave.triangle:
      return 1 - 4 * (p - 0.5).abs();
    case Wave.saw:
      return 2 * p - 1;
  }
}

/// Mezclador: se van sumando notas y ruidos en un único búfer de muestras.
class Mixer {
  Mixer(double seconds, {this.loop = false}) : buf = Float64List((seconds * sampleRate).ceil());

  final Float64List buf;

  /// Si es true, lo que se sale por el final vuelve a entrar por el principio (música sin cortes al repetir).
  final bool loop;

  void _add(int i, double v) {
    if (loop) {
      buf[i % buf.length] += v;
    } else if (i < buf.length) {
      buf[i] += v;
    }
  }

  /// Una nota: [freq] (Hz) puede deslizarse hasta [freqEnd]. [decay] mayor = se apaga antes.
  void note(
    double start,
    double dur,
    double freq, {
    double? freqEnd,
    Wave wave = Wave.sine,
    double vol = 0.5,
    double decay = 8,
    double attack = 0.004,
  }) {
    final n = (dur * sampleRate).floor();
    final s0 = (start * sampleRate).floor();
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final f = freqEnd == null ? freq : freq + (freqEnd - freq) * (i / n);
      phase += f / sampleRate;
      var env = exp(-decay * t);
      if (t < attack) env *= t / attack;
      final tail = n - i;
      if (tail < 110) env *= tail / 110; // se apaga en 5 ms: sin "clics"
      _add(s0 + i, _osc(wave, phase) * env * vol);
    }
  }

  /// Ruido (golpes, explosiones, platillos). [lowpass] 0..1: menor = más grave; 1 = ruido blanco.
  void noise(double start, double dur, {double vol = 0.4, double decay = 20, double lowpass = 1, bool highpass = false, int seed = 1}) {
    final rnd = Random(seed);
    final n = (dur * sampleRate).floor();
    final s0 = (start * sampleRate).floor();
    var y = 0.0, prev = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final x = rnd.nextDouble() * 2 - 1;
      y += lowpass * (x - y);
      var v = y;
      if (highpass) {
        v = x - prev; // diferencia: deja pasar los agudos
        prev = x;
      }
      final tail = n - i;
      final fade = tail < 110 ? tail / 110 : 1.0;
      _add(s0 + i, v * exp(-decay * t) * vol * fade);
    }
  }

  /// Convierte a WAV de 16 bits (mono). [gain] sube o baja el volumen; nunca se pasa de rango.
  Uint8List toWav({double gain = 1}) {
    final data = ByteData(44 + buf.length * 2);
    void str(int off, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(off + i, s.codeUnitAt(i));
      }
    }

    final bytes = buf.length * 2;
    str(0, 'RIFF');
    data.setUint32(4, 36 + bytes, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, bytes, Endian.little);
    for (var i = 0; i < buf.length; i++) {
      final v = (buf[i] * gain).clamp(-0.98, 0.98);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }
}

// Notas (Hz).
const double _c4 = 261.63, _e4 = 329.63, _g4 = 392.00;
const double _c5 = 523.25, _d5 = 587.33, _e5 = 659.25, _g5 = 783.99, _a5 = 880.0, _c6 = 1046.5, _e6 = 1318.5;

/// El efecto [s] como WAV. Cada uno dura menos de 1,5 s para que se pueda repetir con rapidez.
Uint8List sfxWav(Sfx s) {
  switch (s) {
    case Sfx.catchCoco:
      final m = Mixer(0.16)
        ..note(0, 0.1, 520, freqEnd: 800, wave: Wave.triangle, vol: 0.6, decay: 12)
        ..note(0.02, 0.1, 1040, vol: 0.22, decay: 22);
      return m.toWav();
    case Sfx.golden:
      final m = Mixer(0.45);
      const notes = [784.0, 988.0, 1319.0];
      for (var i = 0; i < notes.length; i++) {
        m.note(i * 0.06, 0.25, notes[i], vol: 0.45, decay: 9);
        m.note(i * 0.06, 0.2, notes[i] * 2, vol: 0.12, decay: 14);
      }
      m.note(0.14, 0.3, 2637, vol: 0.12, decay: 12);
      return m.toWav();
    case Sfx.powerUp:
      final m = Mixer(0.6);
      const notes = [_c5, _e5, _g5, _c6];
      for (var i = 0; i < notes.length; i++) {
        m.note(i * 0.07, 0.3, notes[i], wave: Wave.triangle, vol: 0.45, decay: 7);
        m.note(i * 0.07, 0.25, notes[i] * 2, vol: 0.15, decay: 10);
      }
      return m.toWav();
    case Sfx.shieldBlock:
      final m = Mixer(0.35)
        ..note(0, 0.3, 1400, freqEnd: 900, vol: 0.45, decay: 11)
        ..note(0, 0.25, 2800, vol: 0.18, decay: 18)
        ..noise(0, 0.08, vol: 0.28, decay: 40, highpass: true);
      return m.toWav();
    case Sfx.hit:
      final m = Mixer(0.3)
        ..note(0, 0.25, 160, freqEnd: 55, vol: 0.85, decay: 9)
        ..noise(0, 0.14, vol: 0.4, decay: 22, lowpass: 0.25);
      return m.toWav();
    case Sfx.bomb:
      final m = Mixer(0.7)
        ..noise(0, 0.6, vol: 0.85, decay: 5, lowpass: 0.09, seed: 3)
        ..note(0, 0.55, 120, freqEnd: 35, vol: 0.95, decay: 5);
      return m.toWav(gain: 0.9);
    case Sfx.miss:
      final m = Mixer(0.25)..note(0, 0.2, 330, freqEnd: 170, wave: Wave.square, vol: 0.2, decay: 8);
      return m.toWav();
    case Sfx.combo:
      final m = Mixer(0.6);
      const notes = [_c5, _e5, _g5, _c6, _e6];
      for (var i = 0; i < notes.length; i++) {
        m.note(i * 0.06, i == notes.length - 1 ? 0.3 : 0.18, notes[i], wave: Wave.triangle, vol: 0.5, decay: 6);
        m.note(i * 0.06, 0.15, notes[i] * 2, vol: 0.12, decay: 12);
      }
      return m.toWav();
    case Sfx.tick:
      final m = Mixer(0.12)..note(0, 0.09, 660, vol: 0.4, decay: 24);
      return m.toWav();
    case Sfx.go:
      final m = Mixer(0.4)
        ..note(0, 0.35, 990, vol: 0.5, decay: 6)
        ..note(0, 0.3, 1320, vol: 0.22, decay: 8);
      return m.toWav();
    case Sfx.win:
      final m = Mixer(1.5);
      const notes = [_c5, _e5, _g5, _c6, _e6];
      for (var i = 0; i < notes.length; i++) {
        final last = i == notes.length - 1;
        m.note(i * 0.13, last ? 0.9 : 0.25, notes[i], wave: Wave.triangle, vol: 0.5, decay: last ? 3 : 6);
        m.note(i * 0.13, last ? 0.8 : 0.2, notes[i] / 2, vol: 0.25, decay: last ? 3 : 8);
      }
      m.note(0.65, 0.8, _g5, vol: 0.2, decay: 3);
      return m.toWav();
    case Sfx.lose:
      final m = Mixer(1.2);
      const notes = [_g4, _e4, _c4];
      for (var i = 0; i < notes.length; i++) {
        m.note(i * 0.22, i == notes.length - 1 ? 0.7 : 0.3, notes[i], wave: Wave.triangle, vol: 0.5, decay: 4);
      }
      return m.toWav();
    case Sfx.click:
      final m = Mixer(0.08)..note(0, 0.05, 800, vol: 0.35, decay: 55);
      return m.toWav();
  }
}

/// Música de fondo (bucle de ~16 s): ritmo alegre tropical con marimba, bajo y percusión suave.
/// Está hecha para repetirse sin cortes (las colas de las notas "dan la vuelta" al principio).
Uint8List musicWav() {
  const bpm = 116.0;
  const beat = 60 / bpm;
  const bars = 8;
  final m = Mixer(bars * 4 * beat, loop: true);
  final rnd = Random(11);

  // Acordes por compás: C, G, Am, F, C, G, F, G (raíz grave y tres notas para el arpegio).
  const chords = [
    [130.81, 261.63, 329.63, 392.00], // C
    [98.00, 196.00, 246.94, 293.66], // G
    [110.00, 220.00, 261.63, 329.63], // Am
    [87.31, 174.61, 220.00, 261.63], // F
    [130.81, 261.63, 329.63, 392.00], // C
    [98.00, 196.00, 246.94, 293.66], // G
    [87.31, 174.61, 220.00, 261.63], // F
    [98.00, 196.00, 246.94, 293.66], // G
  ];
  // Escala pentatónica para la melodía.
  const scale = [_c5, _d5, _e5, _g5, _a5, _c6];

  var lastIdx = 2;
  for (var bar = 0; bar < bars; bar++) {
    final chord = chords[bar];
    final t0 = bar * 4 * beat;

    // Bajo: pulsos 1 y 3, y un contratiempo.
    m.note(t0, beat * 0.9, chord[0], wave: Wave.triangle, vol: 0.5, decay: 3.5);
    m.note(t0 + beat * 2, beat * 0.9, chord[0], wave: Wave.triangle, vol: 0.45, decay: 3.5);
    m.note(t0 + beat * 3.5, beat * 0.4, chord[0] * 1.5, wave: Wave.triangle, vol: 0.3, decay: 6);

    // Marimba: arpegio en corcheas (dos golpes por pulso).
    for (var k = 0; k < 8; k++) {
      final tone = chord[1 + (const [0, 1, 2, 1, 0, 2, 1, 2][k] % 3)];
      final at = t0 + k * beat / 2;
      m.note(at, beat * 0.6, tone, vol: 0.2, decay: 7);
      m.note(at, beat * 0.2, tone * 4, vol: 0.05, decay: 30); // el "tac" de la marimba
    }

    // Melodía: sube y baja por la escala, con silencios.
    for (var k = 0; k < 8; k++) {
      if (rnd.nextDouble() < 0.35) continue;
      lastIdx = (lastIdx + (rnd.nextInt(3) - 1)).clamp(0, scale.length - 1);
      final at = t0 + k * beat / 2;
      m.note(at, beat * 0.55, scale[lastIdx], wave: Wave.triangle, vol: 0.22, decay: 5);
    }

    // Percusión: bombo en 1 y 3, caja suave en 2 y 4, platillo en los contratiempos.
    for (var b = 0; b < 4; b++) {
      final at = t0 + b * beat;
      if (b.isEven) m.note(at, 0.16, 110, freqEnd: 42, vol: 0.55, decay: 14);
      if (b.isOdd) m.noise(at, 0.1, vol: 0.12, decay: 28, lowpass: 0.35, seed: bar * 4 + b);
      m.noise(at + beat / 2, 0.05, vol: 0.07, decay: 45, highpass: true, seed: 50 + bar * 4 + b);
    }
  }
  return m.toWav(gain: 0.85);
}
