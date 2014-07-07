library dots_canvas;

/**
 * Model
 */
class Dot {
  String _color;

  Dot._raw();

  factory Dot(String color) {
    var d = new Dot._raw();
    d._color = color;
    return d;
  }

  String get color => _color;
}
