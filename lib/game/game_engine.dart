import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'level.dart';
import 'words.dart';

/// Objetos que vienen hacia el jugador. Los nombres `coconut` y `rock` se conservan (coco y roca).
enum ItemKind { coconut, golden, rock, bomb, heart, shield, magnet, slow, double }

enum GameStatus { playing, won, lost }

/// Cosas que pasan en la partida y que la pantalla convierte en sonido y vibración.
enum GameEvent { catchCoco, catchGolden, powerUp, blocked, hitRock, hitBomb, miss, combo, tick, go, win, lose }

/// Un objeto en el mundo 3D: [lane] es su carril (-1 izquierda .. 1 derecha) y [z] su distancia
/// (1 = en el horizonte, 0 = llega al jugador).
class Item {
  Item({required this.kind, required this.lane, this.z = 1, this.spin = 0, this.startHeight = 120, this.word});

  final ItemKind kind;

  /// Palabra en inglés que muestra el objeto: un verbo en los "cocos" (hay que atraparlo) o una
  /// palabra que NO es verbo en las "rocas" (atraparla quita una vida). Null en el resto de objetos.
  final String? word;
  double lane;
  double z;
  double rot = 0;
  final double spin;

  /// Altura inicial sobre el suelo (px); desciende hasta la altura de las manos al acercarse.
  final double startHeight;

  bool get isHazard => kind == ItemKind.rock || kind == ItemKind.bomb;
  bool get isPowerUp => kind == ItemKind.heart || kind == ItemKind.shield || kind == ItemKind.magnet || kind == ItemKind.slow || kind == ItemKind.double;
  int get points => kind == ItemKind.golden ? 3 : (kind == ItemKind.coconut ? 1 : 0);
}

class Particle {
  Particle(this.x, this.y, this.vx, this.vy, this.color, this.size);

  double x, y, vx, vy, life = 1;
  final Color color;
  final double size;
}

/// Texto flotante ("+1", "¡Escudo!"...) en pantalla.
class Popup {
  Popup(this.x, this.y, this.text, this.color);

  final double x;
  double y;
  final String text;
  final Color color;
  double life = 1;
}

class _Pending {
  _Pending(this.delay, this.lane, this.kind);

  double delay;
  final double lane;
  final ItemKind kind;
}

/// Lógica pura del juego (sin widgets): fácil de probar y de ajustar.
///
/// Vista pseudo-3D: el mundo tiene carriles (x en -1..1) y profundidad z (1 = horizonte, 0 = jugador).
/// La proyección convierte (carril, z) en píxeles con perspectiva ([groundPoint] y [scaleAt]).
class GameEngine extends ChangeNotifier {
  GameEngine(this.level, {Random? random, double startDelay = 2.6})
      : _rnd = random ?? Random(),
        lives = level.lives,
        countdown = startDelay;

  static const double playerW = 110, playerH = 123;
  static const double groundMargin = 22; // distancia de los pies del personaje al borde inferior
  static const double groundHeight = 70; // alto de la arena del fondo 2D del menú (no afecta al juego)
  static const double walkSpeed = 520;
  static const double perspective = 3.0; // intensidad de la perspectiva
  static const double catchRadius = 52; // radio de atrapar, en px a la altura del jugador
  static const double itemRadius = 22; // tamaño base de un objeto (px a la altura del jugador)
  static const double handHeight = 58; // altura (px) a la que llegan los objetos

  static const double magnetTime = 7, slowTime = 5, doubleTime = 8, stunTime = 0.8;
  static const double slowFactor = 0.55;

  // Medidas de los patrones, en píxeles a la altura del jugador.
  static const double zigzagAmpPx = 110, wallMinPx = 90, wallMaxPx = 140;
  static const double zigzagStep = 0.45; // segundos entre cocos de un zigzag
  static const double rowStep = 0.32; // segundos entre los verbos de una racha en línea

  final Level level;
  final Random _rnd;

  final List<Item> items = [];
  final List<Particle> particles = [];
  final List<Popup> popups = [];
  final List<_Pending> _queue = [];

  Size arena = Size.zero;
  GameStatus status = GameStatus.playing;
  bool paused = false;

  /// Segundos que faltan para empezar (cuenta atrás "3, 2, 1, ¡Ya!").
  double countdown;

  int score = 0;
  int lives;

  // Poderes activos.
  bool shield = false;
  double magnetT = 0, slowT = 0, doubleT = 0;
  double stun = 0; // aturdimiento tras una bomba (no puedes moverte)

  // Estado del personaje (lo usa el painter para animar).
  double playerX = 0;
  double facing = 1;
  double walkPhase = 0;
  double energy = 0; // 0 quieto .. 1 corriendo
  double happy = 0; // pulso al atrapar algo bueno
  double hurt = 0; // pulso al perder una vida
  double shake = 0; // temblor de pantalla (0..1)
  double elapsed = 0;

  /// Distancia recorrida por el mundo (para mover el suelo y las palmeras).
  double worldScroll = 0;

  /// Pulsos del jefe: [bossHit] al recibir un golpe, [bossAttack] al lanzar una pared.
  double bossHit = 0, bossAttack = 0;

  /// Racha: cocos seguidos sin fallar. Cada [streakBonusEvery] da +1 punto extra.
  static const int streakBonusEvery = 5;
  int streak = 0;
  int bestStreak = 0;
  double comboFlash = 0;

  /// -1 izquierda, 0 quieto, 1 derecha (teclado).
  double moveDir = 0;

  /// Aviso de cada [GameEvent] (la pantalla de juego lo usa para el sonido y la vibración).
  void Function(GameEvent event)? onEvent;

  double _spawnTimer = 0;
  double _lastX = 0;
  int _countStage = 4; // etapa de la cuenta atrás ya anunciada (3, 2, 1, 0 = ¡ya!)

  // ---- Geometría de la escena -------------------------------------------------

  int get maxLives => level.lives + 2;
  double get cx => arena.width / 2;
  double get horizonY => arena.height * 0.34;
  double get groundY => arena.height - groundMargin;
  double get playerTop => groundY - playerH;
  double get fieldHalfW => max(60.0, min(arena.width / 2 - playerW / 2, 320.0));
  double get playerLane => (playerX - cx) / fieldHalfW;
  double get timeScale => slowT > 0 ? slowFactor : 1;

  /// Escala de perspectiva a la profundidad [z] (1 cerca, ~0.25 en el horizonte lejano).
  double scaleAt(double z) => 1 / (1 + z.clamp(0.0, 4.0) * perspective);

  /// Punto del suelo (px) para un carril y una profundidad.
  Offset groundPoint(double lane, double z) {
    final s = scaleAt(z);
    return Offset(cx + lane * fieldHalfW * s, horizonY + (groundY - horizonY) * s);
  }

  /// Altura (px a escala 1) de un objeto: cae desde lo alto hasta las manos del jugador.
  double heightOf(Item it) => handHeight + (it.startHeight - handHeight) * pow(it.z.clamp(0.0, 1.0), 0.9);

  /// Progreso del nivel (0..1): en un jefe es su vida restante.
  double get progress => (score / level.goal).clamp(0.0, 1.0);

  /// Estrellas obtenidas al ganar según las vidas que quedan.
  int get stars => status != GameStatus.won ? 0 : (lives >= level.lives ? 3 : (lives == level.lives - 1 ? 2 : 1));

  void resize(Size size) {
    if (size == arena) return;
    final first = arena == Size.zero;
    arena = size;
    playerX = first ? size.width / 2 : _clampX(playerX);
    _lastX = playerX;
  }

  void dragBy(double dx) {
    if (stun > 0) return;
    playerX = _clampX(playerX + dx);
  }

  void setPaused(bool value) {
    if (paused == value) return;
    paused = value;
    notifyListeners();
  }

  double _clampX(double x) => x.clamp(cx - fieldHalfW, cx + fieldHalfW).toDouble();

  // ---- Bucle ------------------------------------------------------------------

  void update(double rawDt) {
    if (arena == Size.zero || paused || status != GameStatus.playing) return;
    final dt = min(rawDt, 0.05);
    if (dt <= 0) return;
    elapsed += dt;

    stun = max(0, stun - dt);
    final move = stun > 0 ? 0.0 : moveDir;
    playerX = _clampX(playerX + move * walkSpeed * dt);
    final moved = playerX - _lastX;
    _lastX = playerX;
    if (moved.abs() > 0.2) facing = moved.sign;
    energy += (min(1.0, moved.abs() / dt / 220) - energy) * min(1.0, dt * 10);
    walkPhase += dt * (1.5 + 9 * energy);
    happy = max(0, happy - dt * 2.5);
    hurt = max(0, hurt - dt * 2);
    shake = max(0, shake - dt * 2.4);
    comboFlash = max(0, comboFlash - dt * 1.5);
    bossHit = max(0, bossHit - dt * 3);
    bossAttack = max(0, bossAttack - dt * 1.6);
    _updateParticles(dt);
    _updatePopups(dt);

    if (countdown > 0) {
      countdown = max(0, countdown - dt);
      // Anuncia cada etapa de la cuenta atrás una sola vez: 3, 2, 1 y "¡ya!".
      final stage = countdown > 1.8 ? 3 : (countdown > 1.0 ? 2 : (countdown > 0.4 ? 1 : 0));
      if (stage < _countStage) {
        _countStage = stage;
        onEvent?.call(stage == 0 ? GameEvent.go : GameEvent.tick);
      }
      notifyListeners();
      return;
    }

    magnetT = max(0, magnetT - dt);
    slowT = max(0, slowT - dt);
    doubleT = max(0, doubleT - dt);

    final itemDt = dt * timeScale;
    worldScroll += itemDt / level.travelTime;
    _spawn(itemDt);
    _updateItems(itemDt);

    if (score >= level.goal) {
      status = GameStatus.won;
      onEvent?.call(GameEvent.win);
    } else if (lives <= 0) {
      status = GameStatus.lost;
      onEvent?.call(GameEvent.lose);
    }
    notifyListeners();
  }

  // ---- Oleadas ----------------------------------------------------------------
  //
  // Generador "justo": cada objeto nuevo aparece en un carril al que el jugador PUEDE llegar desde el
  // anterior (según el tiempo que hay entre ambos), los obstáculos nunca se colocan sobre el camino
  // hacia el siguiente premio y los patrones largos reservan su tiempo. Así una partida nunca exige
  // lo imposible, aunque el nivel sea rápido.

  /// Velocidad (px/s) que se supone que el jugador puede mover el dedo o el teclado al planificar.
  static const double reachSpeedPx = 460;

  /// Margen entre un obstáculo y un premio para que no se pisen (px).
  static const double safeGapPx = catchRadius + 26;

  double _lastGoodLane = 0; // carril del último premio que apareció
  double _sinceGood = 1; // segundos desde ese premio
  double _lastHazardLane = 0;
  double _sinceHazard = 9;

  /// Carriles que se alcanzan en [seconds] segundos (con un 20 % de holgura).
  double _reach(double seconds) => (reachSpeedPx * seconds * 0.8 / fieldHalfW).clamp(0.2, 2.0).toDouble();

  void _spawn(double dt) {
    _sinceGood += dt;
    _sinceHazard += dt;

    for (var i = _queue.length - 1; i >= 0; i--) {
      final p = _queue[i];
      p.delay -= dt;
      if (p.delay <= 0) {
        _queue.removeAt(i);
        _add(p.kind, p.lane);
      }
    }

    _spawnTimer += dt;
    if (_spawnTimer < level.spawnInterval) return;
    _spawnTimer = 0;

    final r = _rnd.nextDouble();
    var acc = level.wallChance;
    if (r < acc) return _wall();
    acc += level.zigzagChance;
    if (r < acc) return _zigzag();
    acc += level.rowChance;
    if (r < acc) return _row();
    _single();
  }

  void _add(ItemKind kind, double lane) {
    final item = Item(
      kind: kind,
      lane: lane.clamp(-0.95, 0.95).toDouble(),
      spin: (_rnd.nextDouble() - 0.5) * 6,
      startHeight: 90 + _rnd.nextDouble() * 120,
      word: switch (kind) {
        ItemKind.coconut || ItemKind.golden => Words.verb(_rnd, level.number),
        ItemKind.rock => Words.other(_rnd, level.number),
        _ => null,
      },
    );
    items.add(item);
    if (item.isHazard) {
      _lastHazardLane = item.lane;
      _sinceHazard = 0;
    } else if (item.points > 0) {
      _lastGoodLane = item.lane;
      _sinceGood = 0;
    }
  }

  /// Aleja [lane] de [other] hasta quedar a más de [safeGapPx] (hacia el lado con más espacio).
  double _pushAway(double lane, double other) {
    if ((lane - other).abs() * fieldHalfW >= safeGapPx) return lane;
    final gap = safeGapPx / fieldHalfW;
    final up = other + gap, down = other - gap;
    final preferUp = lane >= other;
    if (preferUp && up <= 0.92) return up;
    if (!preferUp && down >= -0.92) return down;
    return up <= 0.92 ? up : down;
  }

  /// Carril para un premio: alcanzable desde el anterior y lejos de un obstáculo reciente.
  double _goodLane() {
    final reach = _reach(max(_sinceGood, 0.35));
    var lane = (_lastGoodLane + (_rnd.nextDouble() * 2 - 1) * reach).clamp(-0.92, 0.92).toDouble();
    if (_sinceHazard < 0.8) lane = _pushAway(lane, _lastHazardLane);
    return lane;
  }

  /// Un objeto suelto: el tipo depende de las probabilidades del nivel.
  void _single() {
    final r = _rnd.nextDouble();
    var acc = level.bombChance;
    final ItemKind kind;
    if (r < acc) {
      kind = ItemKind.bomb;
    } else if (r < (acc += level.rockChance)) {
      kind = ItemKind.rock;
    } else if (r < (acc += level.powerChance)) {
      kind = _randomPower();
    } else if (r < (acc += level.goldenChance)) {
      kind = ItemKind.golden;
    } else {
      kind = ItemKind.coconut;
    }
    if (kind == ItemKind.bomb || kind == ItemKind.rock) {
      var lane = (_rnd.nextDouble() * 2 - 1) * 0.92;
      if (_sinceGood < 0.8) lane = _pushAway(lane, _lastGoodLane);
      _add(kind, lane);
    } else {
      _add(kind, _goodLane());
    }
  }

  ItemKind _randomPower() {
    final canHeart = lives < maxLives;
    final r = _rnd.nextDouble() * (canHeart ? 1.0 : 0.72);
    if (canHeart && r >= 0.72) return ItemKind.heart;
    if (r < 0.24) return ItemKind.shield;
    if (r < 0.46) return ItemKind.magnet;
    if (r < 0.60) return ItemKind.slow;
    return ItemKind.double;
  }

  // Las distancias de los patrones se definen en PÍXELES (no en carriles): así son igual de justas
  // en un móvil estrecho que en una pantalla ancha, donde un carril mide mucho más.

  /// Racha de tres verbos que bajan uno tras otro por el MISMO carril: se atrapan los tres sin moverse.
  /// (Antes iban lado a lado, pero las etiquetas con palabras son anchas y se montaban unas sobre otras.)
  void _row() {
    final c = _goodLane().clamp(-0.6, 0.6).toDouble();
    for (var i = 0; i < 3; i++) {
      _queue.add(_Pending(i * rowStep, c, ItemKind.coconut));
    }
    _lastGoodLane = c;
    _spawnTimer = -2 * rowStep; // nada más hasta que termine la racha
  }

  /// Cuatro cocos que alternan de lado: obliga a moverse rápido (pero se puede con el teclado).
  void _zigzag() {
    final amp = min(0.55, zigzagAmpPx / fieldHalfW);
    // Empieza por el lado más cercano a donde está el jugador.
    final start = _lastGoodLane >= 0 ? amp : -amp;
    for (var i = 0; i < 4; i++) {
      _queue.add(_Pending(i * zigzagStep, i.isEven ? start : -start, i == 3 ? ItemKind.golden : ItemKind.coconut));
    }
    _spawnTimer = -3 * zigzagStep; // nada más hasta que termine la figura
  }

  /// Carriles de una pared: separados entre 90 y 140 px (los obstáculos quedan fuera del radio de atrapar).
  List<double> get _wallLanes {
    final d = min(max(0.7 * fieldHalfW, wallMinPx), wallMaxPx) / fieldHalfW;
    return [-d, 0, d];
  }

  /// Pared de obstáculos con un hueco en el que hay premio (siempre al alcance del jugador).
  void _wall() {
    final lanes = _wallLanes;
    final reach = _reach(max(_sinceGood, 0.5));
    final reachable = [for (var i = 0; i < lanes.length; i++) if ((lanes[i] - _lastGoodLane).abs() <= reach) i];
    final gap = reachable.isNotEmpty
        ? reachable[_rnd.nextInt(reachable.length)]
        : [0, 1, 2].reduce((a, b) => (lanes[a] - _lastGoodLane).abs() <= (lanes[b] - _lastGoodLane).abs() ? a : b);
    for (var i = 0; i < lanes.length; i++) {
      if (i == gap) continue;
      _add(level.bombChance > 0 && _rnd.nextDouble() < 0.25 ? ItemKind.bomb : ItemKind.rock, lanes[i]);
    }
    _add(_rnd.nextDouble() < 0.4 ? ItemKind.golden : ItemKind.coconut, lanes[gap]);
    bossAttack = 1;
    _spawnTimer = -level.spawnInterval * 0.5; // respiro tras la pared
  }

  // ---- Objetos ----------------------------------------------------------------

  void _updateItems(double dt) {
    for (var i = items.length - 1; i >= 0; i--) {
      final it = items[i];
      it.z -= dt / level.travelTime;
      it.rot += it.spin * dt;

      // El imán atrae lo bueno hacia el carril del jugador.
      if (magnetT > 0 && !it.isHazard && it.z < 0.9) {
        it.lane += (playerLane - it.lane) * min(1.0, dt * 2.6);
      }

      if (it.z <= 0) {
        items.removeAt(i);
        _arrive(it);
      }
    }
  }

  Offset get _chest => Offset(playerX, groundY - playerH * 0.55);

  /// Un objeto llega a la altura del jugador: ¿lo atrapa o pasa de largo?
  void _arrive(Item it) {
    final dx = (it.lane * fieldHalfW - (playerX - cx)).abs();
    final caught = dx <= catchRadius;
    final at = _chest;

    if (!caught) {
      if (it.points > 0) {
        _loseLife(at, 'Perdido', GameEvent.miss);
      } else if (it.isHazard) {
        popups.add(Popup(cx + it.lane * fieldHalfW, groundY - 70, '¡Esquivada!', const Color(0xFF9DF0C0)));
      }
      return;
    }

    switch (it.kind) {
      case ItemKind.coconut:
      case ItemKind.golden:
        final gained = it.points * (doubleT > 0 ? 2 : 1);
        score += gained;
        happy = 1;
        bossHit = 1;
        _burst(at, it.kind == ItemKind.golden ? const Color(0xFFFFD84D) : const Color(0xFFFFFFFF), 10);
        popups.add(Popup(at.dx, at.dy - 40, '+$gained', it.kind == ItemKind.golden ? const Color(0xFFFFD84D) : const Color(0xFFFFFFFF)));
        onEvent?.call(it.kind == ItemKind.golden ? GameEvent.catchGolden : GameEvent.catchCoco);
        _registerCatch(at);
      case ItemKind.rock:
        _hazardHit(at, stunned: false);
      case ItemKind.bomb:
        _hazardHit(at, stunned: true);
      case ItemKind.heart:
        if (lives < maxLives) lives++;
        _powerPopup(at, '+1 vida', const Color(0xFFFF6B8A));
      case ItemKind.shield:
        shield = true;
        _powerPopup(at, '¡Escudo!', const Color(0xFF7FD4FF));
      case ItemKind.magnet:
        magnetT = magnetTime;
        _powerPopup(at, '¡Imán!', const Color(0xFFFF7A7A));
      case ItemKind.slow:
        slowT = slowTime;
        _powerPopup(at, 'Cámara lenta', const Color(0xFFB9A6FF));
      case ItemKind.double:
        doubleT = doubleTime;
        _powerPopup(at, 'Puntos x2', const Color(0xFFFFD84D));
    }
  }

  void _powerPopup(Offset at, String text, Color color) {
    happy = 1;
    _burst(at, color, 14);
    popups.add(Popup(at.dx, at.dy - 40, text, color));
    onEvent?.call(GameEvent.powerUp);
  }

  void _hazardHit(Offset at, {required bool stunned}) {
    if (shield) {
      shield = false;
      _burst(at, const Color(0xFF7FD4FF), 16);
      popups.add(Popup(at.dx, at.dy - 40, '¡Bloqueado!', const Color(0xFF7FD4FF)));
      onEvent?.call(GameEvent.blocked);
      return;
    }
    if (stunned) stun = stunTime;
    _loseLife(at, stunned ? '¡Bomba!' : '¡No es verbo!', stunned ? GameEvent.hitBomb : GameEvent.hitRock);
    shake = stunned ? 1 : 0.6;
  }

  void _registerCatch(Offset at) {
    streak++;
    bestStreak = max(bestStreak, streak);
    if (streak % streakBonusEvery == 0) {
      score += doubleT > 0 ? 2 : 1;
      comboFlash = 1;
      _burst(at, const Color(0xFFFFB800), 18);
      popups.add(Popup(at.dx, at.dy - 70, '¡Racha x$streak!', const Color(0xFFFFB800)));
      onEvent?.call(GameEvent.combo);
    }
  }

  void _loseLife(Offset at, String text, GameEvent event) {
    streak = 0;
    lives--;
    hurt = 1;
    shake = max(shake, 0.5);
    _burst(at, const Color(0xFFFF5A5A), 10);
    popups.add(Popup(at.dx, at.dy - 40, text, const Color(0xFFFF6B6B)));
    onEvent?.call(event);
  }

  // ---- Efectos ----------------------------------------------------------------

  void _burst(Offset at, Color color, int count) {
    for (var i = 0; i < count; i++) {
      final a = _rnd.nextDouble() * pi * 2;
      final v = 80 + _rnd.nextDouble() * 160;
      particles.add(Particle(at.dx, at.dy, cos(a) * v, sin(a) * v - 80, color, 2 + _rnd.nextDouble() * 3));
    }
  }

  void _updateParticles(double dt) {
    for (var i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.life -= dt * 1.8;
      if (p.life <= 0) {
        particles.removeAt(i);
        continue;
      }
      p.vy += 420 * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
    }
  }

  void _updatePopups(double dt) {
    for (var i = popups.length - 1; i >= 0; i--) {
      final p = popups[i];
      p.life -= dt * 1.1;
      p.y -= 55 * dt;
      if (p.life <= 0) popups.removeAt(i);
    }
  }
}
