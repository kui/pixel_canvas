library pixel_canvas.src.area;

import 'dart:math';
import 'dart:collection';
import '../pixels.dart';

const _LEFT = const Point(-1, 0);
const _RIGHT = const Point(1, 0);
const _UPPER = const Point(0, -1);
const _LOWER = const Point(0, 1);

List<Point<int>> _getArounds(Point<int> p) =>
  [p + _LEFT, p + _RIGHT, p + _UPPER, p + _LOWER];

abstract class Area {
  Pixels get pixels;
  Set<Point<int>> get points;

  Set<Line> get outline {
    final int width = pixels.horizontalPixels;
    final int height = pixels.verticalPixels;
    final Set<Point<int>> pts = new HashSet.from(points);

    return pts.map((p) {
      final lines = [];
      final upper = p + _UPPER, lower = p + _LOWER,
          left = p + _LEFT, right = p + _RIGHT;
      if (!pts.contains(upper)) lines.add(new HorizontalLine(p));
      if (!pts.contains(lower)) lines.add(new HorizontalLine(lower));
      if (!pts.contains(left))  lines.add(new VerticalLine(p));
      if (!pts.contains(right)) lines.add(new VerticalLine(right));
      return lines;
    }).expand((List<Line> lines) => lines).toSet();
  }
}

class UnshapedArea extends Area {
  final Pixels pixels;
  final Set<Point<int>> points;

  UnshapedArea._(this.pixels, this.points);

  factory UnshapedArea(Pixels pixels, Set<Point<int>> points) {
    final rect = pixels.rectangle;
    final p = points.where(rect.containsPoint).toSet();
    return new UnshapedArea._(pixels, p);
  }
}

class RectArea extends Area {
  final Pixels pixels;
  final Rectangle<int> rectangle;

  RectArea(this.pixels, int left, int top, int width, int height) :
    this.rectangle = new Rectangle(left, top, width, height);

  @override
  Set<Point<int>> get points {
    final Rectangle<int> intersects = rectangle.intersection(pixels.rectangle);
    if (intersects == null)
      return new HashSet();

    final base = intersects.topLeft;
    final width = intersects.width;
    final height = intersects.height;

    final points = new HashSet<Point<int>>();
    for (int x = 0; x <= width; x++) {
      for (int y = 0; y <= height; y++) {
        points.add(new Point<int>(base.x + x, base.y + y));
      }
    }
    return points;
  }

  @override
  Set<Line> get outline {
    final Rectangle<int> intersects = rectangle.intersection(pixels.rectangle);
    if (intersects == null)
      return new HashSet();

    final base = intersects.topLeft;
    final width = intersects.width;
    final height = intersects.height;

    final lines = new HashSet<Line>();

    // upper horizontal lines
    for(int x = 0; x <= width; x++)
      lines.add(new HorizontalLine(new Point<int>(base.x + x, base.y)));

    // lower horizontal lines
    for(int x = 0; x <= width; x++)
      lines.add(new HorizontalLine(new Point<int>(base.x + x, base.y + height + 1)));

    // left vertical lines
    for(int y = 0; y <= height; y++)
      lines.add(new VerticalLine(new Point<int>(base.x, base.y + y)));

    // right vertical lines
    for(int y = 0; y <= height; y++)
      lines.add(new VerticalLine(new Point<int>(base.x + width + 1, base.y + y)));

    return lines;
  }
}

class SameColorArea extends Area {
  final Pixels pixels;
  final String basicColor;

  SameColorArea(this.pixels, this.basicColor);

  @override
  Set<Point<int>> get points {
    final points = new HashSet();
    pixels.eachColorWithIndex((color, x, y) {
      if (color != basicColor) return;
      points.add(new Point<int>(x, y));
    });
    return points;
  }
}

class NeighborSameColorArea extends SameColorArea with Area {
  final Point<int> basicPoint;

  NeighborSameColorArea._(Pixels pixels, String basicColor, this.basicPoint):
    super(pixels, basicColor);
  factory NeighborSameColorArea(Pixels pixels, Point<int> basicPoint) =>
      new NeighborSameColorArea._(pixels, pixels.getByPoint(basicPoint), basicPoint);

  @override
  Iterable<Point<int>> get points {
    final sameColors = super.points;
    if (sameColors.isEmpty) return new HashSet();
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
      _getArounds(basic).where(targets.contains).toList(growable: false);
}

abstract class Line {
  Point<int> get base;
  int get _typeCode;
  @override
  int get hashCode => (_typeCode * 31 + base.hashCode) & 0x3fffffff;
  @override
  bool operator ==(o) =>
    o is Line && o._typeCode == _typeCode && o.base == base;
}
class HorizontalLine extends Line {
  final Point<int> base;
  final int _typeCode = 0;
  HorizontalLine(this.base);
  @override
  String toString() => 'HLine(${base.x}, ${base.y})';
}
class VerticalLine extends Line {
  final Point<int> base;
  final int _typeCode = 1;
  VerticalLine(this.base);
  @override
  String toString() => 'VLine(${base.x}, ${base.y})';
}
