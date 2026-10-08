import 'dart:math';

import 'package:flutter/material.dart';

import '../core/color_ext.dart';
import 'background_painter.dart';
import 'game_engine.dart';
import 'level.dart';

/// Dibuja el escenario en perspectiva: cielo, mar lejano, suelo con franjas que avanzan hacia la
/// cámara, carriles y palmeras que desfilan a los lados. El punto de fuga está en el horizonte.
void paintWorld(Canvas canvas, Size size, GameEngine e) {
  final theme = e.level.theme;
  final t = e.elapsed;
  final horizon = e.horizonY;
  final ground = e.groundY;
  final shore = horizon + (ground - horizon) * 0.2; // donde el mar se encuentra con la arena

  // Cielo.
  final skyRect = Rect.fromLTWH(0, 0, size.width, shore + 1);
  canvas.drawRect(
    skyRect,
    Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [theme.skyTop, theme.skyBottom]).createShader(skyRect),
  );
  if (theme.night) paintStars(canvas, size, horizon, t);
  if (theme.name == 'Aurora') _aurora(canvas, size, horizon, t);
  paintSun(canvas, size, horizon, theme, t);
  paintClouds(canvas, size, horizon, theme, t);

  // Bruma en el horizonte: da profundidad.
  final haze = Rect.fromLTWH(0, horizon - 36, size.width, 60);
  canvas.drawRect(
    haze,
    Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.o(0), Colors.white.o(theme.night ? 0.08 : 0.28)]).createShader(haze),
  );

  _sea(canvas, size, horizon, shore, theme, t);
  _sand(canvas, size, e, shore);
  _palms(canvas, e);
  if (theme.rain) _rain(canvas, size, t);
}

void _aurora(Canvas canvas, Size size, double horizon, double t) {
  for (var k = 0; k < 3; k++) {
    final path = Path()..moveTo(0, horizon * (0.35 + k * 0.12));
    for (double x = 0; x <= size.width; x += 16) {
      path.lineTo(x, horizon * (0.35 + k * 0.12) + sin(x / 90 + t * 0.7 + k * 1.8) * 14 + sin(x / 40 + t * 1.3 + k) * 5);
    }
    path
      ..lineTo(size.width, horizon * 0.15)
      ..lineTo(0, horizon * 0.15)
      ..close();
    final rect = Rect.fromLTWH(0, 0, size.width, horizon);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, (k.isEven ? const Color(0xFF4DFFC4) : const Color(0xFFB07CFF)).o(0.28)],
        ).createShader(rect),
    );
  }
}

void _sea(Canvas canvas, Size size, double horizon, double shore, LevelTheme theme, double t) {
  final rect = Rect.fromLTRB(0, horizon, size.width, shore + 2);
  canvas.drawRect(
    rect,
    Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [theme.sea, theme.seaDeep]).createShader(rect),
  );
  final line = Paint()
    ..color = Colors.white.o(theme.night ? 0.14 : 0.3)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;
  const rows = 3;
  for (var r = 1; r <= rows; r++) {
    final y = horizon + (shore - horizon) * r / (rows + 1);
    final path = Path()..moveTo(0, y);
    for (double x = 0; x <= size.width; x += 10) {
      path.lineTo(x, y + sin(x / (30 + r * 8) + t * 1.5 + r * 1.9) * (1.4 + r * 0.5));
    }
    canvas.drawPath(path, line);
  }
}

/// Suelo: base de arena + franjas alternas que se mueven hacia el jugador + carriles + espuma.
void _sand(Canvas canvas, Size size, GameEngine e, double shore) {
  final theme = e.level.theme;
  final ground = e.groundY;
  final horizon = e.horizonY;
  final rect = Rect.fromLTRB(0, shore - 3, size.width, size.height);
  canvas.drawRect(
    rect,
    Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [theme.sandDark, theme.sand]).createShader(rect),
  );

  double yAt(double z) => horizon + (ground - horizon) * e.scaleAt(z);

  // Franjas: cada una mide `step` de profundidad y avanza con el mundo.
  const step = 0.16;
  final shift = e.worldScroll % step;
  final base = (e.worldScroll / step).floor();
  final stripe = Paint()..color = Colors.black.o(theme.night ? 0.10 : 0.07);
  for (var i = -1; i < 14; i++) {
    final z0 = i * step - shift;
    final z1 = z0 + step;
    if ((i + base).isOdd) continue;
    final y0 = yAt(z0.clamp(-0.28, 4.0));
    final y1 = yAt(z1.clamp(-0.28, 4.0));
    final top = min(y0, y1), bottom = max(y0, y1);
    if (bottom < shore || top > size.height) continue;
    canvas.drawRect(Rect.fromLTRB(0, max(top, shore), size.width, min(bottom, size.height)), stripe);
  }

  // Zona de juego: una "pista" más oscura que se estrecha hacia el horizonte.
  final lane = Path()
    ..moveTo(e.cx - e.fieldHalfW * 1.2 * e.scaleAt(1.6), yAt(1.6))
    ..lineTo(e.cx + e.fieldHalfW * 1.2 * e.scaleAt(1.6), yAt(1.6))
    ..lineTo(e.cx + e.fieldHalfW * 1.2 * 1.25, ground + (ground - horizon) * 0.25)
    ..lineTo(e.cx - e.fieldHalfW * 1.2 * 1.25, ground + (ground - horizon) * 0.25)
    ..close();
  canvas.drawPath(lane, Paint()..color = Colors.black.o(theme.night ? 0.10 : 0.06));

  // Líneas de carril que convergen en el punto de fuga.
  final guide = Paint()
    ..color = Colors.white.o(theme.night ? 0.10 : 0.22)
    ..strokeWidth = 1.4
    ..style = PaintingStyle.stroke;
  for (final l in const [-1.0, -0.35, 0.35, 1.0]) {
    final sFar = e.scaleAt(1.6), sNear = 1.25;
    canvas.drawLine(
      Offset(e.cx + l * e.fieldHalfW * sFar, horizon + (ground - horizon) * sFar),
      Offset(e.cx + l * e.fieldHalfW * sNear, horizon + (ground - horizon) * sNear),
      guide,
    );
  }

  // Espuma en la orilla.
  final foam = Path()..moveTo(0, shore);
  for (double x = 0; x <= size.width; x += 12) {
    foam.lineTo(x, shore + sin(x / 40 + e.elapsed * 1.2) * 2.2);
  }
  canvas.drawPath(foam, Paint()
    ..color = Colors.white.o(0.6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3);
}

/// Palmeras a ambos lados que avanzan hacia la cámara (lejos: pequeñas; cerca: enormes).
void _palms(Canvas canvas, GameEngine e) {
  const spacing = 0.42;
  const count = 6;
  const period = spacing * count;
  final theme = e.level.theme;

  final entries = <(double z, double lane, int k)>[];
  for (var k = 0; k < count; k++) {
    for (final side in const [-1.0, 1.0]) {
      final z = ((k * spacing - e.worldScroll + (side > 0 ? spacing / 2 : 0)) % period + period) % period - 0.25;
      entries.add((z, side * 1.95, k));
    }
  }
  entries.sort((a, b) => b.$1.compareTo(a.$1)); // lejos primero

  for (final (z, lane, k) in entries) {
    if (z < -0.2) continue;
    final s = e.scaleAt(max(z, 0));
    final base = e.groundPoint(lane, max(z, 0));
    canvas.save();
    canvas.translate(base.dx, base.dy + 6 * s);
    canvas.scale(s, s);
    paintPalm(canvas, Offset.zero, 270, lane > 0 ? -34 : 34, e.elapsed, theme, k + (lane > 0 ? 3.0 : 0.0));
    canvas.restore();
  }
}

void _rain(Canvas canvas, Size size, double t) {
  final p = Paint()
    ..color = Colors.white.o(0.28)
    ..strokeWidth = 1.3
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 70; i++) {
    final x = (i * 97.0 + t * 90) % (size.width + 60) - 30;
    final y = (i * 53.0 + t * 520) % (size.height + 40) - 20;
    canvas.drawLine(Offset(x, y), Offset(x - 5, y + 16), p);
  }
}
