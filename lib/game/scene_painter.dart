import 'dart:math';

import 'package:flutter/material.dart';

import '../core/color_ext.dart';
import 'boss_painter.dart';
import 'characters.dart';
import 'game_engine.dart';
import 'item_painters.dart';
import 'world_painter.dart';

/// Pinta toda la escena a partir del estado del [GameEngine].
/// Se repinta solo cuando el motor notifica (sin reconstruir widgets).
class ScenePainter extends CustomPainter {
  ScenePainter(this.engine) : super(repaint: engine);

  final GameEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    final e = engine;

    canvas.save();
    if (e.shake > 0) {
      // Temblor de pantalla al recibir un golpe.
      canvas.translate(sin(e.elapsed * 90) * 7 * e.shake, cos(e.elapsed * 77) * 5 * e.shake);
    }

    paintWorld(canvas, size, e);
    if (e.level.isBoss) _boss(canvas, e);
    _items(canvas, e);
    _player(canvas, e);

    for (final p in e.particles) {
      canvas.drawCircle(Offset(p.x, p.y), p.size * p.life, Paint()..color = p.color.o(p.life));
    }
    for (final p in e.popups) {
      _popup(canvas, p);
    }
    canvas.restore();

    _overlays(canvas, size, e);
  }

  // ---- Jefe -------------------------------------------------------------------

  void _boss(Canvas canvas, GameEngine e) {
    final spec = e.level.boss!;
    final shore = e.horizonY + (e.groundY - e.horizonY) * 0.2;
    final width = min(e.arena.width * 0.55, 230.0);
    paintBoss(canvas, Offset(e.cx, shore - 2), width, spec, e.elapsed, e.bossHit, e.bossAttack);
  }

  // ---- Objetos ----------------------------------------------------------------

  void _items(Canvas canvas, GameEngine e) {
    // De lejos a cerca, para que los cercanos tapen a los lejanos.
    final sorted = [...e.items]..sort((a, b) => b.z.compareTo(a.z));
    for (final it in sorted) {
      final s = e.scaleAt(it.z);
      final ground = e.groundPoint(it.lane, it.z);
      final height = e.heightOf(it) * s;
      final bob = it.isPowerUp ? sin(e.elapsed * 3 + it.lane * 4) * 4 * s : 0.0;
      // Nace pequeño y crece (efecto de aparecer en el horizonte).
      final pop = ((1 - it.z) * 14).clamp(0.0, 1.0);
      final r = GameEngine.itemRadius * 1.5 * s * pop;
      if (r < 0.5) continue;

      // Sombra en el suelo: más pequeña y tenue cuanto más alto está el objeto.
      final lift = (height / (200 * s)).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(center: ground, width: r * (2.3 - 0.8 * lift), height: r * (0.75 - 0.25 * lift)),
        Paint()..color = Colors.black.o(0.3 * (1 - 0.5 * lift)),
      );

      paintItem(canvas, it, Offset(ground.dx, ground.dy - height + bob), r);
    }
  }

  // ---- Jugador ----------------------------------------------------------------

  void _player(Canvas canvas, GameEngine e) {
    final base = Offset(e.playerX, e.groundY);
    canvas.drawOval(Rect.fromCenter(center: base.translate(0, -4), width: 92, height: 20), Paint()..color = Colors.black.o(0.3));

    canvas.save();
    canvas.translate(e.playerX - GameEngine.playerW / 2, e.playerTop);
    // Si está aturdido, parpadea.
    if (e.stun > 0 && (e.elapsed * 14).floor().isEven) {
      canvas.saveLayer(const Rect.fromLTWH(-20, -20, GameEngine.playerW + 40, GameEngine.playerH + 40), Paint()..color = Colors.white.o(0.55));
    } else {
      canvas.save();
    }
    selectedCharacter.value
        .painter(facing: e.facing, walk: e.walkPhase, energy: e.energy, happy: e.happy)
        .paint(canvas, const Size(GameEngine.playerW, GameEngine.playerH));
    canvas.restore();
    canvas.restore();

    final chest = Offset(e.playerX, e.groundY - GameEngine.playerH * 0.55);
    if (e.shield) {
      final pulse = 1 + 0.03 * sin(e.elapsed * 6);
      final r = 74 * pulse;
      canvas.drawCircle(chest, r, Paint()..color = const Color(0xFF7FD4FF).o(0.18));
      canvas.drawCircle(chest, r, Paint()..color = const Color(0xFFBFEAFF).o(0.85)..style = PaintingStyle.stroke..strokeWidth = 3);
      canvas.drawArc(Rect.fromCircle(center: chest, radius: r - 8), -2.4, 0.9, false, Paint()..color = Colors.white.o(0.7)..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round);
    }
    if (e.magnetT > 0) {
      // Anillos que se encogen hacia el jugador.
      for (var i = 0; i < 2; i++) {
        final f = (e.elapsed * 0.9 + i * 0.5) % 1.0;
        canvas.drawCircle(chest, 150 * (1 - f) + 30, Paint()..color = const Color(0xFFFF7A7A).o(0.45 * (1 - f))..style = PaintingStyle.stroke..strokeWidth = 3);
      }
    }
    if (e.stun > 0) {
      // Estrellitas girando sobre la cabeza.
      final head = Offset(e.playerX, e.playerTop + 6);
      for (var i = 0; i < 3; i++) {
        final a = e.elapsed * 7 + i * 2 * pi / 3;
        final p = head + Offset(cos(a) * 26, sin(a) * 7);
        canvas.drawCircle(p, 5, Paint()..color = const Color(0xFFFFD84D));
        canvas.drawCircle(p, 2, Paint()..color = Colors.white);
      }
    }
  }

  // ---- Texto flotante ---------------------------------------------------------

  void _popup(Canvas canvas, Popup p) {
    final alpha = (p.life * 1.6).clamp(0.0, 1.0);
    final scale = 1 + (1 - p.life) * 0.12;
    TextPainter make(Paint? foreground, Color? color) => TextPainter(
          text: TextSpan(
            text: p.text,
            style: TextStyle(fontSize: 26 * scale, fontWeight: FontWeight.w900, foreground: foreground, color: color),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

    final outline = make(Paint()..style = PaintingStyle.stroke..strokeWidth = 5..strokeJoin = StrokeJoin.round..color = const Color(0xFF14264F).o(alpha), null);
    final fill = make(null, p.color.o(alpha));
    final at = Offset(p.x - fill.width / 2, p.y - fill.height / 2);
    outline.paint(canvas, at);
    fill.paint(canvas, at);
  }

  // ---- Superposiciones --------------------------------------------------------

  void _overlays(Canvas canvas, Size size, GameEngine e) {
    final rect = Offset.zero & size;
    if (e.slowT > 0) {
      // Tinte azulado y viñeta suave en cámara lenta.
      canvas.drawRect(rect, Paint()..color = const Color(0xFF6A5CFF).o(0.10));
      canvas.drawRect(
        rect,
        Paint()..shader = RadialGradient(radius: 0.95, colors: [Colors.transparent, const Color(0xFF3B2A9A).o(0.35)], stops: const [0.6, 1]).createShader(rect),
      );
    }
    if (e.hurt > 0) {
      canvas.drawRect(
        rect,
        Paint()..shader = RadialGradient(radius: 0.9, colors: [Colors.transparent, Colors.red.o(0.45 * e.hurt)], stops: const [0.55, 1]).createShader(rect),
      );
    }
    if (e.comboFlash > 0) {
      canvas.drawRect(
        rect,
        Paint()..shader = RadialGradient(radius: 0.9, colors: [Colors.transparent, const Color(0xFFFFC21A).o(0.28 * e.comboFlash)], stops: const [0.6, 1]).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScenePainter old) => old.engine != engine;
}
