import 'package:flutter/material.dart';

import '../core/color_ext.dart';
import 'background_painter.dart';
import 'game_engine.dart';
import 'item_painters.dart';
import 'characters.dart';

/// Pinta toda la escena a partir del estado del [GameEngine].
/// Se repinta solo cuando el motor notifica (sin reconstruir widgets).
class ScenePainter extends CustomPainter {
  ScenePainter(this.engine) : super(repaint: engine);

  final GameEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    paintBackground(canvas, size, engine.level.theme, engine.elapsed);

    for (final item in engine.items) {
      paintItem(canvas, item);
    }

    canvas.save();
    canvas.translate(engine.playerX - GameEngine.playerW / 2, engine.playerTop);
    selectedCharacter.value
        .painter(
          facing: engine.facing,
          walk: engine.walkPhase,
          energy: engine.energy,
          happy: engine.happy,
        )
        .paint(canvas, const Size(GameEngine.playerW, GameEngine.playerH));
    canvas.restore();

    for (final p in engine.particles) {
      canvas.drawCircle(Offset(p.x, p.y), p.size * p.life, Paint()..color = p.color.o(p.life));
    }

    if (engine.hurt > 0) {
      final rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            radius: 0.9,
            colors: [Colors.transparent, Colors.red.o(0.45 * engine.hurt)],
            stops: const [0.55, 1],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScenePainter old) => old.engine != engine;
}
