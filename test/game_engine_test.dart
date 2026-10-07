import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:coco_loco/game/game_engine.dart';
import 'package:coco_loco/game/level.dart';

void main() {
  GameEngine make() {
    final e = GameEngine(levels.first, random: Random(1))..resize(const Size(400, 800));
    return e;
  }

  test('atrapar un coco suma un punto', () {
    final e = make();
    e.items.add(Item(kind: ItemKind.coconut, x: e.playerX, y: e.playerTop + 20, fallSpeed: 0, spin: 0));
    e.update(0.016);
    expect(e.score, 1);
    expect(e.lives, levels.first.lives);
  });

  test('un coco que toca el suelo quita una vida', () {
    final e = make();
    e.items.add(Item(kind: ItemKind.coconut, x: 20, y: 790, fallSpeed: 0, spin: 0));
    e.update(0.016);
    expect(e.lives, levels.first.lives - 1);
  });

  test('una roca atrapada quita una vida', () {
    final e = make();
    e.items.add(Item(kind: ItemKind.rock, x: e.playerX, y: e.playerTop + 20, fallSpeed: 0, spin: 0));
    e.update(0.016);
    expect(e.lives, levels.first.lives - 1);
    expect(e.score, 0);
  });

  test('ganar al llegar a la meta', () {
    final e = make()..score = levels.first.goal - 1;
    e.items.add(Item(kind: ItemKind.coconut, x: e.playerX, y: e.playerTop + 20, fallSpeed: 0, spin: 0));
    e.update(0.016);
    expect(e.status, GameStatus.won);
    expect(e.stars, 3);
  });
}
