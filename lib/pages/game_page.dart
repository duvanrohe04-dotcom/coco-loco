import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/color_ext.dart';
import '../core/progress.dart';
import '../core/sound.dart';
import '../core/synth.dart';
import '../game/game_engine.dart';
import '../game/item_painters.dart';
import '../game/level.dart';
import '../game/scene_painter.dart';
import '../ui/outlined_text.dart';
import '../ui/sound_controls.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.level});

  final Level level;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final GameEngine _engine = GameEngine(widget.level);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _recorded = false;
  bool _wasPaused = false;
  bool _wasSlow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine.onEvent = _onEvent;
    // Efectos listos antes de que empiece la cuenta atrás, y música de fondo mientras dura el nivel.
    Sound.instance.preload(Sfx.values.where((s) => s != Sfx.click));
    Sound.instance.startMusic(this);
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Sound.instance.stopMusic(this);
    _ticker.dispose();
    _engine.dispose();
    super.dispose();
  }

  /// Cada cosa que pasa en la partida suena y vibra (en la web y sin sonido no hace nada).
  void _onEvent(GameEvent e) {
    final sfx = switch (e) {
      GameEvent.catchCoco => Sfx.catchCoco,
      GameEvent.catchGolden => Sfx.golden,
      GameEvent.powerUp => Sfx.powerUp,
      GameEvent.blocked => Sfx.shieldBlock,
      GameEvent.hitRock => Sfx.hit,
      GameEvent.hitBomb => Sfx.bomb,
      GameEvent.miss => Sfx.miss,
      GameEvent.combo => Sfx.combo,
      GameEvent.tick => Sfx.tick,
      GameEvent.go => Sfx.go,
      GameEvent.win => Sfx.win,
      GameEvent.lose => Sfx.lose,
    };
    // Al terminar el nivel la música se apaga para que se oiga la fanfarria.
    if (e == GameEvent.win || e == GameEvent.lose) Sound.instance.stopMusic(this);
    Sound.instance.play(sfx);

    Future<void>? haptic;
    switch (e) {
      case GameEvent.catchCoco:
      case GameEvent.catchGolden:
      case GameEvent.powerUp:
      case GameEvent.combo:
      case GameEvent.blocked:
        haptic = HapticFeedback.selectionClick();
      case GameEvent.hitRock:
      case GameEvent.hitBomb:
        haptic = HapticFeedback.heavyImpact();
      case GameEvent.miss:
        haptic = HapticFeedback.lightImpact();
      case GameEvent.tick:
      case GameEvent.go:
      case GameEvent.win:
      case GameEvent.lose:
        break;
    }
    haptic?.catchError((Object _) {});
  }

  /// Si el jugador sale de la app o bloquea el teléfono, la partida y la música se pausan solas.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    Sound.instance.pauseMusic();
    if (_engine.status == GameStatus.playing) _engine.setPaused(true);
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero ? 0.0 : (now - _last).inMicroseconds / 1e6;
    _last = now;

    final kb = HardwareKeyboard.instance;
    final left = kb.isLogicalKeyPressed(LogicalKeyboardKey.arrowLeft) || kb.isLogicalKeyPressed(LogicalKeyboardKey.keyA);
    final right = kb.isLogicalKeyPressed(LogicalKeyboardKey.arrowRight) || kb.isLogicalKeyPressed(LogicalKeyboardKey.keyD);
    _engine.moveDir = (right ? 1 : 0) - (left ? 1 : 0);
    _engine.update(dt);

    // La música sigue a la partida: se pausa con ella y se hace lenta con la cámara lenta.
    if (_engine.paused != _wasPaused) {
      _wasPaused = _engine.paused;
      _wasPaused ? Sound.instance.pauseMusic() : Sound.instance.resumeMusic();
    }
    final slow = _engine.slowT > 0;
    if (slow != _wasSlow) {
      _wasSlow = slow;
      Sound.instance.setMusicSlow(slow);
    }

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
              IgnorePointer(child: ListenableBuilder(listenable: _engine, builder: (_, __) => _Intro(engine: _engine))),
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
        const SizedBox(height: 8),
        const SoundSwitch(),
        const SizedBox(height: 8),
        FilledButton(onPressed: () => _engine.setPaused(false), child: const Text('Continuar')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Salir al menú')),
      ]);

  Widget _endCard({required bool won}) {
    final level = widget.level;
    final next = level.number < levels.length ? levels[level.number] : null;
    final title = won ? (level.isBoss ? '¡Derrotaste a ${level.boss!.name}!' : '¡Nivel completado!') : 'Se acabaron las vidas';
    return _card([
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      if (won)
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Icon(i < _engine.stars ? Icons.star_rounded : Icons.star_outline_rounded, size: 44, color: const Color(0xFFFFB800)),
        ]),
      const SizedBox(height: 6),
      Text('Puntos: ${_engine.score}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      if (_engine.bestStreak >= 2) Text('🔥 Mejor racha: ${_engine.bestStreak}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      if (won && next == null) const Padding(padding: EdgeInsets.only(top: 8), child: Text('¡Completaste todos los niveles!', style: TextStyle(fontWeight: FontWeight.w800))),
      const SizedBox(height: 16),
      if (won && next != null) FilledButton(onPressed: () => _goTo(next), child: const Text('Siguiente nivel')),
      OutlinedButton(onPressed: () => _goTo(level), child: const Text('Reintentar')),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Menú')),
    ]);
  }
}

/// Barra superior: progreso (o vida del jefe), racha, vidas y poderes activos.
class _Hud extends StatelessWidget {
  const _Hud({required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    final level = engine.level;
    final boss = level.boss;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Material(
            color: Colors.black.o(0.3),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Pausa',
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
                  Expanded(child: Text(level.title, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                  if (engine.streak >= 2)
                    Transform.scale(
                      scale: 1 + 0.35 * engine.comboFlash,
                      child: Text(
                        '🔥 x${engine.streak}',
                        style: TextStyle(color: Color.lerp(Colors.white, const Color(0xFFFFD84D), engine.comboFlash), fontWeight: FontWeight.w900),
                      ),
                    ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  if (boss != null) const Text('👾', style: TextStyle(fontSize: 18)) else const CoconutIcon(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        // En un jefe la barra es SU vida: se vacía al atrapar cocos.
                        value: boss != null ? 1 - engine.progress : engine.progress,
                        minHeight: 10,
                        backgroundColor: Colors.white24,
                        color: boss != null ? const Color(0xFFFF5A5A) : const Color(0xFFFFD84D),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedText(boss != null ? '${(level.goal - engine.score).clamp(0, level.goal)}' : '${engine.score}/${level.goal}', size: 14),
                ]),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < engine.maxLives; i++)
            if (i < level.lives || i < engine.lives)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  i < engine.lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: const Color(0xFFFF4D6D),
                  size: 28,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black38)],
                ),
              ),
          const Spacer(),
          if (engine.shield) const _Effect(ItemKind.shield, 1),
          if (engine.magnetT > 0) _Effect(ItemKind.magnet, engine.magnetT / GameEngine.magnetTime),
          if (engine.slowT > 0) _Effect(ItemKind.slow, engine.slowT / GameEngine.slowTime),
          if (engine.doubleT > 0) _Effect(ItemKind.double, engine.doubleT / GameEngine.doubleTime),
        ]),
      ]),
    );
  }
}

/// Poder activo: su icono con un aro que se va vaciando.
class _Effect extends StatelessWidget {
  const _Effect(this.kind, this.fraction);

  final ItemKind kind;
  final double fraction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: Colors.black.o(0.3), shape: BoxShape.circle),
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(value: fraction.clamp(0.0, 1.0), strokeWidth: 3, color: Colors.white, backgroundColor: Colors.white24),
            ),
            ItemIcon(kind, size: 30),
          ]),
        ),
      );
}

/// Cuenta atrás con el título del nivel y, al principio, el consejo de la mecánica nueva.
class _Intro extends StatelessWidget {
  const _Intro({required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    final c = engine.countdown;
    final hint = engine.level.hint;
    if (c > 0) {
      final label = c > 1.8 ? '3' : (c > 1.0 ? '2' : (c > 0.4 ? '1' : '¡YA!'));
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          OutlinedText(engine.level.title, size: 20, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          OutlinedText(label, size: 92),
          if (hint != null) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 6, color: Colors.black87)]),
              ),
            ),
          ],
        ]),
      );
    }
    return const SizedBox.shrink();
  }
}
