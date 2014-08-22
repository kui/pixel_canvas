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
      } else if (x >= row.length){
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

  void eachColorWithIndex(void f(Color color, int x, int y)) {
    var maxColLength = horizontalPixels;
    var maxRowLength = verticalPixels;
    for(int i = 0; i < maxColLength; i++) {
      for(int j = 0; j < maxRowLength; j++) {
        f(get(i, j), i, j);
      }
    }
  }

  String getAsString(int x, int y) => get(x, y).color;
  Color get(int x, int y) => _colors[y][x];

  void setByString(int x, int y, String colorString, [meta]) =>
      set(x, y, new Color(colorString, meta));
  void set(int x, int y, Color color) {
    Color old = get(x, y);
    _set(x, y, color);
    _notifyColorChange(x, y, old, color);
  }

  void _set(int x, int y, Color color) {
    _colors[y][x] = (color == null) ? new Color(null) : color;
  }

  void _notifyColorChange(int x, int y, Color oldColor, Color newColor) {
    if (oldColor == newColor) return;
    _colorChangeController.add(new ColorChangeEvent(x, y, oldColor, newColor));
  }

  void movePixel(int x, int y, int deltaX, int deltaY, {bool copy: false}) {
    set(x + deltaX, y + deltaY, get(x, y));
    if (!copy) setByString(x, y, null);
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
  int get hashCode => color.hashCode;
  @override
  bool operator ==(o) => o is Color && o.color == color;

  bool get isEmpty => color == null || color.isEmpty;
  bool get isNotEmpty => color != null && color.isNotEmpty;

  @override
  String toString() => 'Color($color,$meta)';
}

class ColorChangeEvent {
  final int x, y;
  final Color oldColor, newColor;
  ColorChangeEvent(this.x, this.y, this.oldColor, this.newColor);
}
