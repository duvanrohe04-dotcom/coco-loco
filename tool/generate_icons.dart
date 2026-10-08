// Genera los íconos del juego (web y Android): un cacho dorado sobre el degradado del atardecer.
// Se ejecuta con:   flutter test tool/generate_icons.dart
// Reescribe web/favicon.png, web/icons/*.png y los android/.../mipmap-*/ic_launcher.png.
// Con la variable ICON_OUT=<carpeta> escribe ahí (misma estructura de carpetas) en vez de en el proyecto
// (algunos antivirus bloquean que el proceso de pruebas escriba dentro de Escritorio/OneDrive).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coco_loco/game/item_painters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _HornArt extends CustomPainter {
  const _HornArt({required this.scale});
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    paintHorn(canvas, size.center(Offset.zero), size.width * scale, -0.25, golden: true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// [maskable]: fondo a sangre y cacho más pequeño (el sistema recorta con su propia forma).
Widget _icon({required bool maskable}) => LayoutBuilder(
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
          child: CustomPaint(size: Size(s, s), painter: _HornArt(scale: maskable ? 0.30 : 0.38)),
        );
      },
    );

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
