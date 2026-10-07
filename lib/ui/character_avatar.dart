import 'package:flutter/material.dart';

import '../game/characters.dart';

/// Retrato estático de un personaje (para tarjetas, perfil y login).
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar(this.character, {super.key, this.width = 60, this.happy = 0});

  final Character character;
  final double width;
  final double happy;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(width, width * 1.12), painter: character.painter(happy: happy));
}

/// Fila para elegir personaje; la usan el login y el perfil.
class CharacterChooser extends StatelessWidget {
  const CharacterChooser({super.key, required this.selected, required this.onChanged, this.cardWidth = 88});

  final Character selected;
  final ValueChanged<Character> onChanged;
  final double cardWidth;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final ch in Character.values)
            Semantics(
              button: true,
              selected: ch == selected,
              label: ch.label,
              child: GestureDetector(
                onTap: () => onChanged(ch),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: cardWidth,
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                  decoration: BoxDecoration(
                    color: ch == selected ? const Color(0xFFFFF4CC) : const Color(0xFFEFF4FB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ch == selected ? const Color(0xFFFFB800) : const Color(0xFFCBD7E8), width: ch == selected ? 3.5 : 2),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CharacterAvatar(ch, width: cardWidth - 36),
                    const SizedBox(height: 4),
                    Text(ch.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1B3A7A))),
                  ]),
                ),
              ),
            ),
        ],
      );
}
