import 'dart:math';

import 'package:flutter/material.dart';

import '../core/color_ext.dart';
import 'level.dart';

/// Dibuja a un jefe (en el horizonte, por detrás de lo que cae). [base] es el punto de sus "pies".
/// [hit] (0..1) lo sacude al recibir un golpe y [attack] (0..1) le abre la boca al lanzar una pared.
void paintBoss(Canvas canvas, Offset base, double width, BossSpec spec, double t, double hit, double attack) {
  final k = width / 200;
  final shake = hit > 0 ? sin(t * 70) * 5 * hit : 0.0;
  canvas.save();
  canvas.translate(base.dx + shake, base.dy + sin(t * 2) * 3);
  canvas.scale(k, k);

  const ink = Color(0xFF1A1020);
  final dark = Color.lerp(spec.body, Colors.black, 0.35)!;
  final light = Color.lerp(spec.body, Colors.white, 0.35)!;

  Paint stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  // Pinchos de lava/roca detrás del cuerpo.
  if (spec.spikes) {
    for (var i = -3; i <= 3; i++) {
      final x = i * 24.0;
      final h = 34.0 + (i.isEven ? 14 : 0);
      final p = Path()
        ..moveTo(x - 13, -100 + (x.abs() / 5))
        ..lineTo(x, -100 - h + (x.abs() / 5))
        ..lineTo(x + 13, -100 + (x.abs() / 5))
        ..close();
      canvas.drawPath(p, Paint()..color = spec.accent);
      canvas.drawPath(p, stroke(ink, 3));
    }
  }

  // Brazos: pinzas (2) o tentáculos (4 o más).
  if (spec.arms <= 2) {
    for (final side in const [-1.0, 1.0]) {
      final lift = attack * 38;
      final shoulder = Offset(side * 70, -62);
      final hand = Offset(side * (112 + attack * 8), -92 - lift);
      canvas.drawLine(shoulder, hand, stroke(ink, 22));
      canvas.drawLine(shoulder, hand, stroke(spec.body, 16));
      // Pinza: círculo con una "boca".
      canvas.drawCircle(hand, 25, Paint()..color = spec.body);
      canvas.drawCircle(hand, 25, stroke(ink, 4));
      final mouth = Path()
        ..moveTo(hand.dx, hand.dy)
        ..lineTo(hand.dx + side * 28, hand.dy - 18 - attack * 12)
        ..lineTo(hand.dx + side * 28, hand.dy + 6)
        ..close();
      canvas.drawPath(mouth, Paint()..color = const Color(0xFF2A1830));
    }
  } else {
    for (var i = 0; i < spec.arms; i++) {
      final f = (i + 0.5) / spec.arms; // 0..1 repartidos de izquierda a derecha
      final x0 = (f - 0.5) * 130;
      final sway = sin(t * 2.4 + i * 1.3) * 14 + attack * 10 * (i.isEven ? 1 : -1);
      final path = Path()
        ..moveTo(x0, -40)
        ..cubicTo(x0 * 1.3 + sway, -20, x0 * 1.7 - sway, 0, x0 * 2.0 + sway * 0.6, 4);
      canvas.drawPath(path, stroke(ink, 20));
      canvas.drawPath(path, stroke(dark, 14));
      canvas.drawCircle(Offset(x0 * 2.0 + sway * 0.6, 4), 7, Paint()..color = spec.accent);
    }
  }

  // Cuerpo.
  final bodyRect = Rect.fromCenter(center: const Offset(0, -68), width: 176, height: 124);
  canvas.drawOval(
    bodyRect,
    Paint()..shader = RadialGradient(center: const Alignment(-0.3, -0.6), colors: [light, spec.body, dark], stops: const [0, 0.5, 1]).createShader(bodyRect),
  );
  canvas.drawOval(bodyRect, stroke(ink, 4));
  // Manchas y vientre.
  canvas.drawOval(Rect.fromCenter(center: const Offset(0, -44), width: 100, height: 50), Paint()..color = spec.accent.o(0.35));
  for (final p in const [Offset(-52, -74), Offset(54, -66), Offset(-28, -36), Offset(30, -34)]) {
    canvas.drawCircle(p, 6, Paint()..color = spec.accent.o(0.55));
  }

  // Ojos que miran al jugador, con cejas enfadadas.
  for (final side in const [-1.0, 1.0]) {
    final eye = Offset(side * 30, -96);
    canvas.drawCircle(eye, 19, Paint()..color = Colors.white);
    canvas.drawCircle(eye, 19, stroke(ink, 3));
    canvas.drawCircle(eye.translate(0, 5 + attack * 2), 9, Paint()..color = ink);
    canvas.drawCircle(eye.translate(-3, 1), 3, Paint()..color = Colors.white);
    canvas.drawLine(eye.translate(side * -16, -22), eye.translate(side * 14, -14 - attack * 6), stroke(ink, 5));
  }

  // Boca: sonrisa; se abre al atacar.
  final open = 6 + attack * 22;
  final mouth = Path()
    ..moveTo(-26, -50)
    ..quadraticBezierTo(0, -50 + open, 26, -50)
    ..quadraticBezierTo(0, -54, -26, -50)
    ..close();
  canvas.drawPath(mouth, Paint()..color = const Color(0xFF2A1830));
  canvas.drawPath(mouth, stroke(ink, 3));
  if (attack > 0.15) canvas.drawOval(Rect.fromCenter(center: Offset(0, -50 + open * 0.62), width: 22, height: 9 + attack * 5), Paint()..color = const Color(0xFFFF7F9A));

  // Corona del Rey.
  if (spec.crown) {
    final crown = Path()
      ..moveTo(-42, -126)
      ..lineTo(-42, -154)
      ..lineTo(-20, -136)
      ..lineTo(0, -160)
      ..lineTo(20, -136)
      ..lineTo(42, -154)
      ..lineTo(42, -126)
      ..close();
    canvas.drawPath(crown, Paint()..color = const Color(0xFFFFD84D));
    canvas.drawPath(crown, stroke(ink, 4));
    for (final x in const [-42.0, 0.0, 42.0]) {
      canvas.drawCircle(Offset(x, x == 0 ? -160 : -154), 5, Paint()..color = const Color(0xFFE5254F));
    }
  }

  canvas.restore();
}
