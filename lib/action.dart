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
  renderBeforeGrids(CanvasRenderingContext2D ctx) {}
  renderAfterGrids(CanvasRenderingContext2D ctx) {}
}

class DrawingAction extends Action {
  final PixelCanvasElement canvas;

  DrawingAction(this.canvas);

  @override
  handleMouseDown(Pixel pixel) {
    super.handleMouseDown(pixel);
    pixel.color = canvas.drawingColor;
  }

  @override
  handleMouseOver(Pixel pixel) {
    super.handleMouseOver(pixel);
    if (isMouseDown && pixel != null)
      pixel.color = canvas.drawingColor;
  }
}

abstract class OutlinableAction extends Action {
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
      ctx.moveTo(x, y);
      if (l is HorizontalLine) {
        ctx.lineTo(x + pixelSize, y);
      } else { // l is VerticalLine
        ctx.lineTo(x, y + pixelSize);
      }
    }
    ctx
      ..lineWidth = gridlineWidth + 1
      ..setLineDash([DASH_INTERVAL])

      ..strokeStyle = 'rgba(0,0,0,0.5)'
      ..lineDashOffset = 0
      ..stroke()

      ..strokeStyle = 'rgba(255,255,255,0.5)'
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

  factory PointsSelectionAction.addPoint(PointsSelectionAction action, Point<int> p) {
    final newPoints = new Set()
        ..addAll(action.bounds.points)
        ..add(p);
    return new PointsSelectionAction(
        action.canvas, new Bounds(action.canvas.pixels, newPoints))
      ..isMouseDown = action.isMouseDown;
  }

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

    canvas.currentAction = new PointsSelectionAction.addPoint(this, p);
  }

  _updateCursor(Pixel pixel) {
    if (pixel == null) return;

    final p = pixel.point;
    if (bounds.contains(p)) {
      canvas.setCanvasClass('selected');
    }
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

  factory SameColorsSelectionAction(PixelCanvasElement canvas, String color) {
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
    final margin = (pixelSize - size) / 2;
    final marginVector = new Point(margin, margin);
    floatLayer.forEach((point, color) {
      final offset = (point * pixelSize) + marginVector;
      ctx
          ..setLineDash([])
          ..lineWidth = 1

          ..beginPath()
          ..strokeStyle = 'rgba(0,0,0,0.5)'
          ..rect(offset.x, offset.y, size, size)
          ..stroke();

      if (color != null && color.isNotEmpty) {
        ctx
          ..fillStyle = color
          ..fill();
      } else {
        ctx
            // draw a white cross
            ..beginPath()
            ..strokeStyle = 'rgba(255,255,255,0.5)'
            ..moveTo(offset.x, offset.y)
            ..lineTo(offset.x + size, offset.y + size)
            ..moveTo(offset.x + size, offset.y)
            ..lineTo(offset.x, offset.y + size)
            ..stroke()

            // draw a black cross
            ..beginPath()
            ..strokeStyle = 'rgba(0,0,0,0.5)'
            ..moveTo(offset.x, offset.y + 1)
            ..lineTo(offset.x + size - 1, offset.y + size)
            ..moveTo(offset.x + size, offset.y + 1)
            ..lineTo(offset.x + 1, offset.y + size)
            ..stroke()
            ;
      }

      ctx
          ..beginPath()
          ..strokeStyle = 'rgba(255,255,255,0.5)'
          ..rect(offset.x + 1, offset.y + 1, size - 2, size - 2)
          ..stroke();
    });
  }
}
