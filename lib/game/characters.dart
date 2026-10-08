import 'package:flutter/material.dart';

import 'photo_painter.dart';

/// Personajes jugables: la cara de cada foto sobre un cuerpecito animado.
///
/// Los identificadores (`mochi`, `dino`, `robot`) se conservan a propósito: así los perfiles guardados
/// en los dispositivos y las cuentas del servidor (que solo aceptan esos tres valores) siguen siendo
/// válidos sin tocar el backend. Lo que cambia es el nombre que se ve y el dibujo.
enum Character {
  mochi('Capucha', 'p1', Color(0xFFF2F6FF), Color(0xFF1F4FD6)),
  dino('Gorra', 'p2', Color(0xFFEDEDED), Color(0xFF2A2F3A)),
  robot('Risas', 'p3', Color(0xFF2E5BD0), Color(0xFFFFFFFF));

  const Character(this.label, this.photo, this.shirt, this.accent);

  final String label;
  final String photo;
  final Color shirt;
  final Color accent;

  CustomPainter painter({double facing = 1, double walk = 0, double energy = 0, double happy = 0}) =>
      PhotoPainter(photo: photo, shirt: shirt, accent: accent, facing: facing, walk: walk, energy: energy, happy: happy);
}

/// Personaje elegido por el jugador actual (lo leen el menú y la escena).
final selectedCharacter = ValueNotifier<Character>(Character.mochi);
