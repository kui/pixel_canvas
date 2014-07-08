library dots_canvas;

/**
 * Model
 */
class Dots {
  final List<List<String>> _colors;

  Dots(int verticalDots, int horizontalDots) :
    this._colors = createMatrix(verticalDots, horizontalDots);

  static List<List<String>> createMatrix(
      int verticalDots, int horizontalDots) {
    if (verticalDots == null)
      throw new ArgumentError('Expected verticalDots to be non-null');
    if (horizontalDots == null)
      throw new ArgumentError('Expected horizontalDots to be non-null');
    return new List<List<String>>.generate(
          verticalDots,
          (i) => new List<String>.filled(horizontalDots, null));
  }

  factory Dots.generate(
      int verticalDots,
      int horizontalDots,
      String colorGenerator(int x, int y)) {
    var dots = new Dots(verticalDots, horizontalDots);
    dots.eachColorWithIndex((c, x, y) => dots.set(x, y, colorGenerator(x, y)));
    return dots;
  }

  factory Dots.fromColorMatrix(
      List<List<String>> colors, int verticalDots, int horizontalDots) {
    if (colors == null)
      throw new ArgumentError('Expected 1st arg to be non-null');

    return new Dots.generate(verticalDots, horizontalDots, (x, y) {
      if (y >= colors.length) return null;

      var row = colors[y];
      if (row == null) {
        return null;
      } else if(x >= row.length){
        return null;
      } else {
        return row[x];
      }
    });
  }

  factory Dots.fromDots(Dots oldDots, int verticalDots, int horizontalDots) {
    if (oldDots == null)
      throw new ArgumentError('Expected 1st arg to be non-null');

    return new Dots.fromColorMatrix(oldDots._colors, verticalDots, horizontalDots);
  }

  //

  int get verticalDots => _colors.length;
  int get horizontalDots => _colors.first.length;

  void eachColorWithIndex(void f(String color, int x, int y)) {
    var maxColLength = horizontalDots;
    var maxRowLength = verticalDots;
    for(int i = 0; i < maxColLength; i++) {
      for(int j = 0; j < maxRowLength; j++) {
        f(get(j, i), j, i);
      }
    }
  }

  String get(int x, int y) {
    return _colors[y][x];
  }

  void set(int x, int y, String color) {
    _colors[y][x] = color;
  }
}
