import 'dart:math';

import 'package:flutter/material.dart';

import '../core/color_ext.dart';
import 'game_engine.dart';

/// Dibuja un objeto del juego centrado en [c], con radio [r] (px).
void paintItem(Canvas canvas, Item item, Offset c, double r) => paintKind(canvas, item.kind, c, r, item.rot);

void paintKind(Canvas canvas, ItemKind kind, Offset c, double r, double rot) {
  switch (kind) {
    case ItemKind.coconut:
      paintCoconut(canvas, c, r, rot);
    case ItemKind.golden:
      paintCoconut(canvas, c, r, rot, golden: true);
    case ItemKind.rock:
      paintRock(canvas, c, r, rot);
    case ItemKind.bomb:
      paintBomb(canvas, c, r, rot);
    case ItemKind.heart:
      paintHeart(canvas, c, r, rot);
    case ItemKind.shield:
      paintShield(canvas, c, r, rot);
    case ItemKind.magnet:
      paintMagnet(canvas, c, r, rot);
    case ItemKind.slow:
      paintHourglass(canvas, c, r, rot);
    case ItemKind.double:
      paintDouble(canvas, c, r, rot);
  }
}

/// Halo que hace llamativos a los poderes (pulsa suavemente con [phase]).
void _aura(Canvas canvas, Offset c, double r, Color color, double phase) {
  final k = 1.7 + 0.15 * sin(phase * 2);
  canvas.drawCircle(
    c,
    r * k,
    Paint()..shader = RadialGradient(colors: [color.o(0.65), color.o(0)]).createShader(Rect.fromCircle(center: c, radius: r * k)),
  );
}

Paint _outline(Color color, double w) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;

// ---- Coco y coco dorado -------------------------------------------------------

void paintCoconut(Canvas canvas, Offset c, double r, double rot, {bool golden = false}) {
  canvas.save();
  canvas.translate(c.dx, c.dy);

  if (golden) {
    canvas.drawCircle(
      Offset.zero,
      r * 1.9,
      Paint()
        ..shader = RadialGradient(colors: [const Color(0xFFFFE680).o(0.7), const Color(0x00FFE680)])
            .createShader(Rect.fromCircle(center: Offset.zero, radius: r * 1.9)),
    );
  }

  canvas.rotate(rot);
  final rect = Rect.fromCircle(center: Offset.zero, radius: r);
  final colors = golden
      ? const [Color(0xFFFFF3A6), Color(0xFFFFC21A), Color(0xFFB87800)]
      : const [Color(0xFFA9774A), Color(0xFF5E3C20), Color(0xFF34200F)];
  canvas.drawCircle(
    Offset.zero,
    r,
    Paint()..shader = RadialGradient(center: const Alignment(-0.4, -0.45), colors: colors, stops: const [0, 0.55, 1]).createShader(rect),
  );

  // Fibras de la cáscara.
  final fiber = Paint()
    ..color = (golden ? Colors.white : const Color(0xFFD1A06A)).o(0.35)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  for (var i = 0; i < 4; i++) {
    final a = i * pi / 2 + 0.4;
    canvas.drawArc(rect.deflate(r * 0.17 + i * r * 0.07), a, 0.9, false, fiber);
  }

  // Los tres "ojos" del coco.
  final eye = Paint()..color = golden ? const Color(0xFF7A4B00) : const Color(0xFF160B04);
  for (final p in const [Offset(-5, -3), Offset(5, -3), Offset(0, 5)]) {
    canvas.drawCircle(p * (r / 18), r * 0.15, eye);
  }

  canvas.restore();

  // Brillo (no rota con el coco).
  canvas.drawOval(
    Rect.fromCenter(center: c.translate(-r * 0.38, -r * 0.45), width: r * 0.55, height: r * 0.32),
    Paint()..color = Colors.white.o(0.45),
  );
}

// ---- Obstáculos ---------------------------------------------------------------

void paintRock(Canvas canvas, Offset c, double r, double rot) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(rot);

  const radii = [1.0, 0.82, 1.05, 0.88, 1.0, 0.8, 1.04, 0.9];
  final path = Path();
  for (var i = 0; i < radii.length; i++) {
    final a = i * 2 * pi / radii.length;
    final p = Offset(cos(a), sin(a)) * (r * radii[i]);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  path.close();

  final rect = Rect.fromCircle(center: Offset.zero, radius: r);
  canvas.drawPath(
    path,
    Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.5), colors: [Color(0xFF9AA0A8), Color(0xFF555A63), Color(0xFF2E3238)]).createShader(rect),
  );
  canvas.drawPath(path, _outline(const Color(0xFF1B1E22), max(1.0, r * 0.07)));
  // Grietas.
  canvas.drawPath(
    Path()
      ..moveTo(-r * 0.2, -r * 0.5)
      ..lineTo(0, -r * 0.1)
      ..lineTo(-r * 0.15, r * 0.25),
    _outline(const Color(0xFF1B1E22), max(0.8, r * 0.05)),
  );
  canvas.restore();
}

/// Bomba: más peligrosa que la roca (además de quitar vida, aturde).
void paintBomb(Canvas canvas, Offset c, double r, double rot) {
  final rect = Rect.fromCircle(center: c, radius: r);
  canvas.drawCircle(
    c,
    r,
    Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.5), colors: [Color(0xFF6B7380), Color(0xFF23262E), Color(0xFF0B0C10)], stops: [0, 0.55, 1]).createShader(rect),
  );
  canvas.drawCircle(c, r, _outline(const Color(0xFF05060A), max(1.0, r * 0.07)));
  // Tapa y mecha.
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(r * 0.38, -r * 0.92), width: r * 0.5, height: r * 0.3), Radius.circular(r * 0.08)),
    Paint()..color = const Color(0xFF4A4F5A),
  );
  final fuse = Path()
    ..moveTo(c.dx + r * 0.42, c.dy - r * 1.05)
    ..quadraticBezierTo(c.dx + r * 0.7, c.dy - r * 1.5, c.dx + r * 1.05, c.dy - r * 1.35);
  canvas.drawPath(fuse, _outline(const Color(0xFFD7B27A), max(1.2, r * 0.1)));
  // Chispa que parpadea.
  final spark = Offset(c.dx + r * 1.05, c.dy - r * 1.35);
  final flick = 0.75 + 0.25 * sin(rot * 9);
  canvas.drawCircle(spark, r * 0.32 * flick, Paint()..color = const Color(0xFFFFB347));
  canvas.drawCircle(spark, r * 0.16 * flick, Paint()..color = Colors.white);
  // Calavera simple para que se lea como peligro.
  canvas.drawCircle(c.translate(-r * 0.22, r * 0.05), r * 0.14, Paint()..color = Colors.white.o(0.85));
  canvas.drawCircle(c.translate(r * 0.22, r * 0.05), r * 0.14, Paint()..color = Colors.white.o(0.85));
  canvas.drawRect(Rect.fromCenter(center: c.translate(0, r * 0.42), width: r * 0.5, height: r * 0.1), Paint()..color = Colors.white.o(0.85));
  canvas.drawOval(Rect.fromCenter(center: c.translate(-r * 0.38, -r * 0.45), width: r * 0.5, height: r * 0.28), Paint()..color = Colors.white.o(0.3));
}

// ---- Poderes ------------------------------------------------------------------

void paintHeart(Canvas canvas, Offset c, double r, double phase) {
  _aura(canvas, c, r, const Color(0xFFFF6B8A), phase);
  canvas.save();
  canvas.translate(c.dx, c.dy + r * 0.05);
  final beat = 1 + 0.07 * sin(phase * 4);
  canvas.scale(beat, beat);
  final path = Path()
    ..moveTo(0, r * 0.85)
    ..cubicTo(-r * 1.35, -r * 0.05, -r * 0.95, -r * 0.95, 0, -r * 0.3)
    ..cubicTo(r * 0.95, -r * 0.95, r * 1.35, -r * 0.05, 0, r * 0.85)
    ..close();
  final rect = Rect.fromCircle(center: Offset.zero, radius: r * 1.1);
  canvas.drawPath(
    path,
    Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.5), colors: [Color(0xFFFF9DB0), Color(0xFFE5254F), Color(0xFF9E1236)]).createShader(rect),
  );
  canvas.drawPath(path, _outline(const Color(0xFF5E0A20), max(1.2, r * 0.09)));
  canvas.drawOval(Rect.fromCenter(center: Offset(-r * 0.45, -r * 0.35), width: r * 0.5, height: r * 0.28), Paint()..color = Colors.white.o(0.55));
  canvas.restore();
}

void paintShield(Canvas canvas, Offset c, double r, double phase) {
  _aura(canvas, c, r, const Color(0xFF7FD4FF), phase);
  canvas.save();
  canvas.translate(c.dx, c.dy);
  final path = Path()
    ..moveTo(0, -r)
    ..lineTo(r * 0.9, -r * 0.62)
    ..cubicTo(r * 0.9, r * 0.25, r * 0.5, r * 0.78, 0, r * 1.02)
    ..cubicTo(-r * 0.5, r * 0.78, -r * 0.9, r * 0.25, -r * 0.9, -r * 0.62)
    ..close();
  final rect = Rect.fromCircle(center: Offset.zero, radius: r * 1.1);
  canvas.drawPath(
    path,
    Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFBFEAFF), Color(0xFF3F9BFF), Color(0xFF1A4FB0)]).createShader(rect),
  );
  canvas.drawPath(path, _outline(const Color(0xFF0E2C66), max(1.2, r * 0.09)));
  // Estrella central.
  final star = Path();
  for (var i = 0; i < 10; i++) {
    final a = -pi / 2 + i * pi / 5;
    final rr = i.isEven ? r * 0.46 : r * 0.2;
    final p = Offset(cos(a), sin(a)) * rr;
    i == 0 ? star.moveTo(p.dx, p.dy + r * 0.05) : star.lineTo(p.dx, p.dy + r * 0.05);
  }
  star.close();
  canvas.drawPath(star, Paint()..color = Colors.white.o(0.92));
  canvas.restore();
}

void paintMagnet(Canvas canvas, Offset c, double r, double phase) {
  _aura(canvas, c, r, const Color(0xFFFF7A7A), phase);
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(sin(phase * 2) * 0.12);
  final w = r * 0.5;
  final arc = Rect.fromCircle(center: Offset(0, r * 0.12), radius: r * 0.62);
  // Contorno oscuro, luego el rojo encima.
  for (final pass in [0, 1]) {
    final color = pass == 0 ? const Color(0xFF5E1010) : const Color(0xFFE23B3B);
    final extra = pass == 0 ? max(2.0, r * 0.14) : 0.0;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w + extra
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(arc, 0, pi, false, stroke);
    canvas.drawLine(Offset(-r * 0.62, r * 0.12), Offset(-r * 0.62, -r * 0.62), stroke);
    canvas.drawLine(Offset(r * 0.62, r * 0.12), Offset(r * 0.62, -r * 0.62), stroke);
  }
  // Puntas plateadas.
  final tip = Paint()..color = const Color(0xFFE8EEF5);
  canvas.drawRect(Rect.fromLTRB(-r * 0.62 - w / 2, -r * 0.92, -r * 0.62 + w / 2, -r * 0.62), tip);
  canvas.drawRect(Rect.fromLTRB(r * 0.62 - w / 2, -r * 0.92, r * 0.62 + w / 2, -r * 0.62), tip);
  canvas.restore();
}

void paintHourglass(Canvas canvas, Offset c, double r, double phase) {
  _aura(canvas, c, r, const Color(0xFFB9A6FF), phase);
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(sin(phase) * 0.15);
  final glass = Path()
    ..moveTo(-r * 0.62, -r * 0.88)
    ..lineTo(r * 0.62, -r * 0.88)
    ..lineTo(r * 0.12, 0)
    ..lineTo(r * 0.62, r * 0.88)
    ..lineTo(-r * 0.62, r * 0.88)
    ..lineTo(-r * 0.12, 0)
    ..close();
  canvas.drawPath(glass, Paint()..color = const Color(0xFFE6DEFF).o(0.9));
  // Arena: arriba se vacía y abajo se llena según la fase.
  final f = 0.5 + 0.5 * sin(phase * 0.8);
  canvas.save();
  canvas.clipPath(glass);
  canvas.drawRect(Rect.fromLTRB(-r, -r * 0.88 + (r * 0.88) * (1 - f), r, 0), Paint()..color = const Color(0xFFFFC857));
  canvas.drawRect(Rect.fromLTRB(-r, r * 0.88 - (r * 0.88) * (1 - f), r, r), Paint()..color = const Color(0xFFFFC857));
  canvas.restore();
  canvas.drawPath(glass, _outline(const Color(0xFF3B2A7A), max(1.2, r * 0.08)));
  final frame = Paint()..color = const Color(0xFF7A4B24);
  canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, -r * 0.95), width: r * 1.5, height: r * 0.22), Radius.circular(r * 0.08)), frame);
  canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, r * 0.95), width: r * 1.5, height: r * 0.22), Radius.circular(r * 0.08)), frame);
  canvas.restore();
}

final _doubleLabel = TextPainter(
  text: const TextSpan(text: 'x2', style: TextStyle(color: Color(0xFF7A4B00), fontSize: 26, fontWeight: FontWeight.w900)),
  textDirection: TextDirection.ltr,
)..layout();

void paintDouble(Canvas canvas, Offset c, double r, double phase) {
  _aura(canvas, c, r, const Color(0xFFFFD84D), phase);
  final rect = Rect.fromCircle(center: c, radius: r);
  canvas.drawCircle(
    c,
    r,
    Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.5), colors: [Color(0xFFFFF3A6), Color(0xFFFFC21A), Color(0xFFB87800)]).createShader(rect),
  );
  canvas.drawCircle(c, r, _outline(const Color(0xFF7A4B00), max(1.2, r * 0.09)));
  canvas.drawCircle(c, r * 0.78, _outline(const Color(0xFFB87800).o(0.7), max(1.0, r * 0.05)));
  canvas.save();
  canvas.translate(c.dx, c.dy);
  final k = r * 1.05 / _doubleLabel.width;
  canvas.scale(k, k);
  _doubleLabel.paint(canvas, Offset(-_doubleLabel.width / 2, -_doubleLabel.height / 2));
  canvas.restore();
}

// ---- Iconos para la interfaz --------------------------------------------------

/// Icono pequeño de coco para el HUD.
class CoconutIcon extends StatelessWidget {
  const CoconutIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => ItemIcon(ItemKind.coconut, size: size);
}

/// Icono de cualquier objeto (para el HUD y los avisos).
class ItemIcon extends StatelessWidget {
  const ItemIcon(this.kind, {super.key, this.size = 22});

  final ItemKind kind;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _IconPainter(kind)));
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.kind);
  final ItemKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    // Los poderes llevan un halo grande: se dibujan más pequeños para que quepa en el icono.
    final isPower = kind.index >= ItemKind.heart.index;
    paintKind(canvas, kind, size.center(Offset.zero), size.width * (isPower ? 0.3 : 0.44), 0);
  }

  @override
  bool shouldRepaint(covariant _IconPainter old) => old.kind != kind;
}
