library pixel_canvas.src.bounds;

import 'dart:math';
import 'outlinable.dart';
import 'pixels.dart';

class Bounds extends Outlinable {
  final Set<Point<int>> points;

  Bounds._(this.points);

  factory Bounds(Pixels pixels, Iterable<Point<int>> points) {
    final rect = pixels.rectangle;
    final p = points.where(rect.containsPoint).toSet();
    return new Bounds._(p);
  }

  factory Bounds.fromRectangle(Pixels pixels, Rectangle rectangle) {
    final Rectangle<int> intersects = rectangle.intersection(pixels.rectangle);
    if (intersects == null)
      return new Bounds._(new Set());

    final base = intersects.topLeft;
    final width = intersects.width;
    final height = intersects.height;

    final points = new Set<Point<int>>();
    for (int x = 0; x <= width; x++) {
      for (int y = 0; y <= height; y++) {
        points.add(new Point<int>(base.x + x, base.y + y));
      }
    }
    return new Bounds._(points);
  }

  factory Bounds.sameColor(Pixels pixels, String basicColor) {
    final points = new Set();
    pixels.eachColorWithIndex((color, x, y) {
      if (color != basicColor) return;
      points.add(new Point<int>(x, y));
    });
    return new Bounds._(points);
  }

  factory Bounds.sameColorNeighbors(Pixels pixels, Point<int> basicPoint) {
    final sameColors =
        new Bounds.sameColor(pixels, pixels.getByPoint(basicPoint));
    if (sameColors.points.isEmpty) return sameColors;

    final points = _getNeighborsWithPointers([basicPoint], sameColors.points);
    return new Bounds._(points.toSet());
  }

  static Iterable<Point<int>> _getNeighborsWithPointers(List<Point<int>> basics, Iterable<Point<int>> targets) {
    final parentPoints = [];
    parentPoints.addAll(targets); // clone

    final neighbors = [];
    basics.forEach((b) {
      final n = _getNeiborsWithPointer(b, parentPoints);
      parentPoints.removeWhere(n.contains);
      neighbors.addAll(n);
    });

    if (neighbors.isEmpty) return basics;

    neighbors.addAll(basics);
    return _getNeighborsWithPointers(neighbors, parentPoints);
  }
  static Set<Point<int>> _getNeiborsWithPointer(Point<int> basic, List<Point<int>> targets) =>
      getArounds(basic).where(targets.contains).toSet();
}
