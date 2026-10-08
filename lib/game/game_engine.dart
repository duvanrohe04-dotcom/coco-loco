import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'level.dart';

enum ItemKind { coconut, golden, rock }

enum GameStatus { playing, won, lost }

class Item {
  Item({required this.kind, required this.x, required this.y, required this.fallSpeed, required this.spin});

  static const double radius = 18;

  final ItemKind kind;
  final double fallSpeed;
  final double spin;
  double x, y, rot = 0;

  bool get isHazard => kind == ItemKind.rock;
  int get points => kind == ItemKind.golden ? 3 : 1;
}

class Particle {
  Particle(this.x, this.y, this.vx, this.vy, this.color, this.size);

  double x, y, vx, vy, life = 1;
  final Color color;
  final double size;
}

/// Lógica pura del juego (sin widgets): fácil de probar y de ajustar.
class GameEngine extends ChangeNotifier {
  GameEngine(this.level, {Random? random})
      : _rnd = random ?? Random(),
        lives = level.lives;

  static const double playerW = 110, playerH = 123;
  static const double groundHeight = 70; // alto de la arena en el pie de pantalla
  static const double groundMargin = 22; // distancia de los pies del personaje al borde inferior
  static const double walkSpeed = 460;

  final Level level;
  final Random _rnd;

  final List<Item> items = [];
  final List<Particle> particles = [];

  Size arena = Size.zero;
  GameStatus status = GameStatus.playing;
  bool paused = false;

  int score = 0;
  int lives;

  // Estado del personaje (lo usa el painter para animar).
  double playerX = 0;
  double facing = 1;
  double walkPhase = 0;
  double energy = 0; // 0 quieto .. 1 corriendo
  double happy = 0; // pulso al atrapar un coco
  double hurt = 0; // pulso al perder una vida
  double elapsed = 0;

  /// Racha: cocos seguidos sin fallar. Cada [streakBonusEvery] da +1 punto extra.
  static const int streakBonusEvery = 5;
  int streak = 0;
  int bestStreak = 0;
  double comboFlash = 0; // pulso al conseguir bonus

  /// -1 izquierda, 0 quieto, 1 derecha (teclado).
  double moveDir = 0;

  double _spawnTimer = 0;
  double _lastX = 0;

  double get playerTop => arena.height - groundMargin - playerH;
  double get groundTop => arena.height - groundHeight;

  /// Estrellas obtenidas al ganar según las vidas que quedan.
  int get stars => status != GameStatus.won ? 0 : (lives >= level.lives ? 3 : (lives == level.lives - 1 ? 2 : 1));

  void resize(Size size) {
    if (size == arena) return;
    final first = arena == Size.zero;
    arena = size;
    playerX = first ? size.width / 2 : _clampX(playerX);
    _lastX = playerX;
  }

  void dragBy(double dx) => playerX = _clampX(playerX + dx);

  void setPaused(bool value) {
    if (paused == value) return;
    paused = value;
    notifyListeners();
  }

  double _clampX(double x) => x.clamp(playerW / 2, max(playerW / 2, arena.width - playerW / 2)).toDouble();

  void update(double rawDt) {
    if (arena == Size.zero || paused || status != GameStatus.playing) return;
    final dt = min(rawDt, 0.05);
    if (dt <= 0) return;
    elapsed += dt;

    playerX = _clampX(playerX + moveDir * walkSpeed * dt);
    final moved = playerX - _lastX;
    _lastX = playerX;
    if (moved.abs() > 0.2) facing = moved.sign;
    energy += (min(1.0, moved.abs() / dt / 220) - energy) * min(1.0, dt * 10);
    walkPhase += dt * (1.5 + 9 * energy);
    happy = max(0, happy - dt * 2.5);
    hurt = max(0, hurt - dt * 2);
    comboFlash = max(0, comboFlash - dt * 1.5);

    _spawn(dt);
    _updateItems(dt);
    _updateParticles(dt);

    if (score >= level.goal) {
      status = GameStatus.won;
    } else if (lives <= 0) {
      status = GameStatus.lost;
    }
    notifyListeners();
  }

  void _spawn(double dt) {
    _spawnTimer += dt;
    if (_spawnTimer < level.spawnInterval) return;
    _spawnTimer = 0;
    final r = _rnd.nextDouble();
    final kind = r < level.rockChance
        ? ItemKind.rock
        : (r < level.rockChance + level.goldenChance ? ItemKind.golden : ItemKind.coconut);
    items.add(Item(
      kind: kind,
      x: Item.radius + _rnd.nextDouble() * (arena.width - Item.radius * 2),
      y: -Item.radius,
      fallSpeed: level.fallSpeed * (0.9 + _rnd.nextDouble() * 0.2),
      spin: (_rnd.nextDouble() - 0.5) * 6,
    ));
  }

  void _updateItems(double dt) {
    final catchZone = Rect.fromLTWH(playerX - playerW * 0.45, playerTop + playerH * 0.05, playerW * 0.9, playerH * 0.55)
        .inflate(Item.radius * 0.6);
    final floor = arena.height - groundMargin - 6;

    for (var i = items.length - 1; i >= 0; i--) {
      final it = items[i];
      it.y += it.fallSpeed * dt;
      it.rot += it.spin * dt;

      if (catchZone.contains(Offset(it.x, it.y))) {
        items.removeAt(i);
        if (it.isHazard) {
          _loseLife(it.x, it.y);
        } else {
          score += it.points;
          happy = 1;
          _burst(it.x, it.y, it.kind == ItemKind.golden ? const Color(0xFFFFD84D) : const Color(0xFFFFFFFF), 10);
          _registerCatch(it.x, it.y);
        }
      } else if (it.y >= floor) {
        items.removeAt(i);
        if (!it.isHazard) _loseLife(it.x, floor);
        _burst(it.x, floor, const Color(0xFFE8CB95), 6);
      }
    }
  }

  void _registerCatch(double x, double y) {
    streak++;
    bestStreak = max(bestStreak, streak);
    if (streak % streakBonusEvery == 0) {
      score += 1;
      comboFlash = 1;
      _burst(x, y, const Color(0xFFFFB800), 18);
    }
  }

  void _loseLife(double x, double y) {
    streak = 0;
    lives--;
    hurt = 1;
    _burst(x, y, const Color(0xFFFF5A5A), 10);
  }

  void _burst(double x, double y, Color color, int count) {
    for (var i = 0; i < count; i++) {
      final a = _rnd.nextDouble() * pi * 2;
      final v = 80 + _rnd.nextDouble() * 160;
      particles.add(Particle(x, y, cos(a) * v, sin(a) * v - 80, color, 2 + _rnd.nextDouble() * 3));
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
}
