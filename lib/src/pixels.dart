library pixel_canvas.src.pixels;

import 'dart:math';
import 'dart:async';
import 'dart:convert';

/**
 * Model
 */
class Pixels {
  final List<List<Color>> _colors;
  final StreamController<ColorChangeEvent> _colorChangeController =
      new StreamController.broadcast();

  Pixels(int verticalPixels, int horizontalPixels) :
    this._colors = _createMatrix(verticalPixels, horizontalPixels);

  static List<List<Color>> _createMatrix(
      int verticalPixels, int horizontalPixels) {

    if (verticalPixels == null)
      throw new ArgumentError('Expected verticalPixels to be non-null');
    if (horizontalPixels == null)
      throw new ArgumentError('Expected horizontalPixels to be non-null');

    return new List<List<Color>>.generate(
          verticalPixels,
          (_) => new List<Color>.filled(horizontalPixels, new Color(null)));
  }

  factory Pixels.generate(
      int verticalPixels,
      int horizontalPixels,
      Color colorGenerator(int x, int y)) {
    var px = new Pixels(verticalPixels, horizontalPixels);
    px.eachColorWithIndex(
        (c, x, y) => px._set(x, y, colorGenerator(x, y)));
    return px;
  }

  factory Pixels.fromColorMatrix(
      List<List<Color>> colors, int horizontalPixels, int verticalPixels) {
    if (colors == null)
      throw new ArgumentError('Expected 1st arg to be non-null');

    return new Pixels.generate(verticalPixels, horizontalPixels, (int x, int y) {
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

  factory Pixels.fromJson(
      String json, int verticalPixels, int horizontalPixels) {
    if (json == null || json.trim().isEmpty) {
      return new Pixels(verticalPixels, horizontalPixels);
    }

    final List<List<String>> matrix = JSON.decode(json);
    if (matrix == null) {
      return new Pixels(verticalPixels, horizontalPixels);
    }

    final List<List<Color>> colorMatrix = matrix
        .map((row) => (row == null) ?
            null :
            row.map((c) => new Color(c)).toList(growable: true))
        .toList(growable: true);
    return new Pixels.fromColorMatrix(colorMatrix, horizontalPixels, verticalPixels);
  }

  factory Pixels.fromPixels(Pixels oldPixels, int verticalPixels, int horizontalPixels) {
    if (oldPixels == null)
      throw new ArgumentError('Expected 1st arg to be non-null');

    return new Pixels.fromColorMatrix(
        oldPixels._colors, horizontalPixels, verticalPixels);
  }

  //

  int get verticalPixels => _colors.length;
  int get horizontalPixels => _colors.first.length;
  Stream<ColorChangeEvent> get onColorChange => _colorChangeController.stream;
  Rectangle<int> get rectangle =>
      new Rectangle(0, 0, horizontalPixels - 1, verticalPixels - 1);

  void eachColorWithIndex(void f(String color, int x, int y)) {
    var maxColLength = horizontalPixels;
    var maxRowLength = verticalPixels;
    for(int i = 0; i < maxColLength; i++) {
      for(int j = 0; j < maxRowLength; j++) {
        f(get(i, j), i, j);
      }
    }
  }

  void setByPoint(Point<int> p, String colorString) =>
      set(p.x, p.y, colorString);
  void set(int x, int y, String colorString, [meta]) =>
      setColor(x, y, new Color(colorString, meta));
  void setColor(int x, int y, Color color) {
    String old = get(x, y);
    _set(x, y, color);
    notifyColorChange(x, y, old, color.color);
  }

  String getByPoint(Point<int> p) => get(p.x, p.y);
  String get(int x, int y) => getColor(x, y).color;
  Color getColor(int x, int y) => _colors[y][x];

  void _set(int x, int y, Color color) {
    _colors[y][x] = (color == null) ? new Color(null) : color;
  }

  void notifyColorChange(int x, int y, String oldColor, String newColor) {
    if (oldColor == newColor) return;
    _colorChangeController.add(new ColorChangeEvent(x, y, oldColor, newColor));
  }

  void movePixel(int x, int y, int deltaX, int deltaY, {bool copy: false}) {
    setColor(x + deltaX, y + deltaY, getColor(x, y));
    if (!copy) set(x, y, null);
  }
}

String normalizeColorString(String colorString) =>
    colorString == null ? null : colorString.trim().toLowerCase();

class Color {
  static final EMPTY_COLOR = new Color._(null);

  final String color;
  final meta;

  Color._(String color, [this.meta]): this.color = normalizeColorString(color);
  factory Color(String color, [meta]) =>
    (color == null && meta == null) ? EMPTY_COLOR : new Color._(color, meta);

  @override
  int get hashCode =>
      (color.hashCode * 31 + (meta.hashCode as int)) & 0x3fffffff;
  @override
  bool operator ==(o) => o is Color && o.color == color && o.meta == meta;
}

class ColorChangeEvent {
  final int x, y;
  final String oldColor, newColor;
  ColorChangeEvent(this.x, this.y, this.oldColor, this.newColor);
}
