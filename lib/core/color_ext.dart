import 'dart:ui';

extension ColorOpacity on Color {
  /// Devuelve el color con la opacidad indicada (0..1).
  Color o(double opacity) => withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}
