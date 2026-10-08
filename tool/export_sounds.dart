// Exporta todos los sonidos del juego como archivos .wav para escucharlos en el ordenador.
//   OUT_DIR=<carpeta> flutter test tool/export_sounds.dart
import 'dart:io';

import 'package:coco_loco/core/synth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exporta los sonidos', () {
    final out = Directory(Platform.environment['OUT_DIR']!)..createSync(recursive: true);
    const names = {
      Sfx.catchCoco: '01_atrapar_coco',
      Sfx.golden: '02_coco_dorado',
      Sfx.combo: '03_racha',
      Sfx.powerUp: '04_poder',
      Sfx.shieldBlock: '05_escudo_bloquea',
      Sfx.miss: '06_coco_perdido',
      Sfx.hit: '07_golpe_roca',
      Sfx.bomb: '08_bomba',
      Sfx.tick: '09_cuenta_atras',
      Sfx.go: '10_ya',
      Sfx.win: '11_ganar',
      Sfx.lose: '12_perder',
      Sfx.click: '13_clic',
    };
    for (final e in names.entries) {
      File('${out.path}/${e.value}.wav').writeAsBytesSync(sfxWav(e.key));
    }
    File('${out.path}/00_musica_de_fondo.wav').writeAsBytesSync(musicWav());
  });
}
