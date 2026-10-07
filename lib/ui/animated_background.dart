import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/background_painter.dart';
import '../game/level.dart';

/// Fondo animado reutilizable (menú). El [child] se dibuja encima.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key, required this.theme, this.child});

  final LevelTheme theme;
  final Widget? child;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => _time.value = d.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _BackgroundPainter(widget.theme, _time))),
        if (widget.child != null) Positioned.fill(child: widget.child!),
      ]);
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter(this.theme, this.time) : super(repaint: time);

  final LevelTheme theme;
  final ValueListenable<double> time;

  @override
  void paint(Canvas canvas, Size size) => paintBackground(canvas, size, theme, time.value);

  @override
  bool shouldRepaint(covariant _BackgroundPainter old) => old.theme != theme;
}
