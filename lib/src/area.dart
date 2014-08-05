library pixel_canvas.src.area;

import 'dart:math';
import '../pixels.dart';

class Area {
  final Pixels pixels;
  final Set<Point<int>> points;

  Area._(this.pixels, this.points);

  factory Area(Pixels pixels, Set<Point<int>> points) {
    final rect = pixels.rectangle;
    final p = points.where(rect.containsPoint).toSet();
    return new Area(pixels, p);
  }
}

class RectArea implements Area {
  final Pixels pixels;
  final Rectangle<int> rectangle;

  RectArea(this.pixels, int left, int top, int width, int height) :
    this.rectangle = new Rectangle(left, top, width, height);

  @override
  Set<Point<int>> get points {
    final Rectangle<int> intersects = rectangle.intersection(pixels.rectangle);
    if (intersects == null)
      return [].toSet();

    final topLeft = intersects.topLeft;
    final width = intersects.width;
    final height = intersects.height;

    final points = [];
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        points.add(new Point<int>(topLeft.x + x, topLeft.y + y));
      }
    }
    return points.toSet();
  }
}

class SameColorArea implements Area {
  final Pixels pixels;
  final String basicColor;

  SameColorArea(this.pixels, this.basicColor);

  @override
  Set<Point<int>> get points {
    final points = [];
    pixels.eachColorWithIndex((color, x, y) {
      if (color != basicColor) return;
      points.add(new Point<int>(x, y));
    });
    return points.toList(growable: false).toSet();
  }
}

class NeighborSameColorArea extends SameColorArea implements Area {
  static const LEFT = const Point(-1, 0);
  static const RIGHT = const Point(1, 0);
  static const UPPER = const Point(0, -1);
  static const LOWER = const Point(0, 1);

  final Point<int> basicPoint;

  NeighborSameColorArea._(Pixels pixels, String basicColor, this.basicPoint):
    super(pixels, basicColor);
  factory NeighborSameColorArea(Pixels pixels, Point<int> basicPoint) =>
      new NeighborSameColorArea._(pixels, pixels.getByPoint(basicPoint), basicPoint);

  @override
  Iterable<Point<int>> get points {
    final sameColors = super.points;
    if (sameColors.isEmpty) return [].toSet();
    return _getNeighborsWithPointers([basicPoint], sameColors).toSet();
  }

  Iterable<Point<int>> _getNeighborsWithPointers(List<Point<int>> basics, Iterable<Point<int>> targets) {
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

  List<Point<int>> _getNeiborsWithPointer(Point<int> basic, List<Point<int>> targets) =>
      [basic + LEFT, basic + RIGHT, basic + UPPER, basic + LOWER]
        .where(targets.contains).toList(growable: false);
}
