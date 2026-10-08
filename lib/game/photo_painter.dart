import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/color_ext.dart';
import 'painter_utils.dart';

/// Fotos de los personajes ya recortadas a la cara (assets/characters/*.png).
/// Se cargan una sola vez al arrancar la app (ver main.dart).
class CharacterPhotos {
  CharacterPhotos._();

  static const ids = ['p1', 'p2', 'p3'];
  static final Map<String, ui.Image> _images = {};

  static Future<void> load() async {
    for (final id in ids) {
      if (_images.containsKey(id)) continue;
      try {
        final data = await rootBundle.load('assets/characters/$id.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 256);
        _images[id] = (await codec.getNextFrame()).image;
      } catch (_) {
        // Sin la foto se dibuja un círculo de color: el juego sigue funcionando.
      }
    }
  }

  static ui.Image? imageFor(String id) => _images[id];
}

/// Jugador con la cara de una foto: cabeza redonda con la foto sobre un cuerpecito animado.
/// Misma caja de 100x112 y mismos parámetros de animación que el resto de personajes.
class PhotoPainter extends CustomPainter {
  const PhotoPainter({
    required this.photo,
    required this.shirt,
    required this.accent,
    this.facing = 1,
    this.walk = 0,
    this.energy = 0,
    this.happy = 0,
  });

  /// Identificador de la foto en [CharacterPhotos].
  final String photo;
  final Color shirt;
  final Color accent;
  final double facing;
  final double walk;
  final double energy;
  final double happy;

  static const _skin = Color(0xFFE8B98F);
  static const _ink = Color(0xFF14181F);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 112);

    final bob = -sin(walk * 2).abs() * 3 * energy + sin(walk * 0.6) * 0.8 * (1 - energy);
    final step = sin(walk * 2) * energy;

    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 109), width: 70 + bob * 2, height: 8), Paint()..color = Colors.black.o(0.22));

    canvas.translate(0, bob);

    // Zapatillas.
    for (final side in [-1, 1]) {
      final lift = max(0.0, step * side) * 4;
      drawOvalShape(canvas, Rect.fromCenter(center: Offset(50 + side * 13, 102 - lift), width: 22, height: 11), Colors.white, ink: _ink, width: 2);
    }

    // Piernas.
    for (final side in [-1, 1]) {
      final lift = max(0.0, step * side) * 4;
      drawRRectShape(canvas, Rect.fromCenter(center: Offset(50 + side * 11, 93 - lift * 0.5), width: 14, height: 16), 5, const Color(0xFF2B3A55), ink: _ink, width: 2);
    }

    // Brazos (detrás del torso al bajar).
    for (final side in [-1, 1]) {
      final angle = -side * (0.25 + 2.3 * happy) + sin(walk * 2 + (side > 0 ? pi : 0)) * 0.5 * energy;
      canvas.save();
      canvas.translate(50 + side * 22.0, 72);
      canvas.rotate(angle);
      drawOvalShape(canvas, Rect.fromCenter(center: const Offset(0, 17), width: 8, height: 8), _skin, ink: _ink, width: 1.8);
      drawOvalShape(canvas, Rect.fromCenter(center: const Offset(0, 8), width: 11, height: 20), shirt, ink: _ink, width: 2);
      canvas.restore();
    }

    // Torso con una franja del color de la prenda.
    drawRRectShape(canvas, Rect.fromCenter(center: const Offset(50, 80), width: 36, height: 30), 12, shirt, ink: _ink);
    canvas.drawRect(Rect.fromCenter(center: const Offset(50, 80), width: 5, height: 24), Paint()..color = accent);

    // Cabeza: la foto recortada en círculo, con borde. Se inclina hacia donde mira y "salta" al atrapar.
    final pulse = 1 + 0.10 * happy;
    canvas.save();
    canvas.translate(50, 43);
    canvas.rotate(facing * 0.10 * (0.4 + energy) + sin(walk * 2) * 0.05 * energy);
    canvas.scale(pulse, pulse);
    const r = 32.0;
    final head = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawCircle(const Offset(0, 2), r + 1, Paint()..color = Colors.black.o(0.25));
    final img = CharacterPhotos.imageFor(photo);
    if (img != null) {
      canvas.save();
      canvas.clipPath(Path()..addOval(head));
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        head,
        Paint()..filterQuality = FilterQuality.medium..isAntiAlias = true,
      );
      canvas.restore();
    } else {
      canvas.drawCircle(Offset.zero, r, Paint()..color = _skin);
    }
    canvas.drawCircle(Offset.zero, r, strokePaint(_ink, 3));
    canvas.drawCircle(Offset.zero, r - 2, strokePaint(Colors.white.o(0.85), 1.4));
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PhotoPainter old) =>
      old.photo != photo || old.facing != facing || old.walk != walk || old.energy != energy || old.happy != happy;
}
