import 'dart:math';

import 'package:flutter/material.dart';

import '../core/color_ext.dart';
import 'painter_utils.dart';

/// Tuerca: un robotito con visor luminoso y antena.
/// Personaje original. Caja de 100x112; misma animación que los demás.
class RobotPainter extends CustomPainter {
  const RobotPainter({this.facing = 1, this.walk = 0, this.energy = 0, this.happy = 0});

  final double facing;
  final double walk;
  final double energy;
  final double happy;

  static const _metal = Color(0xFFB9C7D8);
  static const _metalDark = Color(0xFF7F93AB);
  static const _visor = Color(0xFF1E2B45);
  static const _glow = Color(0xFF4DF0FF);
  static const _accent = Color(0xFFFF6B4A);
  static const _ink = Color(0xFF16202F);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 112);

    final bob = -sin(walk * 2).abs() * 3 * energy + sin(walk * 0.6) * 0.8 * (1 - energy);
    final step = sin(walk * 2) * energy;
    final look = facing * 2.0;

    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 109), width: 70 + bob * 2, height: 8), Paint()..color = Colors.black.o(0.22));

    canvas.translate(0, bob);

    // Piernas y pies.
    for (final side in [-1, 1]) {
      final lift = max(0.0, step * side) * 4;
      drawRRectShape(canvas, Rect.fromCenter(center: Offset(50 + side * 12, 92 - lift * 0.5), width: 10, height: 14), 3, _metalDark, ink: _ink, width: 2);
      drawRRectShape(canvas, Rect.fromCenter(center: Offset(50 + side * 13, 102 - lift), width: 24, height: 11), 5, _accent, ink: _ink, width: 2);
    }

    // Brazos articulados con pinza redonda.
    for (final side in [-1, 1]) {
      final angle = -side * (0.3 + 2.2 * happy) + sin(walk * 2 + (side > 0 ? pi : 0)) * 0.5 * energy;
      canvas.save();
      canvas.translate(50 + side * 27.0, 72);
      canvas.rotate(angle);
      drawRRectShape(canvas, Rect.fromCenter(center: const Offset(0, 9), width: 8, height: 20), 4, _metalDark, ink: _ink, width: 2);
      drawOvalShape(canvas, Rect.fromCenter(center: const Offset(0, 21), width: 12, height: 12), _accent, ink: _ink, width: 2);
      canvas.restore();
    }

    // Torso con panel luminoso.
    drawRRectShape(canvas, Rect.fromCenter(center: const Offset(50, 80), width: 46, height: 34), 10, _metal, ink: _ink);
    drawRRectShape(canvas, Rect.fromCenter(center: const Offset(50, 81), width: 26, height: 16), 5, _visor, ink: _ink, width: 1.8);
    final pulse = 0.55 + 0.45 * sin(walk * 3);
    canvas.drawCircle(const Offset(44, 81), 2.6, Paint()..color = _glow.o(0.5 + 0.5 * pulse));
    canvas.drawCircle(const Offset(50, 81), 2.6, Paint()..color = _accent.o(0.5 + 0.5 * (1 - pulse)));
    canvas.drawCircle(const Offset(56, 81), 2.6, Paint()..color = const Color(0xFFFFE066).o(0.55 + 0.4 * pulse));
    // Tornillos.
    for (final p in const [Offset(34, 70), Offset(66, 70), Offset(34, 90), Offset(66, 90)]) {
      canvas.drawCircle(p, 1.5, Paint()..color = _metalDark);
    }

    // Antena.
    final wobble = sin(walk * 2) * 2 * energy + sin(walk * 1.3) * 1;
    canvas.drawLine(const Offset(50, 22), Offset(50 + wobble, 11), strokePaint(_ink, 2.4));
    canvas.drawCircle(Offset(50 + wobble, 9), 4.4, Paint()..color = _accent);
    canvas.drawCircle(Offset(50 + wobble, 9), 4.4, strokePaint(_ink, 2));
    canvas.drawCircle(Offset(49 + wobble, 7.6), 1.3, Paint()..color = Colors.white.o(0.8));

    // Orejeras (pernos laterales).
    for (final side in [-1, 1]) {
      drawRRectShape(canvas, Rect.fromCenter(center: Offset(50 + side * 34.0, 44), width: 9, height: 18), 4, _metalDark, ink: _ink, width: 2);
    }

    // Cabeza cuadradita.
    drawRRectShape(canvas, Rect.fromCenter(center: const Offset(50, 43), width: 62, height: 44), 14, _metal, ink: _ink);
    canvas.drawArc(const Rect.fromLTWH(26, 26, 30, 12), pi * 1.05, pi * 0.5, false, strokePaint(Colors.white.o(0.55), 2));

    // Visor y ojos luminosos.
    final visor = Rect.fromCenter(center: Offset(50 + look * 0.5, 44), width: 50, height: 28);
    drawRRectShape(canvas, visor, 10, _visor, ink: _ink, width: 2);
    final blinking = (walk % 7) < 0.14;
    for (final side in [-1, 1]) {
      final c = Offset(50 + side * 11 + look, 43);
      if (blinking) {
        canvas.drawLine(c.translate(-5, 0), c.translate(5, 0), strokePaint(_glow, 2.6));
      } else if (happy > 0.4) {
        // Ojos felices en arco.
        canvas.drawArc(Rect.fromCenter(center: c.translate(0, 2), width: 12, height: 10), pi * 1.05, pi * 0.9, false, strokePaint(_glow, 3));
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 10, height: 13), const Radius.circular(4)), Paint()..color = _glow.o(0.3));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 7, height: 10), const Radius.circular(3)), Paint()..color = _glow);
        canvas.drawCircle(c.translate(-1, -2.4), 1.2, Paint()..color = Colors.white);
      }
    }
    // Sonrisa digital.
    final cx = 50 + look * 0.5;
    if (happy > 0.05) {
      canvas.drawPath(
        Path()
          ..moveTo(cx - 7, 52)
          ..quadraticBezierTo(cx, 52 + 6 + 4 * happy, cx + 7, 52)
          ..close(),
        Paint()..color = _glow,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(cx - 6, 51.5)
          ..quadraticBezierTo(cx, 56, cx + 6, 51.5),
        strokePaint(_glow, 2),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RobotPainter old) =>
      old.facing != facing || old.walk != walk || old.energy != energy || old.happy != happy;
}
