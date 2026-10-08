import 'package:flutter/material.dart';

import '../core/color_ext.dart';
import 'game_engine.dart';

<<<<<<< HEAD
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
=======
/// Dibuja un objeto que cae centrado en [c].
/// (Los nombres internos `coconut` y `rock` se conservan: ahora son el cacho y la ubre.)
void paintItem(Canvas canvas, Item item) {
  final c = Offset(item.x, item.y);
  switch (item.kind) {
    case ItemKind.coconut:
      paintHorn(canvas, c, Item.radius, item.rot);
    case ItemKind.golden:
      paintHorn(canvas, c, Item.radius, item.rot, golden: true);
    case ItemKind.rock:
      paintUdder(canvas, c, Item.radius, item.rot);
  }
}

/// Punto de una curva de Bézier cúbica en el instante [t].
Offset _bezier(Offset a, Offset b, Offset c, Offset d, double t) {
  final u = 1 - t;
  return a * (u * u * u) + b * (3 * u * u * t) + c * (3 * u * t * t) + d * (t * t * t);
}

/// Cacho (cuerno) de animal: curvo, con anillos y punta. Con [golden] es el cacho de oro (3 puntos).
void paintHorn(Canvas canvas, Offset c, double r, double rot, {bool golden = false}) {
>>>>>>> 0427bd4736ec5ece677ee68fc23894bf19f90872
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

  // Contorno exterior (lomo) e interior (cara cóncava) de la curva del cuerno.
  final o0 = Offset(-0.78 * r, 0.72 * r), o1 = Offset(-1.05 * r, -0.2 * r), o2 = Offset(-0.3 * r, -0.95 * r), o3 = Offset(0.95 * r, -0.88 * r);
  final i0 = Offset(0.2 * r, 0.74 * r), i1 = Offset(0.1 * r, 0.05 * r), i2 = Offset(0.2 * r, -0.4 * r);
  final path = Path()
    ..moveTo(o0.dx, o0.dy)
    ..cubicTo(o1.dx, o1.dy, o2.dx, o2.dy, o3.dx, o3.dy)
    ..cubicTo(i2.dx, i2.dy, i1.dx, i1.dy, i0.dx, i0.dy)
    ..quadraticBezierTo(-0.3 * r, 1.0 * r, o0.dx, o0.dy)
    ..close();

  final rect = Rect.fromCircle(center: Offset.zero, radius: r * 1.1);
  // Del color claro de la base a la punta oscura (de abajo-izquierda a arriba-derecha).
  final colors = golden
      ? const [Color(0xFFFFF3A6), Color(0xFFFFC21A), Color(0xFFB87800)]
      : const [Color(0xFFFBF4DE), Color(0xFFD9C59B), Color(0xFF4A3B26)];
  canvas.drawPath(
    path,
    Paint()..shader = LinearGradient(begin: Alignment.bottomLeft, end: Alignment.topRight, colors: colors, stops: const [0.15, 0.6, 1]).createShader(rect),
  );

  // Anillos del cuerno (de la base hacia la punta).
  final ring = Paint()
    ..color = (golden ? const Color(0xFF7A4B00) : const Color(0xFF6B5636)).o(0.55)
    ..style = PaintingStyle.stroke
<<<<<<< HEAD
    ..strokeWidth = 1;
  for (var i = 0; i < 4; i++) {
    final a = i * pi / 2 + 0.4;
    canvas.drawArc(rect.deflate(r * 0.17 + i * r * 0.07), a, 0.9, false, fiber);
  }

  // Los tres "ojos" del coco.
  final eye = Paint()..color = golden ? const Color(0xFF7A4B00) : const Color(0xFF160B04);
  for (final p in const [Offset(-5, -3), Offset(5, -3), Offset(0, 5)]) {
    canvas.drawCircle(p * (r / 18), r * 0.15, eye);
=======
    ..strokeWidth = 1.3
    ..strokeCap = StrokeCap.round;
  for (final t in const [0.16, 0.32, 0.48, 0.64]) {
    // Corte transversal: mismo punto de avance (t) en el lomo y en la cara interior del cuerno.
    canvas.drawLine(_bezier(o0, o1, o2, o3, t), _bezier(i0, i1, i2, o3, t), ring);
>>>>>>> 0427bd4736ec5ece677ee68fc23894bf19f90872
  }

  canvas.drawPath(
    path,
    Paint()
      ..color = golden ? const Color(0xFF6B4300) : const Color(0xFF3F3220)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.restore();

  // Brillo (no rota con el cacho).
  canvas.drawOval(
    Rect.fromCenter(center: c.translate(-r * 0.2, -r * 0.5), width: r * 0.5, height: r * 0.26),
    Paint()..color = Colors.white.o(golden ? 0.6 : 0.5),
  );
}

<<<<<<< HEAD
// ---- Obstáculos ---------------------------------------------------------------

void paintRock(Canvas canvas, Offset c, double r, double rot) {
=======
/// Ubre de vaca (el obstáculo): saco rosa con cuatro pezones y manchitas.
void paintUdder(Canvas canvas, Offset c, double r, double rot) {
>>>>>>> 0427bd4736ec5ece677ee68fc23894bf19f90872
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(rot);

  const ink = Color(0xFF5B2A3A);

  // Pezones (detrás del saco).
  for (final x in const [-0.56, -0.19, 0.19, 0.56]) {
    final teat = Path()
      ..moveTo((x - 0.14) * r, 0.25 * r)
      ..lineTo((x - 0.09) * r, 0.82 * r)
      ..quadraticBezierTo(x * r, 0.98 * r, (x + 0.09) * r, 0.82 * r)
      ..lineTo((x + 0.14) * r, 0.25 * r)
      ..close();
    canvas.drawPath(teat, Paint()..color = const Color(0xFFE7829C));
    canvas.drawPath(teat, Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeJoin = StrokeJoin.round);
  }

  // Saco: ancho, en forma de campana, con venitas y brillo.
  final bag = Path()
    ..moveTo(-1.0 * r, -0.35 * r)
    ..cubicTo(-1.0 * r, -0.95 * r, 1.0 * r, -0.95 * r, 1.0 * r, -0.35 * r)
    ..cubicTo(1.0 * r, 0.15 * r, 0.7 * r, 0.45 * r, 0, 0.45 * r)
    ..cubicTo(-0.7 * r, 0.45 * r, -1.0 * r, 0.15 * r, -1.0 * r, -0.35 * r)
    ..close();
  final rect = Rect.fromCircle(center: Offset.zero, radius: r);
  canvas.drawPath(
    bag,
    Paint()..shader = const RadialGradient(center: Alignment(-0.35, -0.55), colors: [Color(0xFFFFD6E0), Color(0xFFF7A8BC), Color(0xFFCF728B)]).createShader(rect),
  );
<<<<<<< HEAD
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
=======
  final vein = Paint()
    ..color = const Color(0xFFB04E6B).o(0.55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round;
  canvas.drawPath(Path()..moveTo(-0.45 * r, -0.4 * r)..quadraticBezierTo(-0.3 * r, -0.05 * r, -0.4 * r, 0.25 * r), vein);
  canvas.drawPath(Path()..moveTo(0.4 * r, -0.45 * r)..quadraticBezierTo(0.25 * r, -0.05 * r, 0.35 * r, 0.25 * r), vein);
  canvas.drawOval(Rect.fromCenter(center: Offset(-0.45 * r, -0.62 * r), width: r * 0.55, height: r * 0.24), Paint()..color = Colors.white.o(0.45));

  canvas.drawPath(bag, Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = 1.7..strokeJoin = StrokeJoin.round);
  canvas.restore();
}

/// Icono pequeño de cacho para el HUD.
class HornIcon extends StatelessWidget {
  const HornIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _HornIconPainter()));
}

class _HornIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => paintHorn(canvas, size.center(Offset.zero), size.width / 2 - 1, 0);
>>>>>>> 0427bd4736ec5ece677ee68fc23894bf19f90872

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
