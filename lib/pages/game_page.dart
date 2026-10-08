import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/color_ext.dart';
import '../core/progress.dart';
import '../game/game_engine.dart';
import '../game/item_painters.dart';
import '../game/level.dart';
import '../game/scene_painter.dart';
import '../ui/outlined_text.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.level});

  final Level level;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  late final GameEngine _engine = GameEngine(widget.level);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _engine.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero ? 0.0 : (now - _last).inMicroseconds / 1e6;
    _last = now;

    final kb = HardwareKeyboard.instance;
    final left = kb.isLogicalKeyPressed(LogicalKeyboardKey.arrowLeft) || kb.isLogicalKeyPressed(LogicalKeyboardKey.keyA);
    final right = kb.isLogicalKeyPressed(LogicalKeyboardKey.arrowRight) || kb.isLogicalKeyPressed(LogicalKeyboardKey.keyD);
    _engine.moveDir = (right ? 1 : 0) - (left ? 1 : 0);
    _engine.update(dt);

    if (!_recorded && _engine.status == GameStatus.won) {
      _recorded = true;
      progress.record(widget.level, _engine.stars, streak: _engine.bestStreak);
    }
  }

  void _goTo(Level level) =>
      Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => GamePage(level: level)));

  @override
  Widget build(BuildContext context) => Scaffold(
        body: LayoutBuilder(builder: (context, c) {
          _engine.resize(Size(c.maxWidth, c.maxHeight));
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) => _engine.dragBy(d.delta.dx),
            child: Stack(fit: StackFit.expand, children: [
              Positioned.fill(child: CustomPaint(painter: ScenePainter(_engine))),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ListenableBuilder(listenable: _engine, builder: (_, __) => _Hud(engine: _engine)),
                ),
              ),
              ListenableBuilder(listenable: _engine, builder: (_, __) => _overlay()),
            ]),
          );
        }),
      );

  Widget _overlay() {
    if (_engine.status == GameStatus.won) return _endCard(won: true);
    if (_engine.status == GameStatus.lost) return _endCard(won: false);
    if (_engine.paused) return _pauseCard();
    return const SizedBox.shrink();
  }

  Widget _card(List<Widget> children) => Positioned.fill(
        child: ColoredBox(
          color: Colors.black.o(0.55),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white.o(0.95), borderRadius: BorderRadius.circular(24)),
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      );

  Widget _pauseCard() => _card([
        const Text('Pausa', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => _engine.setPaused(false), child: const Text('Continuar')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Salir al menú')),
      ]);

  Widget _endCard({required bool won}) {
    final next = widget.level.number < levels.length ? levels[widget.level.number] : null;
    return _card([
      Text(won ? '¡Nivel completado!' : 'Se acabaron las vidas', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      if (won)
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Icon(i < _engine.stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 44, color: const Color(0xFFFFB800)),
        ]),
      if (_engine.bestStreak >= 2) ...[
        const SizedBox(height: 8),
        Text('🔥 Mejor racha: ${_engine.bestStreak}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
      const SizedBox(height: 16),
      if (won && next != null) FilledButton(onPressed: () => _goTo(next), child: const Text('Siguiente nivel')),
      OutlinedButton(onPressed: () => _goTo(widget.level), child: const Text('Reintentar')),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Menú')),
    ]);
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    final level = engine.level;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Material(
          color: Colors.black.o(0.3),
          shape: const CircleBorder(),
          child: IconButton(
            icon: const Icon(Icons.pause_rounded, color: Colors.white),
            onPressed: () => engine.setPaused(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.black.o(0.3), borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: Text(level.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                if (engine.streak >= 2)
                  Transform.scale(
                    scale: 1 + 0.35 * engine.comboFlash,
                    child: Text(
                      '🔥 Racha x${engine.streak}',
                      style: TextStyle(color: Color.lerp(Colors.white, const Color(0xFFFFD84D), engine.comboFlash), fontWeight: FontWeight.w900),
                    ),
                  ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const HornIcon(),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (engine.score / level.goal).clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.white24,
                      color: const Color(0xFFFFD84D),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedText('${engine.score}/${level.goal}', size: 14),
              ]),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        Row(children: [
          for (var i = 0; i < level.lives; i++)
            Icon(i < engine.lives ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: const Color(0xFFFF4D6D), size: 28),
        ]),
      ]),
    );
  }
}
