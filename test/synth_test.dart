import 'dart:math';
import 'dart:typed_data';

import 'package:coco_loco/core/synth.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lee un WAV de 16 bits mono y devuelve sus muestras entre -1 y 1.
({int rate, int channels, int bits, List<double> samples}) readWav(Uint8List wav) {
  final d = ByteData.sublistView(wav);
  String tag(int o) => String.fromCharCodes(wav.sublist(o, o + 4));
  expect(tag(0), 'RIFF');
  expect(tag(8), 'WAVE');
  expect(tag(12), 'fmt ');
  expect(tag(36), 'data');
  expect(d.getUint32(4, Endian.little), wav.length - 8, reason: 'tamaño RIFF');
  final dataLen = d.getUint32(40, Endian.little);
  expect(dataLen, wav.length - 44, reason: 'tamaño de datos');
  return (
    rate: d.getUint32(24, Endian.little),
    channels: d.getUint16(22, Endian.little),
    bits: d.getUint16(34, Endian.little),
    samples: [for (var i = 0; i < dataLen ~/ 2; i++) d.getInt16(44 + i * 2, Endian.little) / 32768],
  );
}

double peak(List<double> s) => s.map((v) => v.abs()).reduce(max);
double rms(List<double> s) => sqrt(s.fold<double>(0, (a, v) => a + v * v) / s.length);

void main() {
  group('efectos de sonido', () {
    for (final sfx in Sfx.values) {
      test('${sfx.name}: WAV válido, con sonido y sin saturar', () {
        final w = readWav(sfxWav(sfx));
        expect(w.rate, sampleRate);
        expect(w.channels, 1);
        expect(w.bits, 16);
        final seconds = w.samples.length / w.rate;
        expect(seconds, inInclusiveRange(0.05, 2.0), reason: 'duración');
        expect(peak(w.samples), inInclusiveRange(0.15, 0.99), reason: 'se oye y no distorsiona');
        expect(rms(w.samples), greaterThan(0.01), reason: 'no es silencio');
      });
    }

    test('los efectos empiezan y acaban sin "clics" (arrancan y terminan cerca de cero)', () {
      for (final sfx in Sfx.values) {
        final s = readWav(sfxWav(sfx)).samples;
        expect(s.last.abs(), lessThan(0.02), reason: '${sfx.name} termina brusco');
        expect(s.first.abs(), lessThan(0.05), reason: '${sfx.name} empieza brusco');
      }
    });

    test('el sonido de atrapar es agudo y el golpe es grave', () {
      double dominant(List<double> s) {
        // Frecuencia aproximada por cruces de cero en los primeros 40 ms.
        final n = (0.04 * sampleRate).floor();
        var crossings = 0;
        for (var i = 1; i < n; i++) {
          if ((s[i - 1] < 0) != (s[i] < 0)) crossings++;
        }
        return crossings / 2 / 0.04;
      }

      final catchF = dominant(readWav(sfxWav(Sfx.catchCoco)).samples);
      final hitF = dominant(readWav(sfxWav(Sfx.hit)).samples);
      expect(catchF, greaterThan(400));
      expect(hitF, lessThan(catchF), reason: 'el golpe debe sonar más grave que atrapar un coco');
    });
  });

  group('música', () {
    test('es un bucle de unos 16 s, audible y sin saturar', () {
      final w = readWav(musicWav());
      final seconds = w.samples.length / w.rate;
      expect(seconds, inInclusiveRange(15.0, 18.0));
      expect(peak(w.samples), inInclusiveRange(0.3, 0.99));
      expect(rms(w.samples), inInclusiveRange(0.03, 0.4), reason: 'volumen de fondo razonable');
    });

    test('no tiene tramos mudos largos (siempre suena algo)', () {
      final s = readWav(musicWav()).samples;
      const window = sampleRate ~/ 2; // medio segundo
      for (var i = 0; i + window <= s.length; i += window) {
        expect(rms(s.sublist(i, i + window)), greaterThan(0.005), reason: 'silencio cerca de ${(i / sampleRate).toStringAsFixed(1)} s');
      }
    });

    test('es determinista: dos generaciones dan exactamente lo mismo', () {
      expect(musicWav(), musicWav());
    });
  });
}
