import 'dart:math';
import 'dart:ui';

import 'package:coco_loco/game/game_engine.dart';
import 'package:coco_loco/game/level.dart';
import 'package:coco_loco/game/words.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final allVerbs = [for (final l in Words.verbs) ...l];
  final allOthers = [for (final l in Words.others) ...l];

  group('listas de palabras', () {
    test('ninguna palabra está en las dos listas (un verbo nunca es "no verbo")', () {
      expect(allVerbs.toSet().intersection(allOthers.toSet()), isEmpty);
    });

    test('sin repetidas dentro de cada lista', () {
      expect(allVerbs.toSet().length, allVerbs.length);
      expect(allOthers.toSet().length, allOthers.length);
    });

    test('caben en la etiqueta: de 2 a 7 letras, solo minúsculas', () {
      for (final w in [...allVerbs, ...allOthers]) {
        expect(w, matches(RegExp(r'^[a-z]{2,7}$')), reason: w);
      }
    });

    test('hay palabras de sobra en cada nivel de dificultad', () {
      for (final l in [...Words.verbs, ...Words.others]) {
        expect(l.length, greaterThanOrEqualTo(15));
      }
    });

    test('los primeros niveles solo usan las palabras básicas', () {
      final rnd = Random(1);
      final basicVerbs = Words.verbs[0].toSet();
      final basicOthers = Words.others[0].toSet();
      for (var i = 0; i < 300; i++) {
        expect(basicVerbs, contains(Words.verb(rnd, 1)));
        expect(basicOthers, contains(Words.other(rnd, 6)));
      }
    });

    test('los niveles altos también sacan palabras difíciles', () {
      final rnd = Random(2);
      final hard = Words.verbs[2].toSet();
      final seen = {for (var i = 0; i < 400; i++) Words.verb(rnd, 20)};
      expect(seen.intersection(hard), isNotEmpty);
    });
  });

  group('palabras en el juego', () {
    test('cocos y rocas salen con su palabra de la lista correcta; el resto, sin palabra', () {
      final verbs = {for (final l in Words.verbs) ...l};
      final others = {for (final l in Words.others) ...l};
      final e = GameEngine(levels[12], random: Random(3), startDelay: 0)..resize(const Size(800, 1400));
      var coco = 0, rock = 0;
      for (var i = 0; i < 4000; i++) {
        e.update(0.05);
        for (final it in e.items) {
          switch (it.kind) {
            case ItemKind.coconut || ItemKind.golden:
              expect(verbs, contains(it.word));
              coco++;
            case ItemKind.rock:
              expect(others, contains(it.word));
              rock++;
            default:
              expect(it.word, isNull);
          }
        }
        // Mantiene la partida viva para seguir generando objetos.
        e.lives = 99;
        e.score = 0;
        e.items.removeWhere((it) => it.z < 0.5);
      }
      expect(coco, greaterThan(50));
      expect(rock, greaterThan(10));
    });

    test('atrapar una palabra que no es verbo quita una vida; un verbo da un punto', () {
      final e = GameEngine(levels[3], random: Random(4), startDelay: 0)..resize(const Size(800, 1400));
      e.items.add(Item(kind: ItemKind.rock, lane: e.playerLane, z: 0.001, word: 'table'));
      e.update(0.016);
      expect(e.lives, levels[3].lives - 1);

      e.items.add(Item(kind: ItemKind.coconut, lane: e.playerLane, z: 0.001, word: 'eat'));
      e.update(0.016);
      expect(e.score, 1);
      expect(e.lives, levels[3].lives - 1);
    });
  });
}
