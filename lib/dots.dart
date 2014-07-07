library dots_canvas;

import 'dot.dart';

/**
 * Model
 */
class Dots {
  List<List<Dot>> _matrix;

  Dots(int verticalDots, int horizontalDots) {
    if (verticalDots == null)
      throw new ArgumentError('Expected verticalDots to be non-null');
    if (horizontalDots == null)
      throw new ArgumentError('Expected horizontalDots to be non-null');

    _matrix =
        new List<List<Dot>>.generate(
            verticalDots,
            (i) => new List<Dot>.filled(horizontalDots, new Dot(null)));
  }

  factory Dots.fromDotMatrix(
      List<List<Dot>> m, int verticalDots, int horizontalDots) {
    var dots = new Dots(verticalDots, horizontalDots);

    for(int i = 0; i < m.length; i++) {
      var row = m[i];
      if (row == null) continue;
      for(int j = 0; j < row.length; j++) {
        var dot = row[j];
        dots._matrix[i][j] = dot;
      }
    }
    return dots;
  }

  factory Dots.fromStringMatrix(
      List<List<String>> m, int verticalDots, int horizontalDots) {
    if (m == null)
      throw new ArgumentError('Expected 1st arg to be non-null');

    var dotsMatrix = m.map((row) {
      if (row == null) return null;
      else return row.map((color) => new Dot(color)).toList(growable: false);
    }).toList(growable: false);
    return new Dots.fromDotMatrix(dotsMatrix, verticalDots, horizontalDots);
  }

  factory Dots.fromDots(Dots oldDots, int verticalDots, int horizontalDots) {
    if (oldDots == null)
      throw new ArgumentError('Expected 1st arg to be non-null');

    return new Dots.fromDotMatrix(
        oldDots._matrix, verticalDots, horizontalDots);
  }

  //

  int get verticalDots => _matrix.length;
  int get horizontalDots => _matrix.first.length;

  //

  void eachDotsWithIndex(void f(Dot dot, int x, int y)) {
    var maxColLength = horizontalDots;
    var maxRowLength = verticalDots;
    for(int i = 0; i < maxColLength; i++) {
      var row = _matrix[i];
      for(int j = 0; j < maxRowLength; j++) {
        print('$i, $j');
        var dot = row[j];
        f(dot, j, i);
      }
    }
  }

  void setDot(int x, int y, Dot d) {
    _matrix[y][x] = d;
  }
}
