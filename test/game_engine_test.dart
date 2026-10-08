import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:coco_loco/game/game_engine.dart';
import 'package:coco_loco/game/level.dart';

void main() {
  GameEngine make({Level? level, double startDelay = 0}) =>
      GameEngine(level ?? levels.first, random: Random(1), startDelay: startDelay)..resize(const Size(400, 800));

  /// Un objeto que llega al jugador en el siguiente cuadro, en el carril indicado.
  Item arriving(ItemKind kind, double lane) => Item(kind: kind, lane: lane, z: 0.001);

  group('atrapar y fallar', () {
    test('atrapar un coco suma un punto', () {
      final e = make();
      e.items.add(arriving(ItemKind.coconut, e.playerLane));
      e.update(0.016);
      expect(e.score, 1);
      expect(e.lives, levels.first.lives);
    });

    test('el coco dorado vale tres', () {
      final e = make();
      e.items.add(arriving(ItemKind.golden, e.playerLane));
      e.update(0.016);
      expect(e.score, 3);
    });

    test('un coco que pasa de largo quita una vida y rompe la racha', () {
      final e = make()..streak = 4;
      e.items.add(arriving(ItemKind.coconut, 0.9));
      e.update(0.016);
      expect(e.lives, levels.first.lives - 1);
      expect(e.streak, 0);
    });

    test('una roca atrapada quita una vida; una esquivada no', () {
      final hit = make();
      hit.items.add(arriving(ItemKind.rock, hit.playerLane));
      hit.update(0.016);
      expect(hit.lives, levels.first.lives - 1);
      expect(hit.score, 0);

      final dodged = make();
      dodged.items.add(arriving(ItemKind.rock, 0.9));
      dodged.update(0.016);
      expect(dodged.lives, levels.first.lives);
    });

    test('cinco cocos seguidos dan un punto extra', () {
      final e = make();
      for (var i = 0; i < 5; i++) {
        e.items.add(arriving(ItemKind.coconut, e.playerLane));
        e.update(0.016);
      }
      expect(e.score, 6); // 5 cocos + 1 de racha
      expect(e.bestStreak, 5);
    });

    test('ganar al llegar a la meta', () {
      final e = make()..score = levels.first.goal - 1;
      e.items.add(arriving(ItemKind.coconut, e.playerLane));
      e.update(0.016);
      expect(e.status, GameStatus.won);
      expect(e.stars, 3);
    });

    test('perder al quedarse sin vidas', () {
      final e = make()..lives = 1;
      e.items.add(arriving(ItemKind.coconut, 0.9));
      e.update(0.016);
      expect(e.status, GameStatus.lost);
    });
  });

  group('poderes', () {
    test('el escudo bloquea una roca y se gasta', () {
      final e = make()..shield = true;
      e.items.add(arriving(ItemKind.rock, e.playerLane));
      e.update(0.016);
      expect(e.lives, levels.first.lives);
      expect(e.shield, isFalse);
    });

    test('la bomba aturde: no deja moverse', () {
      final e = make();
      e.items.add(arriving(ItemKind.bomb, e.playerLane));
      e.update(0.016);
      expect(e.lives, levels.first.lives - 1);
      expect(e.stun, greaterThan(0));
      final x = e.playerX;
      e.dragBy(50);
      expect(e.playerX, x);
    });

    test('el corazón da una vida y respeta el máximo', () {
      final e = make()..lives = 1;
      e.items.add(arriving(ItemKind.heart, e.playerLane));
      e.update(0.016);
      expect(e.lives, 2);

      final full = make()..lives = make().maxLives;
      full.items.add(arriving(ItemKind.heart, full.playerLane));
      full.update(0.016);
      expect(full.lives, full.maxLives);
    });

    test('puntos x2 duplica lo que vale un coco', () {
      final e = make()..doubleT = 5;
      e.items.add(arriving(ItemKind.coconut, e.playerLane));
      e.update(0.016);
      expect(e.score, 2);
    });

    test('el imán atrae los cocos hacia el jugador', () {
      final e = make()..magnetT = 7;
      e.items.add(Item(kind: ItemKind.coconut, lane: 0.8, z: 0.8));
      for (var i = 0; i < 200 && e.items.isNotEmpty; i++) {
        e.update(0.016);
      }
      expect(e.score, 1, reason: 'sin imán este coco, tan a un lado, se habría perdido');
    });

    test('la cámara lenta frena a los objetos', () {
      final normal = make();
      final slow = make()..slowT = 5;
      for (final e in [normal, slow]) {
        e.items.add(Item(kind: ItemKind.coconut, lane: 0, z: 1));
        for (var i = 0; i < 10; i++) {
          e.update(0.05);
        }
      }
      expect(slow.items.first.z, greaterThan(normal.items.first.z));
    });

    test('los poderes caducan con el tiempo', () {
      final e = make()..magnetT = 0.1;
      e.update(0.05);
      e.update(0.05);
      e.update(0.05);
      expect(e.magnetT, 0);
    });
  });

  group('oleadas y ritmo', () {
    test('la cuenta atrás congela el juego y luego arranca', () {
      final e = make(startDelay: 1);
      e.items.add(Item(kind: ItemKind.coconut, lane: 0, z: 1));
      for (var i = 0; i < 10; i++) {
        e.update(0.05); // cada paso se limita a 0,05 s
      }
      expect(e.countdown, closeTo(0.5, 1e-9));
      expect(e.items.first.z, 1, reason: 'durante la cuenta atrás nada se mueve');
      for (var i = 0; i < 11; i++) {
        e.update(0.05);
      }
      expect(e.countdown, 0);
      expect(e.items.first.z, lessThan(1));
    });

    test('una pared de rocas siempre deja un hueco con premio', () {
      const wallLevel = Level(
        number: 99,
        goal: 100,
        lives: 3,
        travelTime: 2,
        spawnInterval: 0.1,
        rockChance: 0,
        bombChance: 0,
        goldenChance: 0,
        powerChance: 0,
        wallChance: 1,
        rowChance: 0,
        zigzagChance: 0,
        theme: LevelTheme(
          name: 't',
          skyTop: Color(0xFF000000),
          skyBottom: Color(0xFF000000),
          sea: Color(0xFF000000),
          seaDeep: Color(0xFF000000),
          sand: Color(0xFF000000),
          sandDark: Color(0xFF000000),
          sun: Color(0xFF000000),
        ),
      );
      final e = make(level: wallLevel);
      e.update(0.05);
      e.update(0.05); // pasa el intervalo de 0,1 s y sale la primera pared
      expect(e.items.length, 3);
      expect(e.items.where((i) => i.isHazard).length, 2);
      expect(e.items.where((i) => i.points > 0).length, 1);
      expect(e.items.map((i) => i.z).toSet().length, 1, reason: 'toda la pared llega a la vez');
      expect(e.bossAttack, 1);
    });
  });

  group('justicia del generador', () {
    test('nunca pone dos premios seguidos que sea imposible alcanzar', () {
      for (final size in const [Size(390, 844), Size(800, 451)]) {
        for (final level in [levels[11], levels[19]]) {
          final e = GameEngine(level, random: Random(5), startDelay: 0)..resize(size);
          final seen = <Item>{};
          final groups = <(double time, List<double> lanes)>[];
          for (var i = 0; i < 60 * 120; i++) {
            e.lives = 99; // la partida no debe terminar
            e.score = 0;
            e.update(1 / 60);
            final fresh = e.items.where((it) => !seen.contains(it)).toList();
            seen.addAll(fresh);
            final good = [for (final it in fresh) if (it.points > 0) it.lane];
            if (good.isNotEmpty) groups.add((e.elapsed, good));
          }
          expect(groups.length, greaterThan(20));
          for (var i = 1; i < groups.length; i++) {
            final dt = groups[i].$1 - groups[i - 1].$1;
            var dist = double.infinity;
            for (final a in groups[i - 1].$2) {
              for (final b in groups[i].$2) {
                dist = min(dist, (a - b).abs() * e.fieldHalfW);
              }
            }
            expect(dist, lessThanOrEqualTo(GameEngine.walkSpeed * dt + GameEngine.catchRadius),
                reason: 'nivel ${level.number} en $size: ${dist.round()} px en ${dt.toStringAsFixed(2)} s');
          }
        }
      }
    });

    test('una fila de tres cocos se atrapa de golpe en cualquier tamaño de pantalla', () {
      const rowLevel = Level(
        number: 98,
        goal: 100,
        lives: 3,
        travelTime: 2,
        spawnInterval: 0.1,
        rockChance: 0,
        bombChance: 0,
        goldenChance: 0,
        powerChance: 0,
        wallChance: 0,
        rowChance: 1,
        zigzagChance: 0,
        theme: LevelTheme(
          name: 't',
          skyTop: Color(0xFF000000),
          skyBottom: Color(0xFF000000),
          sea: Color(0xFF000000),
          seaDeep: Color(0xFF000000),
          sand: Color(0xFF000000),
          sandDark: Color(0xFF000000),
          sun: Color(0xFF000000),
        ),
      );
      for (final size in const [Size(390, 844), Size(800, 451), Size(1400, 800)]) {
        final e = GameEngine(rowLevel, random: Random(2), startDelay: 0)..resize(size);
        e.update(0.05);
        e.update(0.05);
        expect(e.items.length, 3);
        final lanes = e.items.map((i) => i.lane).toList()..sort();
        final middle = lanes[1];
        for (final lane in lanes) {
          expect(((lane - middle) * e.fieldHalfW).abs(), lessThanOrEqualTo(GameEngine.catchRadius), reason: 'en $size');
        }
      }
    });
  });

  group('perspectiva', () {
    test('a z=0 el objeto está sobre el jugador y a z=1 más pequeño y más arriba', () {
      final e = make();
      final near = e.groundPoint(0, 0);
      final far = e.groundPoint(0, 1);
      expect(near.dx, e.cx);
      expect(near.dy, e.groundY);
      expect(e.scaleAt(0), 1);
      expect(e.scaleAt(1), lessThan(0.5));
      expect(far.dy, lessThan(near.dy));
      expect(far.dy, greaterThan(e.horizonY));
    });

    test('el jugador no puede salirse del campo', () {
      final e = make();
      e.dragBy(10000);
      expect(e.playerLane, closeTo(1, 1e-9));
      e.dragBy(-10000);
      expect(e.playerLane, closeTo(-1, 1e-9));
    });
  });

  group('niveles', () {
    test('hay 20 niveles y los jefes están en el 5, 10, 15 y 20', () {
      expect(levels.length, 20);
      expect(levels.where((l) => l.isBoss).map((l) => l.number), [5, 10, 15, 20]);
    });

    test('la dificultad sube: los objetos llegan cada vez más rápido', () {
      for (var i = 1; i < levels.length; i++) {
        expect(levels[i].travelTime, lessThanOrEqualTo(levels[i - 1].travelTime));
        expect(levels[i].spawnInterval, lessThanOrEqualTo(levels[i - 1].spawnInterval * 1.2));
      }
      expect(levels.first.travelTime, greaterThan(levels.last.travelTime * 2));
    });

    test('las mecánicas se introducen poco a poco', () {
      expect(levels[0].rockChance, 0);
      expect(levels[1].rockChance, greaterThan(0));
      expect(levels[1].powerChance, 0);
      expect(levels[2].powerChance, greaterThan(0));
      expect(levels[2].wallChance, 0);
      expect(levels[3].wallChance, greaterThan(0));
      expect(levels[6].bombChance, 0);
      expect(levels[7].bombChance, greaterThan(0));
    });

    test('tres vidas (cuatro en los jefes), una meta alcanzable y un escenario', () {
      for (final l in levels) {
        expect(l.lives, l.isBoss ? 4 : 3);
        expect(l.goal, inInclusiveRange(8, 80));
        expect(themes, contains(l.theme));
      }
    });
  });
}
