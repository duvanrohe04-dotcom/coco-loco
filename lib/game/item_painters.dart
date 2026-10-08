import 'dart:math';

import 'package:flutter/material.dart';

import '../core/color_ext.dart';
import 'game_engine.dart';

/// Dibuja un objeto que cae centrado en [c].
void paintItem(Canvas canvas, Item item) {
  final c = Offset(item.x, item.y);
  switch (item.kind) {
    case ItemKind.coconut:
      paintCoconut(canvas, c, Item.radius, item.rot);
    case ItemKind.golden:
      paintCoconut(canvas, c, Item.radius, item.rot, golden: true);
    case ItemKind.rock:
      paintRock(canvas, c, Item.radius, item.rot);
  }
}

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
    canvas.drawArc(rect.deflate(3 + i * 1.2), a, 0.9, false, fiber);
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
  canvas.drawPath(
    path,
    Paint()
      ..color = const Color(0xFF1B1E22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6,
  );
  // Grietas.
  final crack = Paint()
    ..color = const Color(0xFF1B1E22)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  canvas.drawPath(
    Path()
      ..moveTo(-r * 0.2, -r * 0.5)
      ..lineTo(0, -r * 0.1)
      ..lineTo(-r * 0.15, r * 0.25),
    crack,
  );
  canvas.restore();
}

/// Icono pequeño de coco para el HUD.
class CoconutIcon extends StatelessWidget {
  const CoconutIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _CoconutIconPainter()));
}

class _CoconutIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => paintCoconut(canvas, size.center(Offset.zero), size.width / 2 - 1, 0);

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
