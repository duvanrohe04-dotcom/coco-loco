import 'package:flutter/material.dart';

import '../core/color_ext.dart';
import 'game_engine.dart';

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
    ..strokeWidth = 1.3
    ..strokeCap = StrokeCap.round;
  for (final t in const [0.16, 0.32, 0.48, 0.64]) {
    // Corte transversal: mismo punto de avance (t) en el lomo y en la cara interior del cuerno.
    canvas.drawLine(_bezier(o0, o1, o2, o3, t), _bezier(i0, i1, i2, o3, t), ring);
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

/// Ubre de vaca (el obstáculo): saco rosa con cuatro pezones y manchitas.
void paintUdder(Canvas canvas, Offset c, double r, double rot) {
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

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
