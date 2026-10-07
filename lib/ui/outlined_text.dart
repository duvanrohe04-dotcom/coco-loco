import 'package:flutter/material.dart';

/// Texto blanco con contorno, legible sobre cualquier fondo.
class OutlinedText extends StatelessWidget {
  const OutlinedText(this.text, {super.key, this.size = 24, this.outline = const Color(0xFF1C3F7A), this.textAlign});

  final String text;
  final double size;
  final Color outline;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: size, fontWeight: FontWeight.w900, letterSpacing: 1);
    return Stack(children: [
      Text(text, textAlign: textAlign, style: base.copyWith(foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = size / 5..strokeJoin = StrokeJoin.round..color = outline)),
      Text(text, textAlign: textAlign, style: base.copyWith(color: Colors.white)),
    ]);
  }
}
