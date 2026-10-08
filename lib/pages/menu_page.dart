import 'package:flutter/material.dart';

import '../core/color_ext.dart';
import '../core/api.dart';
import '../core/progress.dart';
import 'leaderboard_page.dart';
import '../core/session.dart';
import '../ui/character_avatar.dart';
import 'profile_page.dart';
import '../game/level.dart';
import '../game/characters.dart';
import '../ui/animated_background.dart';
import '../ui/outlined_text.dart';
import 'game_page.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  void _play(BuildContext context, Level level) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => GamePage(level: level)));

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AnimatedBackground(
          theme: themes[1],
          child: SafeArea(
            child: Stack(children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 64, 16, 160),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(children: [
                      const OutlinedText('CACHO LOCO', size: 44),
                      const OutlinedText('atrapa la lluvia de cachos', size: 18),
                      const SizedBox(height: 14),
                      const _CharacterPicker(),
                      const SizedBox(height: 16),
                      ListenableBuilder(
                        listenable: progress,
                        builder: (context, _) => LayoutBuilder(
                          builder: (context, c) => GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: c.maxWidth > 560 ? 5 : 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.85,
                            children: [
                              for (final l in levels)
                                _LevelCard(
                                  level: l,
                                  stars: progress.starsFor(l.number),
                                  unlocked: progress.isUnlocked(l.number),
                                  onTap: () => _play(context, l),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              const Positioned(left: 24, bottom: 18, child: IgnorePointer(child: _IdleCharacter())),
              const Positioned(top: 8, right: 8, child: _ProfileChip()),
              if (onlineEnabled)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Material(
                    color: Colors.white.o(0.92),
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: IconButton(
                      tooltip: 'Ranking',
                      icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFE9A400)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LeaderboardPage())),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.level, required this.stars, required this.unlocked, required this.onTap});

  final Level level;
  final int stars;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = level.theme;
    return Opacity(
      opacity: unlocked ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: unlocked ? onTap : null,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [t.skyTop, t.skyBottom]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: Colors.black.o(0.25), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              unlocked ? OutlinedText('${level.number}', size: 30) : const Icon(Icons.lock_rounded, color: Colors.white, size: 30),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < 3; i++)
                  Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 18, color: i < stars ? const Color(0xFFFFD84D) : Colors.white70),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Botón con el avatar y nombre del jugador; abre su perfil.
class _ProfileChip extends StatelessWidget {
  const _ProfileChip();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([session, selectedCharacter]),
        builder: (context, _) {
          final p = session.current;
          if (p == null) return const SizedBox.shrink();
          return Material(
            color: Colors.white.o(0.92),
            borderRadius: BorderRadius.circular(28),
            elevation: 3,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProfilePage())),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 14, 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  CharacterAvatar(p.character, width: 32),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Text(p.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1B3A7A))),
                  ),
                ]),
              ),
            ),
          );
        },
      );
}

/// Fila para elegir con qué personaje jugar.
class _CharacterPicker extends StatelessWidget {
  const _CharacterPicker();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Character>(
        valueListenable: selectedCharacter,
        builder: (context, current, _) => Column(children: [
          const OutlinedText('Elige tu personaje', size: 20),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final ch in Character.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _CharacterCard(character: ch, selected: ch == current, onTap: () => selectedCharacter.value = ch),
              ),
          ]),
        ]),
      );
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.character, required this.selected, required this.onTap});

  final Character character;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 92,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          decoration: BoxDecoration(
            color: Colors.white.o(selected ? 0.9 : 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? const Color(0xFFFFC233) : Colors.white, width: selected ? 4 : 2),
            boxShadow: [BoxShadow(color: Colors.black.o(0.25), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CustomPaint(size: const Size(60, 67), painter: character.painter()),
            const SizedBox(height: 4),
            Text(
              character.label,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: selected ? const Color(0xFF1B3A7A) : Colors.white),
            ),
          ]),
        ),
      );
}

/// El personaje elegido, respirando y parpadeando en el menú.
class _IdleCharacter extends StatefulWidget {
  const _IdleCharacter();

  @override
  State<_IdleCharacter> createState() => _IdleCharacterState();
}

class _IdleCharacterState extends State<_IdleCharacter> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 70))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([_c, selectedCharacter]),
        builder: (context, _) => CustomPaint(size: const Size(120, 134), painter: selectedCharacter.value.painter(walk: _c.value * 70, facing: 1)),
      );
}
