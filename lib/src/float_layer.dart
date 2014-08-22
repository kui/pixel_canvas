library pixel_canvas.src.float_layer;

import 'dart:math';
import 'dart:collection';
import 'pixels.dart';
import 'outlinable.dart';

class FloatLayer extends Outlinable {
  Point<int> _grabbedPoint;
  Point<int> get grabbedPoint => _grabbedPoint;
  set grabbedPoint(Point<int> p) => _grabbedPoint = contains(p) ? p : null;

  Map<Point<int>, String> _colorMap;
  @override
  Set<Point<int>> get points => _colorMap.keys.toSet();

  FloatLayer._(this._colorMap);
  factory FloatLayer(Pixels pixels, Iterable<Point<int>> points) {
    final Map<Point<int>, String> m = new HashMap();
    points.forEach((p) {
      m[p] = pixels.getAsString(p.x, p.y);
    });
    return new FloatLayer._(m);
  }

  void move(int deltaX, int deltaY) {
    final delta = new Point(deltaX, deltaY);
    final Map<Point<int>, String> m = new HashMap();
    forEach((p, color) {
      m[p + delta] = color;
    });
    _colorMap = m;
    if (_grabbedPoint != null) _grabbedPoint = _grabbedPoint + delta;
  }

  void forEach(void f(Point<int> point, String color)) => _colorMap.forEach(f);
}
