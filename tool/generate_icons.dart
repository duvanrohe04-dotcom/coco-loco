// Genera los íconos del juego (web y Android) dibujando a Mochi sobre el degradado del atardecer.
// Se ejecuta con:   flutter test tool/generate_icons.dart
// Reescribe web/favicon.png, web/icons/*.png y los android/.../mipmap-*/ic_launcher.png.
// Con la variable ICON_OUT=<carpeta> escribe ahí (misma estructura de carpetas) en vez de en el proyecto.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coco_loco/game/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// [maskable]: fondo a sangre y personaje más pequeño (el sistema recorta con su propia forma).
Widget _icon({required bool maskable}) {
  final character = maskable ? 0.56 : 0.70; // proporción del ancho que ocupa el personaje
  return LayoutBuilder(
    builder: (context, c) {
      final s = c.maxWidth;
      return Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(maskable ? 0 : s * 0.22),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF9A86), Color(0xFFFFE0A3), Color(0xFF4AA8E8), Color(0xFF3A93D6)],
            stops: [0, 0.45, 0.62, 1],
          ),
        ),
        child: Stack(children: [
          // Un coco cayendo, como guiño al juego.
          Positioned(
            left: s * 0.70,
            top: s * 0.12,
            child: Container(
              width: s * 0.12,
              height: s * 0.12,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFB0793F), Color(0xFF4A2A12)])),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.22),
            child: CustomPaint(size: Size(s * character, s * character * 1.12), painter: Character.mochi.painter(happy: 0.5)),
          ),
        ]),
      );
    },
  );
}

Future<void> _write(WidgetTester tester, String path, int px, {required bool maskable}) async {
  final key = GlobalKey();
  tester.view.physicalSize = const Size(1024, 1024);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: RepaintBoundary(key: key, child: SizedBox(width: 1024, height: 1024, child: _icon(maskable: maskable)))),
  ));
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: px / 1024);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    // ICON_OUT: carpeta de salida alternativa (algunos antivirus bloquean que el proceso de
    // pruebas escriba dentro de Escritorio/OneDrive; entonces se genera fuera y se copia).
    final out = Platform.environment['ICON_OUT'];
    File(out == null ? path : '$out/$path')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('genera los íconos', (tester) async {
    addTearDown(tester.view.reset);
    const web = [('web/favicon.png', 64, false), ('web/icons/Icon-192.png', 192, false), ('web/icons/Icon-512.png', 512, false), ('web/icons/Icon-maskable-192.png', 192, true), ('web/icons/Icon-maskable-512.png', 512, true)];
    for (final (path, px, mask) in web) {
      await _write(tester, path, px, maskable: mask);
    }
    const android = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    for (final e in android.entries) {
      await _write(tester, 'android/app/src/main/res/mipmap-${e.key}/ic_launcher.png', e.value, maskable: false);
    }
  });
}
