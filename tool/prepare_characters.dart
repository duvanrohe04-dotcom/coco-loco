// Recorta las fotos de los personajes a un cuadrado centrado en la cara y las guarda (256x256) en
// assets/characters/. Se ejecuta con:
//   SRC_DIR=<carpeta con las fotos originales> OUT_DIR=<carpeta de salida> flutter test tool/prepare_characters.dart
// (OUT_DIR puede ser una carpeta temporal si el antivirus bloquea escribir en el proyecto; luego se copia.)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Recorte como fracciones de la foto original: izquierda, arriba y lado (relativo al ANCHO).
class _Crop {
  const _Crop(this.file, this.out, this.left, this.top, this.side);

  final String file;
  final String out;
  final double left;
  final double top;
  final double side;
}

const _crops = [
  _Crop('9.webp', 'p1.png', 0.2670, 0.1105, 0.3683),
  _Crop('10.png', 'p2.png', 0.1080, 0.0530, 0.7374),
  _Crop('11.png', 'p3.png', 0.0524, 0.0862, 0.9090),
];

void main() {
  testWidgets('recorta las caras', (tester) async {
    final src = Platform.environment['SRC_DIR']!;
    final out = Platform.environment['OUT_DIR']!;
    await tester.runAsync(() async {
      for (final c in _crops) {
        final bytes = File('$src/${c.file}').readAsBytesSync();
        final codec = await ui.instantiateImageCodec(bytes);
        final img = (await codec.getNextFrame()).image;
        final w = img.width.toDouble(), h = img.height.toDouble();
        final side = c.side * w;
        final rect = ui.Rect.fromLTWH(c.left * w, c.top * h, side, side);
        // ignore: avoid_print
        print('${c.file}: ${img.width}x${img.height} -> recorte ${rect.left.round()},${rect.top.round()} lado ${side.round()}');

        const size = 256.0;
        final rec = ui.PictureRecorder();
        ui.Canvas(rec).drawImageRect(
          img,
          rect,
          const ui.Rect.fromLTWH(0, 0, size, size),
          ui.Paint()..filterQuality = ui.FilterQuality.high..isAntiAlias = true,
        );
        final cropped = await rec.endRecording().toImage(size.toInt(), size.toInt());
        final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
        File('$out/${c.out}')
          ..createSync(recursive: true)
          ..writeAsBytesSync(data!.buffer.asUint8List());
      }
    });
  });
}
