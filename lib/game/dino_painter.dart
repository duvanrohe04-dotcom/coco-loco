import 'dart:math';

import 'package:flutter/material.dart';

import '../core/color_ext.dart';
import 'painter_utils.dart';

/// Dino: un dinosaurio verde y simpático con crestas naranjas.
/// Personaje original. Caja de 100x112; misma animación que los demás.
class DinoPainter extends CustomPainter {
  const DinoPainter({this.facing = 1, this.walk = 0, this.energy = 0, this.happy = 0});

  final double facing;
  final double walk;
  final double energy;
  final double happy;

  static const _green = Color(0xFF5CBF6A);
  static const _greenDark = Color(0xFF3E9A52);
  static const _belly = Color(0xFFD6F2B0);
  static const _crest = Color(0xFFFF9A3C);
  static const _ink = Color(0xFF123524);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 112);

    final bob = -sin(walk * 2).abs() * 3 * energy + sin(walk * 0.6) * 0.8 * (1 - energy);
    final step = sin(walk * 2) * energy;
    final look = facing * 1.8;

    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 109), width: 74 + bob * 2, height: 8), Paint()..color = Colors.black.o(0.22));

    canvas.translate(0, bob);

    // Cola (sale por el lado contrario a donde mira) con balanceo.
    final tailSway = sin(walk * 2) * 3 * energy + sin(walk * 0.9) * 1.5;
    canvas.save();
    canvas.translate(50, 0);
    canvas.scale(-facing, 1);
    canvas.translate(-50, 0);
    final tail = Path()
      ..moveTo(70, 88)
      ..cubicTo(86, 90 + tailSway, 96, 84 + tailSway, 97, 72 + tailSway)
      ..cubicTo(90, 80 + tailSway, 84, 80, 74, 78)
      ..close();
    drawShape(canvas, tail, _green, ink: _ink, width: 2.2);
    canvas.restore();

    // Patas con garritas.
    for (final side in [-1, 1]) {
      final lift = max(0.0, step * side) * 4;
      final r = Rect.fromCenter(center: Offset(50 + side * 15, 101 - lift), width: 25, height: 14);
      drawOvalShape(canvas, r, _green, ink: _ink);
      for (var c = -1; c <= 1; c++) {
        canvas.drawLine(Offset(r.center.dx + c * 6.5, r.bottom - 3), Offset(r.center.dx + c * 6.5, r.bottom - 0.5), strokePaint(_ink, 1.6));
      }
    }

    // Cuerpo y panza.
    final body = Rect.fromCenter(center: const Offset(50, 80), width: 54, height: 46);
    drawOvalShape(canvas, body, _green, ink: _ink);
    final belly = Rect.fromCenter(center: const Offset(50, 85), width: 34, height: 32);
    canvas.drawOval(belly, Paint()..color = _belly);
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(Offset(40, 76 + i * 7.0), Offset(60, 76 + i * 7.0), strokePaint(_greenDark.o(0.35), 1.2));
    }

    // Bracitos cortos.
    for (final side in [-1, 1]) {
      final angle = -side * (0.35 + 2.2 * happy) + sin(walk * 2 + (side > 0 ? pi : 0)) * 0.5 * energy;
      canvas.save();
      canvas.translate(50 + side * 26.0, 74);
      canvas.rotate(angle);
      drawOvalShape(canvas, Rect.fromCenter(center: const Offset(0, 6), width: 11, height: 17), _green, ink: _ink, width: 2);
      canvas.restore();
    }

    // Crestas naranjas sobre la cabeza.
    for (var i = -1; i <= 1; i++) {
      final x = 50 + i * 14.0;
      final h = i == 0 ? 16.0 : 12.0;
      final p = Path()
        ..moveTo(x - 6, 22 + (i == 0 ? 0 : 3))
        ..lineTo(x, 22 + (i == 0 ? 0 : 3) - h)
        ..lineTo(x + 6, 22 + (i == 0 ? 0 : 3))
        ..close();
      drawShape(canvas, p, _crest, ink: _ink, width: 2);
    }

    // Cabeza grande.
    final head = Rect.fromCenter(center: const Offset(50, 44), width: 70, height: 54);
    drawOvalShape(canvas, head, _green, ink: _ink);
    // Mejillas.
    for (final side in [-1, 1]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(50 + side * 26.0 + look * 0.4, 56), width: 11, height: 7), Paint()..color = const Color(0xFFFF8FA3).o(0.7));
    }

    // Ojos.
    final blinking = (walk % 7) < 0.14;
    for (final side in [-1, 1]) {
      final c = Offset(50 + side * 15 + look, 38);
      if (blinking) {
        canvas.drawLine(c.translate(-6, 0), c.translate(6, 0), strokePaint(_ink, 2.2));
        continue;
      }
      canvas.drawOval(Rect.fromCenter(center: c, width: 17, height: 19), Paint()..color = Colors.white);
      canvas.drawOval(Rect.fromCenter(center: c, width: 17, height: 19), strokePaint(_ink, 1.8));
      canvas.drawCircle(c.translate(look * 0.6, 1.5), 4.4, Paint()..color = _ink);
      canvas.drawCircle(c.translate(look * 0.6 - 1.3, -0.3), 1.5, Paint()..color = Colors.white);
    }

    // Fosas nasales y sonrisa grande con dientitos.
    final cx = 50 + look * 0.6;
    canvas.drawCircle(Offset(cx - 4, 49), 1.3, Paint()..color = _ink);
    canvas.drawCircle(Offset(cx + 4, 49), 1.3, Paint()..color = _ink);
    if (happy > 0.05) {
      final open = 4 + 8 * happy;
      final mouth = Path()
        ..moveTo(cx - 14, 55)
        ..quadraticBezierTo(cx, 55 + open * 1.6, cx + 14, 55)
        ..close();
      canvas.drawPath(mouth, Paint()..color = const Color(0xFF7A1F2F));
      canvas.save();
      canvas.clipPath(mouth);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, 55 + open), width: 12, height: 7), Paint()..color = const Color(0xFFFF7F96));
      canvas.restore();
      canvas.drawPath(mouth, strokePaint(_ink, 1.8));
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(cx - 13, 54)
          ..quadraticBezierTo(cx, 63, cx + 13, 54),
        strokePaint(_ink, 2.1),
      );
      for (final dx in [-7.0, 7.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(cx + dx - 2, 58.3)
            ..lineTo(cx + dx, 61.5)
            ..lineTo(cx + dx + 2, 58.3)
            ..close(),
          Paint()..color = Colors.white,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DinoPainter old) =>
      old.facing != facing || old.walk != walk || old.energy != energy || old.happy != happy;
}
