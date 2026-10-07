import 'dart:math';
import 'dart:ui';

/// Ambientación visual de un grupo de niveles.
class LevelTheme {
  const LevelTheme({
    required this.name,
    required this.skyTop,
    required this.skyBottom,
    required this.sea,
    required this.seaDeep,
    required this.sand,
    required this.sandDark,
    required this.sun,
    this.night = false,
    this.sunHeight = 0.35,
  });

  final String name;
  final Color skyTop, skyBottom, sea, seaDeep, sand, sandDark, sun;
  final bool night;

  /// Posición vertical del sol/luna como fracción del cielo (0 = arriba).
  final double sunHeight;
}

const themes = <LevelTheme>[
  LevelTheme(
    name: 'Amanecer',
    skyTop: Color(0xFFFF9A8B),
    skyBottom: Color(0xFFFFE3A8),
    sea: Color(0xFF6CBAD9),
    seaDeep: Color(0xFF3F8FB8),
    sand: Color(0xFFF6DDAA),
    sandDark: Color(0xFFE2BF84),
    sun: Color(0xFFFFF3C0),
    sunHeight: 0.7,
  ),
  LevelTheme(
    name: 'Playa soleada',
    skyTop: Color(0xFF3FA9F5),
    skyBottom: Color(0xFFC4EBFF),
    sea: Color(0xFF35C2D0),
    seaDeep: Color(0xFF1B8FB5),
    sand: Color(0xFFF5D99C),
    sandDark: Color(0xFFE0BC78),
    sun: Color(0xFFFFE566),
    sunHeight: 0.3,
  ),
  LevelTheme(
    name: 'Atardecer',
    skyTop: Color(0xFF5B3F8F),
    skyBottom: Color(0xFFFF8C5A),
    sea: Color(0xFF4A78B0),
    seaDeep: Color(0xFF2B4F86),
    sand: Color(0xFFE6BC7C),
    sandDark: Color(0xFFC99A5E),
    sun: Color(0xFFFFB347),
    sunHeight: 0.75,
  ),
  LevelTheme(
    name: 'Noche estrellada',
    skyTop: Color(0xFF070F2E),
    skyBottom: Color(0xFF29478A),
    sea: Color(0xFF16406B),
    seaDeep: Color(0xFF0B2545),
    sand: Color(0xFFB8A57E),
    sandDark: Color(0xFF8E7D5B),
    sun: Color(0xFFF5F3E1),
    night: true,
    sunHeight: 0.3,
  ),
];

/// Reglas de un nivel. La dificultad crece con [number].
class Level {
  const Level({
    required this.number,
    required this.goal,
    required this.lives,
    required this.fallSpeed,
    required this.spawnInterval,
    required this.rockChance,
    required this.goldenChance,
    required this.theme,
  });

  final int number;
  final int goal;
  final int lives;

  /// Velocidad de caída en px/s.
  final double fallSpeed;

  /// Segundos entre objetos.
  final double spawnInterval;
  final double rockChance;
  final double goldenChance;
  final LevelTheme theme;

  String get title => 'Nivel $number · ${theme.name}';
}

const levelCount = 10;

Level _buildLevel(int i) => Level(
      number: i + 1,
      goal: 6 + i * 3,
      lives: 3,
      fallSpeed: 150 + i * 30,
      spawnInterval: max(0.4, 1.0 - i * 0.07),
      rockChance: i == 0 ? 0 : min(0.3, 0.08 + i * 0.025),
      goldenChance: i < 2 ? 0 : 0.06,
      theme: themes[min(themes.length - 1, i * themes.length ~/ levelCount)],
    );

final List<Level> levels = List.unmodifiable(List.generate(levelCount, _buildLevel));
