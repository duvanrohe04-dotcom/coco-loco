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
    this.rain = false,
    this.sunHeight = 0.35,
  });

  final String name;
  final Color skyTop, skyBottom, sea, seaDeep, sand, sandDark, sun;
  final bool night;

  /// Lluvia animada sobre la escena (nivel de tormenta).
  final bool rain;

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
    name: 'Tormenta',
    skyTop: Color(0xFF2F3A4A),
    skyBottom: Color(0xFF7C8A99),
    sea: Color(0xFF3F5F78),
    seaDeep: Color(0xFF223A50),
    sand: Color(0xFFB9A98A),
    sandDark: Color(0xFF8F8168),
    sun: Color(0xFFB8C4D0),
    rain: true,
    sunHeight: 0.4,
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
  LevelTheme(
    name: 'Isla volcánica',
    skyTop: Color(0xFF2A0F1F),
    skyBottom: Color(0xFFFF6A3D),
    sea: Color(0xFF7A3B3B),
    seaDeep: Color(0xFF3F1B24),
    sand: Color(0xFF6B5148),
    sandDark: Color(0xFF3F2E2A),
    sun: Color(0xFFFFC46B),
    sunHeight: 0.8,
  ),
  LevelTheme(
    name: 'Aurora',
    skyTop: Color(0xFF05122B),
    skyBottom: Color(0xFF2FCB9A),
    sea: Color(0xFF1A5C7A),
    seaDeep: Color(0xFF0B2E4A),
    sand: Color(0xFFC9D6DF),
    sandDark: Color(0xFF9FB3C1),
    sun: Color(0xFFE6FFF5),
    night: true,
    sunHeight: 0.35,
  ),
];

/// Un jefe de fin de bloque (niveles 5, 10, 15 y 20). Su barra de vida es el progreso del nivel.
class BossSpec {
  const BossSpec(this.name, this.body, this.accent, {this.arms = 2, this.spikes = false, this.crown = false});

  final String name;
  final Color body;
  final Color accent;
  final int arms;
  final bool spikes;
  final bool crown;
}

const _bosses = <int, BossSpec>{
  5: BossSpec('Cangrejo Gigante', Color(0xFFE5483B), Color(0xFFFFC857)),
  10: BossSpec('Pulpo Travieso', Color(0xFF8E5BD6), Color(0xFFFF8FD0), arms: 6),
  15: BossSpec('Golem de Lava', Color(0xFF4A3B3B), Color(0xFFFF7A1A), spikes: true),
  20: BossSpec('Rey Coco', Color(0xFF2E9B4F), Color(0xFFFFD84D), arms: 4, crown: true),
};

/// Reglas de un nivel. La dificultad crece con [number].
class Level {
  const Level({
    required this.number,
    required this.goal,
    required this.lives,
    required this.travelTime,
    required this.spawnInterval,
    required this.rockChance,
    required this.bombChance,
    required this.goldenChance,
    required this.powerChance,
    required this.wallChance,
    required this.rowChance,
    required this.zigzagChance,
    required this.theme,
    this.boss,
    this.hint,
  });

  final int number;

  /// Puntos para ganar (en un jefe, su "vida").
  final int goal;
  final int lives;

  /// Segundos que tarda un objeto en llegar desde el horizonte hasta el jugador.
  final double travelTime;

  /// Segundos entre oleadas de objetos.
  final double spawnInterval;

  /// Probabilidades (por objeto suelto o por oleada).
  final double rockChance, bombChance, goldenChance, powerChance;
  final double wallChance, rowChance, zigzagChance;
  final LevelTheme theme;
  final BossSpec? boss;

  /// Consejo que se muestra al empezar (solo cuando aparece una mecánica nueva).
  final String? hint;

  bool get isBoss => boss != null;

  String get title => isBoss ? 'Nivel $number · JEFE ${boss!.name}' : 'Nivel $number · ${theme.name}';
}

const levelCount = 20;

double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

const _hints = <int, String>{
  1: 'Atrapa los VERBOS en inglés (eat, jump, sing…). Arrastra el dedo o usa las flechas',
  2: '¡Cuidado! Las palabras con una X NO son verbos: si las atrapas pierdes una vida',
  3: 'Los objetos con brillo son poderes: ¡recógelos!',
  4: 'Las paredes de palabras X tienen un hueco con un verbo: pasa por ahí',
  5: '¡JEFE! Atrapa verbos para dejarlo sin vida',
  8: 'Las bombas te aturden un momento: ¡esquívalas!',
};

Level _buildLevel(int i) {
  final n = i + 1;
  final d = i / (levelCount - 1); // 0 (fácil) .. 1 (difícil)
  final boss = _bosses[n];
  final isBoss = boss != null;
  final baseGoal = (8 + i * 3).clamp(8, 56);
  return Level(
    number: n,
    goal: isBoss ? (baseGoal * 1.25).round() : baseGoal,
    lives: isBoss ? 4 : 3, // los jefes dan una vida de más
    travelTime: _lerp(2.7, 1.3, d),
    spawnInterval: _lerp(1.05, 0.6, d) * (isBoss ? 0.92 : 1.0),
    rockChance: i < 1 ? 0 : _lerp(0.10, 0.25, d),
    bombChance: i < 7 ? 0 : _lerp(0.04, 0.09, (i - 7) / 12),
    goldenChance: i < 1 ? 0 : 0.07,
    powerChance: i < 2 ? 0 : 0.085,
    wallChance: i < 3 ? 0 : _lerp(0.06, 0.15, d) + (isBoss ? 0.10 : 0),
    rowChance: i < 1 ? 0 : 0.12,
    zigzagChance: i < 3 ? 0 : 0.12,
    theme: themes[(i * themes.length ~/ levelCount).clamp(0, themes.length - 1)],
    boss: boss,
    hint: _hints[n],
  );
}

final List<Level> levels = List.unmodifiable(List.generate(levelCount, _buildLevel));
