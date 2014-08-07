library pixel_canvas.src.editor;

import 'dart:math';
import 'dart:collection';
import '../pixels.dart';
import 'bounds.dart';
import 'outlinable.dart';

class Editor {
  final Pixels pixels;

  Editor(this.pixels);

  Bounds select(Iterable<Point<int>> points) => new Bounds(pixels, points);
  Bounds selectByRectangle(int top, int left, int width, int height) =>
      new Bounds.fromRectangle(pixels, new Rectangle(left, top, width, height));
  Bounds selectByColor(String color) => new Bounds.sameColor(pixels, color);
  Bounds selectByColorNeighbors(Point<int> point) =>
      new Bounds.sameColorNeighbors(pixels, point);

  void fillColor(Bounds bounds, String color) {
    for (Point p in bounds.points)
      pixels.setByPoint(p, color);
  }
  FloatLayer copy(Bounds bounds) => new FloatLayer(pixels, bounds.points);
  FloatLayer cut(Bounds bounds) {
    final f = copy(bounds);
    fillColor(bounds, null);
    return f;
  }
  void paste(FloatLayer floatLayer) {
    floatLayer.forEach(pixels.setByPoint);
  }
}

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
      m[p] = pixels.getByPoint(p);
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

class SelectionChangeEvent {
  final Bounds oldBounds, newBounds;
  SelectionChangeEvent(this.oldBounds, this.newBounds);
}
