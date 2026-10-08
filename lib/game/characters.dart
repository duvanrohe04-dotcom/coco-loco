import 'package:flutter/material.dart';

import 'dino_painter.dart';
import 'mochi_painter.dart';
import 'robot_painter.dart';

/// Personajes jugables (diseños originales). Todos se dibujan en la misma caja de 100x112.
enum Character {
  mochi('Mochi'),
  dino('Dino'),
  robot('Tuerca');

  const Character(this.label);

  final String label;

  CustomPainter painter({double facing = 1, double walk = 0, double energy = 0, double happy = 0}) => switch (this) {
        Character.mochi => MochiPainter(facing: facing, walk: walk, energy: energy, happy: happy),
        Character.dino => DinoPainter(facing: facing, walk: walk, energy: energy, happy: happy),
        Character.robot => RobotPainter(facing: facing, walk: walk, energy: energy, happy: happy),
      };
}

/// Personaje elegido por el jugador actual (lo leen el menú y la escena).
final selectedCharacter = ValueNotifier<Character>(Character.mochi);
