import 'dart:math';

import 'package:flutter/material.dart';

import '../core/color_ext.dart';
import 'game_engine.dart';
import 'level.dart';

/// Fondo animado: cielo, sol/luna, nubes, mar con olas, arena y palmeras.
void paintBackground(Canvas canvas, Size size, LevelTheme theme, double t) {
  final sandTop = size.height - GameEngine.groundHeight;
  final seaTop = sandTop - size.height * 0.16;

  // Cielo.
  final skyRect = Rect.fromLTWH(0, 0, size.width, seaTop + 1);
  canvas.drawRect(
    skyRect,
    Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [theme.skyTop, theme.skyBottom]).createShader(skyRect),
  );

  if (theme.night) paintStars(canvas, size, seaTop, t);
  paintSun(canvas, size, seaTop, theme, t);
  paintClouds(canvas, size, seaTop, theme, t);
  _sea(canvas, size, seaTop, sandTop, theme, t);
  _sand(canvas, size, sandTop, theme);

  final palmH = min(size.height * 0.55, 300.0);
  paintPalm(canvas, Offset(size.width * 0.07, sandTop + 14), palmH, 36, t, theme, 0);
  paintPalm(canvas, Offset(size.width * 0.93, sandTop + 14), palmH * 0.85, -30, t, theme, 2);
}

void paintStars(Canvas canvas, Size size, double seaTop, double t) {
  final rnd = Random(7);
  for (var i = 0; i < 70; i++) {
    final p = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * seaTop * 0.9);
    final twinkle = 0.5 + 0.5 * sin(t * 2 + i);
    canvas.drawCircle(p, 0.8 + rnd.nextDouble() * 1.2, Paint()..color = Colors.white.o(0.35 + 0.6 * twinkle));
  }
}

void paintSun(Canvas canvas, Size size, double seaTop, LevelTheme theme, double t) {
  final c = Offset(size.width * 0.74, seaTop * theme.sunHeight);
  final glowR = theme.night ? 90.0 : 120.0;
  canvas.drawCircle(
    c,
    glowR,
    Paint()..shader = RadialGradient(colors: [theme.sun.o(theme.night ? 0.35 : 0.6), theme.sun.o(0)]).createShader(Rect.fromCircle(center: c, radius: glowR)),
  );
  canvas.drawCircle(c, theme.night ? 28 : 36, Paint()..color = theme.sun);
  if (theme.night) {
    final crater = Paint()..color = const Color(0xFFD9D5BD);
    canvas.drawCircle(c.translate(-8, -5), 5, crater);
    canvas.drawCircle(c.translate(9, 8), 4, crater);
    canvas.drawCircle(c.translate(4, -12), 3, crater);
  }
}

void paintClouds(Canvas canvas, Size size, double seaTop, LevelTheme theme, double t) {
  final paint = Paint()..color = (theme.night ? const Color(0xFF8FA6D6) : Colors.white).o(theme.night ? 0.25 : 0.8);
  for (var i = 0; i < 4; i++) {
    final span = size.width + 260;
    final x = (i * span / 4 + t * (7 + i * 3)) % span - 130;
    final y = seaTop * (0.12 + 0.17 * i);
    final s = 0.8 + 0.25 * (i % 3);
    for (final o in const [Offset(0, 0), Offset(26, -9), Offset(52, 0), Offset(26, 6)]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(x + o.dx * s, y + o.dy * s), width: 56 * s, height: 28 * s), paint);
    }
  }
}

void _sea(Canvas canvas, Size size, double seaTop, double sandTop, LevelTheme theme, double t) {
  final rect = Rect.fromLTRB(0, seaTop, size.width, sandTop + 4);
  canvas.drawRect(
    rect,
    Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [theme.sea, theme.seaDeep]).createShader(rect),
  );
  final h = sandTop - seaTop;
  final line = Paint()
    ..color = Colors.white.o(theme.night ? 0.12 : 0.28)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  for (var row = 1; row <= 4; row++) {
    final y = seaTop + h * row / 5;
    final path = Path()..moveTo(0, y);
    for (double x = 0; x <= size.width; x += 10) {
      path.lineTo(x, y + sin(x / 38 + t * 1.6 + row * 1.7) * (2 + row * 0.6));
    }
    canvas.drawPath(path, line);
  }
}

void _sand(Canvas canvas, Size size, double sandTop, LevelTheme theme) {
  final rect = Rect.fromLTRB(0, sandTop - 8, size.width, size.height);
  final path = Path()..moveTo(0, size.height)..lineTo(0, sandTop);
  for (double x = 0; x <= size.width; x += 12) {
    path.lineTo(x, sandTop + sin(x / 70) * 4);
  }
  path
    ..lineTo(size.width, size.height)
    ..close();
  canvas.drawPath(
    path,
    Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [theme.sand, theme.sandDark]).createShader(rect),
  );
  // Espuma en la orilla.
  canvas.drawPath(
    Path()
      ..moveTo(0, sandTop - 1)
      ..lineTo(size.width, sandTop - 1),
    Paint()
      ..color = Colors.white.o(0.55)
      ..strokeWidth = 3,
  );
}

void paintPalm(Canvas canvas, Offset base, double height, double lean, double t, LevelTheme theme, double seed) {
  final shade = theme.night ? 0.5 : 0.0;
  Color tone(Color c) => Color.lerp(c, Colors.black, shade)!;

  final top = base + Offset(lean, -height);
  final ctrl = Offset(base.dx + lean * 0.15, base.dy - height * 0.55);

  // Tronco.
  final trunk = Path()
    ..moveTo(base.dx - 10, base.dy)
    ..quadraticBezierTo(ctrl.dx - 7, ctrl.dy, top.dx - 5, top.dy)
    ..lineTo(top.dx + 5, top.dy)
    ..quadraticBezierTo(ctrl.dx + 7, ctrl.dy, base.dx + 10, base.dy)
    ..close();
  canvas.drawPath(
    trunk,
    Paint()
      ..shader = LinearGradient(colors: [tone(const Color(0xFF8A5A33)), tone(const Color(0xFF5A3820))])
          .createShader(trunk.getBounds()),
  );
  final ring = Paint()
    ..color = tone(const Color(0xFF3E2512)).o(0.5)
    ..strokeWidth = 2;
  for (var i = 1; i < 9; i++) {
    final u = i / 9;
    final p = Offset(
      pow(1 - u, 2) * base.dx + 2 * u * (1 - u) * ctrl.dx + u * u * top.dx,
      pow(1 - u, 2) * base.dy + 2 * u * (1 - u) * ctrl.dy + u * u * top.dy,
    );
    final w = 9 - 4 * u;
    canvas.drawLine(p.translate(-w, 0), p.translate(w, 2), ring);
  }

  // Hojas.
  final len = min(130.0, height * 0.5);
  for (var k = 0; k < 7; k++) {
    final a = -pi + pi * k / 6 + sin(t * 1.3 + seed + k) * 0.04;
    final tip = top + Offset(cos(a), sin(a) * 0.55 + 0.35) * len;
    final mid = Offset.lerp(top, tip, 0.5)!;
    final leaf = Path()
      ..moveTo(top.dx, top.dy)
      ..quadraticBezierTo(mid.dx, mid.dy - len * 0.28, tip.dx, tip.dy)
      ..quadraticBezierTo(mid.dx, mid.dy + len * 0.06, top.dx, top.dy)
      ..close();
    canvas.drawPath(leaf, Paint()..color = tone(k.isEven ? const Color(0xFF2E9B4F) : const Color(0xFF1F7A3C)));
    canvas.drawLine(top, tip, Paint()..color = tone(const Color(0xFF15592B)).o(0.6)..strokeWidth = 1.2);
  }

  // Racimo de cocos.
  final coco = Paint()..color = tone(const Color(0xFF5A3A1E));
  for (final o in const [Offset(-6, 7), Offset(6, 8), Offset(0, 12)]) {
    canvas.drawCircle(top + o, 7, coco);
  }
}
