import 'dart:math';

import 'package:flutter/material.dart';

import '../core/color_ext.dart';
import 'painter_utils.dart';

/// Mochi: un bollito de arroz redondo y blandito, con una hojita en la cabeza.
/// Personaje original. Caja de 100x112; misma animación que los demás.
class MochiPainter extends CustomPainter {
  const MochiPainter({this.facing = 1, this.walk = 0, this.energy = 0, this.happy = 0});

  final double facing;
  final double walk;
  final double energy;
  final double happy;

  static const _dough = Color(0xFFFFF3DD);
  static const _doughShade = Color(0xFFF0D9B5);
  static const _pink = Color(0xFFFF9DB5);
  static const _leaf = Color(0xFF58B368);
  static const _ink = Color(0xFF3B2A25);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 112);

    final bob = -sin(walk * 2).abs() * 3 * energy + sin(walk * 0.6) * 0.8 * (1 - energy);
    final step = sin(walk * 2) * energy;
    final look = facing * 2.0;
    // Se aplasta y se estira al andar (blandito).
    final squash = 1 + sin(walk * 2).abs() * 0.05 * energy - 0.02 * sin(walk * 0.6);

    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 109), width: 72 + bob * 2, height: 8), Paint()..color = Colors.black.o(0.22));

    canvas.translate(0, bob);

    // Piecitos rosas.
    for (final side in [-1, 1]) {
      final lift = max(0.0, step * side) * 4;
      drawOvalShape(canvas, Rect.fromCenter(center: Offset(50 + side * 17, 102 - lift), width: 22, height: 12), _pink, ink: _ink);
    }

    // Brazos redondos (detrás del cuerpo al bajar).
    for (final side in [-1, 1]) {
      final angle = -side * (0.2 + 2.2 * happy) + sin(walk * 2 + (side > 0 ? pi : 0)) * 0.5 * energy;
      canvas.save();
      canvas.translate(50 + side * 36.0, 70);
      canvas.rotate(angle);
      drawOvalShape(canvas, Rect.fromCenter(center: const Offset(0, 7), width: 14, height: 18), _dough, ink: _ink, width: 2);
      canvas.restore();
    }

    // Cuerpo: una gran gota redonda.
    canvas.save();
    canvas.translate(50, 100);
    canvas.scale(1 / squash, squash);
    canvas.translate(-50, -100);
    final body = Path()
      ..moveTo(50, 22)
      ..cubicTo(84, 22, 94, 52, 92, 74)
      ..cubicTo(90, 96, 74, 102, 50, 102)
      ..cubicTo(26, 102, 10, 96, 8, 74)
      ..cubicTo(6, 52, 16, 22, 50, 22)
      ..close();
    drawShape(canvas, body, _dough, ink: _ink, width: 2.4);
    // Sombra suave abajo.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 104), width: 90, height: 22), Paint()..color = _doughShade);
    canvas.restore();
    canvas.drawPath(body, strokePaint(_ink, 2.4));
    canvas.restore();

    // Hojita.
    final leaf = Path()
      ..moveTo(50, 24)
      ..cubicTo(44, 12, 54, 4, 66, 8)
      ..cubicTo(66, 18, 58, 24, 50, 24)
      ..close();
    drawShape(canvas, leaf, _leaf, ink: _ink, width: 2);
    canvas.drawLine(const Offset(52, 21), const Offset(62, 11), strokePaint(_ink.o(0.5), 1.2));

    // Cara.
    final blinking = (walk % 7) < 0.14;
    for (final side in [-1, 1]) {
      final c = Offset(50 + side * 17 + look, 62);
      canvas.drawOval(Rect.fromCenter(center: c.translate(side * 5.0, 8), width: 11, height: 7), Paint()..color = _pink.o(0.75));
      if (blinking || happy > 0.4) {
        // Ojitos felices ^ ^ (o parpadeo).
        canvas.drawArc(Rect.fromCenter(center: c.translate(0, 1), width: 10, height: 9), pi * 1.1, pi * 0.8, false, strokePaint(_ink, 2.4));
      } else {
        canvas.drawOval(Rect.fromCenter(center: c, width: 9, height: 12), Paint()..color = _ink);
        canvas.drawCircle(c.translate(-1.6, -3), 2.1, Paint()..color = Colors.white);
        canvas.drawCircle(c.translate(1.6, 2.4), 0.9, Paint()..color = Colors.white.o(0.8));
      }
    }

    final cx = 50 + look * 0.8;
    if (happy > 0.05) {
      final open = 3 + 7 * happy;
      final mouth = Path()
        ..moveTo(cx - 6, 69)
        ..quadraticBezierTo(cx, 69 + open * 1.6, cx + 6, 69)
        ..close();
      canvas.drawPath(mouth, Paint()..color = const Color(0xFF8A2F3F));
      canvas.save();
      canvas.clipPath(mouth);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, 69 + open), width: 8, height: 5), Paint()..color = _pink);
      canvas.restore();
      canvas.drawPath(mouth, strokePaint(_ink, 1.6));
    } else {
      // Boquita en "w".
      canvas.drawPath(
        Path()
          ..moveTo(cx - 6, 68)
          ..quadraticBezierTo(cx - 3, 73, cx, 68)
          ..quadraticBezierTo(cx + 3, 73, cx + 6, 68),
        strokePaint(_ink, 1.8),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MochiPainter old) =>
      old.facing != facing || old.walk != walk || old.energy != energy || old.happy != happy;
}
