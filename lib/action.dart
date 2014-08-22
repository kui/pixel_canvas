part of pixel_canvas.element;

abstract class Action {
  PixelCanvasElement get canvas;
  bool isMouseDown = false;

  handleMouseDown(Pixel pixel) {
    isMouseDown = true;
  }
  handleMouseUp(Pixel pixel) {
    isMouseDown = false;
  }
  handleMouseOver(Pixel pixel) {
    canvas.setCanvasClass('');
  }
  handleKeyDown(KeyboardEvent event) {}
  handleKeyUp(KeyboardEvent event) {}
  renderBeforeGrids(CanvasRenderingContext2D ctx) {}
  renderAfterGrids(CanvasRenderingContext2D ctx) {}
}

class DrawingAction extends Action {
  final PixelCanvasElement canvas;

  DrawingAction(this.canvas);

  @override
  handleMouseDown(Pixel pixel) {
    super.handleMouseDown(pixel);
    canvas.draw(pixel.x, pixel.y);
  }

  @override
  handleMouseOver(Pixel pixel) {
    super.handleMouseOver(pixel);
    if (isMouseDown && pixel != null)
      canvas.draw(pixel.x, pixel.y);
  }
}

abstract class OutlinableAction extends Action {
  static const LIGHTER_LINE_COLOR = 'rgba(0,0,0,0.5)';
  static const DARKER_LINE_COLOR = 'rgba(255,255,255,0.5)';

  static const DASH_INTERVAL = 6;

  Set<Line> get outline;
  PixelCanvasElement get canvas;

  @override
  renderAfterGrids(CanvasRenderingContext2D ctx) {
    final pixelSize = canvas.pixelSize;
    final gridlineWidth = canvas.gridlineWidth;

    ctx.beginPath();
    for(Line l in outline) {
      final p = l.base;
      final x = p.x * pixelSize;
      final y = p.y * pixelSize;
      if (l is HorizontalLine) {
        ctx
            ..moveTo(x, y + l.slip)
            ..lineTo(x + pixelSize, y + l.slip);
      } else { // l is VerticalLine
        ctx
            ..moveTo(x + l.slip, y)
            ..lineTo(x + l.slip, y + pixelSize);
      }
    }
    ctx
      ..lineWidth = gridlineWidth + 1
      ..setLineDash([DASH_INTERVAL])

      ..strokeStyle = DARKER_LINE_COLOR
      ..lineDashOffset = 0
      ..stroke()

      ..strokeStyle = LIGHTER_LINE_COLOR
      ..lineDashOffset = DASH_INTERVAL
      ..stroke();
  }
}

abstract class SelectionAction extends OutlinableAction {
  final PixelCanvasElement canvas;
  final Bounds bounds;
  get outline => bounds.outline;

  SelectionAction(this.canvas, this.bounds);
}

class PointsSelectionAction extends SelectionAction {
  PointsSelectionAction(PixelCanvasElement canvas, Bounds bounds) :
    super(canvas, bounds);

  @override
  handleMouseDown(Pixel pixel) {
    super.handleMouseDown(pixel);
    _updateCurrentAction(pixel);
  }

  @override
  handleMouseOver(Pixel pixel) {
    super.handleMouseOver(pixel);
    _updateCurrentAction(pixel);
    _updateCursor(pixel);
  }

  _updateCurrentAction(Pixel pixel) {
    if (!isMouseDown || pixel == null) return;

    final p = pixel.point;
    if (bounds.contains(p)) return;

    canvas.currentAction = _addPoint(p);
  }

  PointsSelectionAction _addPoint(Point<int> p) {
    final newPoints = new Set()
        ..addAll(bounds.points)
        ..add(p);
    return new PointsSelectionAction(
        canvas, new Bounds(canvas.pixels, newPoints))
      ..isMouseDown = isMouseDown;
  }

  _updateCursor(Pixel pixel) {
    if (pixel == null) return;

    final p = pixel.point;
    if (bounds.contains(p)) {
      canvas.setCanvasClass('selected');
    }
  }
}

class InstantSelectionAction extends PointsSelectionAction {
  bool isTargetKeyDown = false;
  final int targetKeyCode;

  InstantSelectionAction(PixelCanvasElement canvas, Bounds bounds, this.targetKeyCode) :
    super(canvas, bounds);

  bool isReady(KeyboardEvent event) =>
      targetKeyCode == event.which
      && canvas.currentAction is DrawingAction;

  @override
  handleKeyDown(KeyboardEvent event) {
    if (event.which == targetKeyCode)
      isTargetKeyDown = true;
  }

  @override
  handleKeyUp(KeyboardEvent event) {
    if (event.which == targetKeyCode)
      isTargetKeyDown = false;
  }

  @override
  _updateCurrentAction(Pixel pixel) {
    if (isTargetKeyDown) {
      super._updateCurrentAction(pixel);
    } else if (isMouseDown) {
      final drawing = new DrawingAction(canvas)
          ..isMouseDown = true;
      canvas.currentAction = drawing;
      drawing.handleMouseOver(pixel);
    }
  }

  @override
  InstantSelectionAction _addPoint(Point<int> p) {
    final newPoints = new Set()
        ..addAll(bounds.points)
        ..add(p);
    return new InstantSelectionAction(
        canvas, new Bounds(canvas.pixels, newPoints), targetKeyCode)
      ..isMouseDown = isMouseDown
      ..isTargetKeyDown = isTargetKeyDown;
  }
}

class RectangleSelectionAction extends SelectionAction {
  final Point<int> grabbedPoint;

  RectangleSelectionAction(PixelCanvasElement canvas, Bounds bounds, this.grabbedPoint) :
    super(canvas, bounds);

  @override
  handleMouseDown(Pixel pixel) {
    super.handleMouseDown(pixel);
    _updateCurrentAction(pixel, null);
    _updateCursor(pixel);
  }

  @override
  handleMouseOver(Pixel pixel) {
    super.handleMouseOver(pixel);
    _updateCurrentAction(pixel, grabbedPoint);
    _updateCursor(pixel);
  }

  @override
  handleMouseUp(Pixel pixel) {
    super.handleMouseUp(pixel);
    _updateCursor(pixel);
  }

  _updateCurrentAction(Pixel pixel, Point<int> _grabbedPoint) {
    if (!isMouseDown || pixel == null) return;

    final p = pixel.point;
    final rect = (_grabbedPoint == null) ?
        new Rectangle(p.x, p.y, 0, 0) :
        new Rectangle.fromPoints(p, _grabbedPoint);
    final gp = (_grabbedPoint == null) ? p : _grabbedPoint;
    final bounds = new Bounds.fromRectangle(canvas.pixels, rect);
    canvas.currentAction = new RectangleSelectionAction(canvas, bounds, gp)
      ..isMouseDown = isMouseDown;
  }

  void _updateCursor(Pixel pixel) {
    if (pixel == null) return;
    final p = pixel.point;
    if (isMouseDown) {
      canvas.setCanvasClass('grabbing');
    } else if (bounds.contains(p)) {
      canvas.setCanvasClass('selected');
    } else {
      canvas.setCanvasClass('grab');
    }
  }
}

abstract class OneShotClickSelectionAction extends SelectionAction {
  OneShotClickSelectionAction(PixelCanvasElement canvas, Bounds bounds) : super(canvas, bounds) {
    canvas.setCanvasClass('selected');
  }

  OneShotClickSelectionAction createFromPixel(Pixel pixel);

  @override
  handleMouseDown(Pixel pixel) {
    super.handleMouseDown(pixel);
    canvas.currentAction = createFromPixel(pixel)
      ..isMouseDown = isMouseDown;
  }

  @override
  handleMouseOver(Pixel pixel) {
    super.handleMouseOver(pixel);
    _updateCursor(pixel);
  }

  void _updateCursor(Pixel pixel) {
    if (pixel == null) return;
    final p = pixel.point;
    if (bounds.contains(p)) {
      canvas.setCanvasClass('selected');
    }
  }
}

class SameColorsSelectionAction extends OneShotClickSelectionAction {
  SameColorsSelectionAction._(PixelCanvasElement canvas, Bounds bounds):
    super(canvas, bounds);

  factory SameColorsSelectionAction(PixelCanvasElement canvas, Color color) {
    final b = new Bounds.sameColor(canvas.pixels, color);
    return new SameColorsSelectionAction._(canvas, b);
  }

  factory SameColorsSelectionAction.empty(PixelCanvasElement canvas) {
    final b = new Bounds(canvas.pixels, []);
    return new SameColorsSelectionAction._(canvas, b);
  }

  @override
  OneShotClickSelectionAction createFromPixel(Pixel pixel) =>
      new SameColorsSelectionAction(canvas, pixel.color);
}

class SameColorNeighborsSelectionAction extends OneShotClickSelectionAction {
  SameColorNeighborsSelectionAction._(PixelCanvasElement canvas, Bounds bounds) :
    super(canvas, bounds);

  factory SameColorNeighborsSelectionAction(PixelCanvasElement canvas, Point<int> point) {
    final b = new Bounds.sameColorNeighbors(canvas.pixels, point);
    return new SameColorNeighborsSelectionAction._(canvas, b);
  }

  factory SameColorNeighborsSelectionAction.empty(PixelCanvasElement canvas) {
    final b = new Bounds(canvas.pixels, []);
    return new SameColorNeighborsSelectionAction._(canvas, b);
  }

  @override
  OneShotClickSelectionAction createFromPixel(Pixel pixel) =>
      new SameColorNeighborsSelectionAction(canvas, pixel.point);
}

class ImmutableSelectionAction extends SelectionAction {
  ImmutableSelectionAction(PixelCanvasElement canvas, Bounds bounds):
    super(canvas, bounds);

  @override
  handleMouseOver(Pixel pixel) {
    super.handleMouseOver(pixel);

    if (pixel != null && bounds.contains(pixel.point)) {
      canvas.setCanvasClass('selected');
    }
  }
}

class FloatLayerAction extends OutlinableAction {
  static const FLOAT_PIXEL_SIZE_FACTOR = 0.85;

  final PixelCanvasElement canvas;
  final FloatLayer floatLayer;
  get outline => floatLayer.outline;

  FloatLayerAction(PixelCanvasElement canvas, Iterable<Point<int>> points):
    this.canvas = canvas,
    this.floatLayer = new FloatLayer(canvas.pixels, points);

  @override
  handleMouseDown(Pixel pixel) {
    super.handleMouseDown(pixel);

    final p = pixel.point;
    if (floatLayer.contains(p)) {
      floatLayer.grabbedPoint = p;
    }
    _updateCursor(pixel);
  }

  @override
  handleMouseUp(Pixel pixel) {
    super.handleMouseUp(pixel);
    floatLayer.grabbedPoint = null;
    _updateCursor(pixel);
  }

  @override
  handleMouseOver(Pixel pixel) {
    super.handleMouseOver(pixel);

    if (isMouseDown && floatLayer.grabbedPoint != null && pixel != null) {
      final delta = pixel.point - floatLayer.grabbedPoint;
      floatLayer.move(delta.x, delta.y);
      canvas.render();
    }

    _updateCursor(pixel);
  }

  void _updateCursor(Pixel pixel) {
    if (pixel == null) return;
    final p = pixel.point;
    if (floatLayer.contains(p)) {
      canvas.setCanvasClass(isMouseDown ? 'grabbing' : 'grab');
    }
  }

  @override
  renderBeforeGrids(CanvasRenderingContext2D ctx) {
    final pixelSize = canvas.pixelSize;
    final size = pixelSize * FLOAT_PIXEL_SIZE_FACTOR;
    final margin = ((pixelSize - size) / 2).round();
    final marginVector = new Point<int>(margin, margin);
    floatLayer.forEach((Point<num> point, Color color) {
      final offset = (point * pixelSize) + marginVector;
      ctx
          ..setLineDash([])
          ..lineWidth = 1

          ..beginPath()
          ..strokeStyle = OutlinableAction.LIGHTER_LINE_COLOR
          ..rect(offset.x, offset.y, size, size)
          ..stroke();

      if (color.isNotEmpty) {
        ctx
          ..fillStyle = color.color
          ..fill();
      } else {
        ctx
            // draw a white cross
            ..beginPath()
            ..strokeStyle = OutlinableAction.DARKER_LINE_COLOR
            ..moveTo(offset.x, offset.y)
            ..lineTo(offset.x + size, offset.y + size)
            ..moveTo(offset.x + size, offset.y)
            ..lineTo(offset.x, offset.y + size)
            ..stroke()

            // draw a black cross
            ..beginPath()
            ..strokeStyle = OutlinableAction.LIGHTER_LINE_COLOR
            ..moveTo(offset.x, offset.y + 1)
            ..lineTo(offset.x + size - 1, offset.y + size)
            ..moveTo(offset.x + size, offset.y + 1)
            ..lineTo(offset.x + 1, offset.y + size)
            ..stroke()
            ;
      }

      ctx
          ..beginPath()
          ..strokeStyle = OutlinableAction.DARKER_LINE_COLOR
          ..rect(offset.x + 1, offset.y + 1, size - 2, size - 2)
          ..stroke();
    });
  }
}
