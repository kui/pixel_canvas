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

abstract class SelectionAction extends Action {
  final PixelCanvasElement _canvas;

  SelectionAction(this._canvas);
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
      ..strokeStyle = 'rgba(0,0,0,0.5)'
      ..setLineDash([DASH_INTERVAL])
      ..lineDashOffset = 0
      ..stroke()
      ..strokeStyle = 'rgba(255,255,255,0.5)'
      ..lineDashOffset = DASH_INTERVAL
      ..stroke();
  }
}

class SelectedAction extends OutlinableAction {
  final PixelCanvasElement canvas;
  final Bounds bounds;
  get outline => bounds.outline;

  SelectedAction(this.canvas, this.bounds);

  @override
  handleMouseOver(Pixel pixel) {
    super.handleMouseOver(pixel);

    if (pixel != null && bounds.contains(pixel.toPoint())) {
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

    final p = pixel.toPoint();
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
      final delta = pixel - floatLayer.grabbedPoint;
      floatLayer.move(delta.x, delta.y);
      canvas.render();
    }

    _updateCursor(pixel);
  }

  void _updateCursor(Pixel pixel) {
    if (pixel == null) return;
    final p = pixel.toPoint();
    if (floatLayer.contains(p)) {
      canvas.setCanvasClass(isMouseDown ? 'grabbing' : 'grab');
    }
  }

  @override
  renderBeforeGrids(CanvasRenderingContext2D ctx) {
    final pixelSize = canvas.pixelSize;
    final size = pixelSize * FLOAT_PIXEL_SIZE_FACTOR;
    final margin = (pixelSize - size) / 2;
    floatLayer.forEach((point, color) {
      if (color == null || color.isEmpty) return;
      ctx
        ..fillStyle = color
        ..fillRect(point.x * pixelSize + margin, point.y * pixelSize + margin, size, size);
    });
  }
}
