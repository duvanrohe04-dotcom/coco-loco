import 'dart:math';

/// Palabras en inglés del juego: los "cocos" son verbos (hay que atraparlos) y las "rocas" son
/// palabras que NO son verbos (atraparlas quita una vida).
///
/// Reglas de las listas, para no confundir a quien aprende:
///  - Máximo 7 letras: la palabra tiene que caber en el radio de atrapar.
///  - Los verbos son verbos claros; las otras palabras no se usan como verbo en el inglés cotidiano
///    (por eso no hay "book", "water", "play" ni "run" en la lista de no-verbos).
///  - Hay tres niveles de dificultad: los primeros niveles usan solo las palabras más básicas.
class Words {
  Words._();

  /// Verbos por dificultad (índice 0 = básicos).
  static const List<List<String>> verbs = [
    ['eat', 'drink', 'sleep', 'jump', 'swim', 'sing', 'read', 'write', 'open', 'close', 'give', 'take', 'make', 'go', 'come', 'see', 'hear', 'sit', 'stand', 'laugh', 'wash'],
    ['listen', 'speak', 'buy', 'sell', 'learn', 'teach', 'climb', 'throw', 'catch', 'drive', 'ride', 'fly', 'cry', 'build', 'break', 'fix', 'clean', 'carry', 'bring', 'send'],
    ['meet', 'find', 'forget', 'choose', 'begin', 'finish', 'believe', 'borrow', 'lend', 'explain', 'arrive', 'invite', 'enjoy', 'travel', 'repeat', 'decide', 'notice', 'answer'],
  ];

  /// Palabras que NO son verbos (sustantivos, adjetivos, adverbios), por dificultad.
  static const List<List<String>> others = [
    ['apple', 'table', 'house', 'chair', 'dog', 'cat', 'blue', 'green', 'happy', 'big', 'small', 'tall', 'window', 'river', 'banana', 'yellow', 'bread', 'tree', 'bird', 'red'],
    ['pencil', 'candle', 'bridge', 'pillow', 'carpet', 'guitar', 'lemon', 'castle', 'rabbit', 'school', 'sofa', 'quick', 'heavy', 'funny', 'hungry', 'sunny', 'never', 'always', 'orange'],
    ['kitchen', 'quickly', 'beauty', 'whale', 'island', 'machine', 'thirsty', 'quietly', 'between', 'because', 'someone', 'purple', 'silver', 'bakery', 'doctor', 'forest'],
  ];

  /// Nivel de dificultad de las palabras (0..2) según el número de nivel del juego (1..20).
  static int tierFor(int levelNumber) => levelNumber <= 6 ? 0 : (levelNumber <= 13 ? 1 : 2);

  /// Un verbo al azar. Los niveles altos mezclan también los verbos fáciles.
  static String verb(Random rnd, int levelNumber) => _pick(verbs, rnd, levelNumber);

  /// Una palabra que no es verbo, al azar.
  static String other(Random rnd, int levelNumber) => _pick(others, rnd, levelNumber);

  static String _pick(List<List<String>> lists, Random rnd, int levelNumber) {
    // Con el nivel suben las probabilidades de las listas difíciles, sin dejar de mezclar las fáciles.
    final tier = tierFor(levelNumber);
    final r = rnd.nextDouble();
    final use = tier == 0 ? 0 : (tier == 1 ? (r < 0.5 ? 0 : 1) : (r < 0.25 ? 0 : (r < 0.55 ? 1 : 2)));
    final list = lists[use];
    return list[rnd.nextInt(list.length)];
  }
}
