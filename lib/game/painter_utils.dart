import 'package:flutter/material.dart';

/// Relleno + contorno grueso, el estilo "caricatura" común a los personajes.
void drawShape(Canvas canvas, Path path, Color fill, {Color ink = const Color(0xFF0B0B14), double width = 2.2}) {
  canvas.drawPath(path, Paint()..color = fill);
  canvas.drawPath(
    path,
    Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round,
  );
}

void drawOvalShape(Canvas canvas, Rect r, Color fill, {Color ink = const Color(0xFF0B0B14), double width = 2.2}) =>
    drawShape(canvas, Path()..addOval(r), fill, ink: ink, width: width);

void drawRRectShape(Canvas canvas, Rect r, double radius, Color fill, {Color ink = const Color(0xFF0B0B14), double width = 2.2}) =>
    drawShape(canvas, Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius))), fill, ink: ink, width: width);

Paint strokePaint(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;
