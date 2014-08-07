library pixel_canvas.element;

import 'dart:html';
import 'dart:async';
import 'package:polymer/polymer.dart';
import 'pixels.dart';
import 'src/bounds.dart';
import 'src/editor.dart';
import 'src/outlinable.dart';

@CustomTag('pixel-canvas')
class PixelCanvasElement extends PolymerElement {

  static const CANVAS_FPS = 30;
  static final RENDERER_DELAY =
      new Duration(milliseconds: (1000/CANVAS_FPS).floor());
  static const LEFT_BUTTON = 1;
  static const DASH_INTERVAL = 6;

  @published
  int verticalPixels = 32;

  @published
  int horizontalPixels = 32;

  @published
  int pixelSize = 20;

  @published
  bool noGridlines = false;

  @published
  String gridlineColor = 'rgba(0, 0, 0, 0.2)';

  @published
  int gridlineWidth = 1;

  @published
  bool drawable = false;

  @published
  String drawingColor = 'black';

  @published
  Bounds selectedBounds;

  @published
  FloatLayer floatLayer;

  CanvasElement _canvas;
  Pixels _pixels;
  Editor _editor;
  Timer _rendererTimer;
  Pixel _mouseOveredPx = null;
  bool _isMouseDown = false;

  StreamController<PixelMouseEvent> _mouseMoveEventsController =
      new StreamController.broadcast();
  StreamController<PixelMouseEvent> _mouseOutEventsController =
      new StreamController.broadcast();
  StreamController<PixelMouseEvent> _mouseOverEventsController =
      new StreamController.broadcast();
  StreamController<PixelMouseEvent> _mouseDownEventsController =
      new StreamController.broadcast();
  StreamController<PixelMouseEvent> _mouseUpEventsController =
      new StreamController.broadcast();
  StreamController<PixelMouseEvent> _clickEventsController =
      new StreamController.broadcast();
  StreamController<PixelColorChangeEvent> _colorChangeEventsController =
      new StreamController.broadcast();
  StreamController<PixelCanvesEvent> _beforeRenderingEventController =
      new StreamController.broadcast();
  StreamController<PixelCanvesEvent> _afterRenderingEventController =
      new StreamController.broadcast();

  Stream<PixelMouseEvent> get onPixelMouseMove =>
      _mouseMoveEventsController.stream;
  Stream<PixelMouseEvent> get onPixelMouseOut =>
      _mouseOutEventsController.stream;
  Stream<PixelMouseEvent> get onPixelMouseOver =>
      _mouseOverEventsController.stream;
  Stream<PixelMouseEvent> get onPixelMouseDown =>
      _mouseDownEventsController.stream;
  Stream<PixelMouseEvent> get onPixelMouseUp =>
      _mouseUpEventsController.stream;
  Stream<PixelMouseEvent> get onPixelClick =>
      _clickEventsController.stream;
  Stream<PixelColorChangeEvent> get onPixelColorChange =>
      _colorChangeEventsController.stream;
  Stream<PixelCanvesEvent> get onBeforeRendering =>
      _beforeRenderingEventController.stream;
  Stream<PixelCanvesEvent> get onAfterRendering =>
      _afterRenderingEventController.stream;

  CanvasRenderingContext2D get _canvasContext =>
      (_canvas == null) ? null : _canvas.getContext('2d');

  PixelCanvasElement.created() : super.created();

  @override
  ready() {
    _canvas = shadowRoot.getElementsByTagName('canvas').first;
    _initCanvas();

    _pixels = new Pixels.fromJson(text, verticalPixels, horizontalPixels);
    _initPixels();

    render();
  }

  // property changed callbacks

  noGridlinesChanged() => render();
  pixelSizeChanged()   => render();

  verticalPixelsChanged()   => handleCanvasChange();
  horizontalPixelsChanged() => handleCanvasChange();

  handleCanvasChange() {
    if (verticalPixels == _pixels.verticalPixels &&
        horizontalPixels == _pixels.horizontalPixels)
      return;
    _pixels = new Pixels.fromPixels(_pixels, verticalPixels, horizontalPixels);
    _initPixels();

    render();
  }

  selectedBoundsChanged() => render();
  floatLayerChanged() => render();

  //

  void _initCanvas() {
    _initEvents();
  }

  void _initEvents() {
    _canvas
        ..onMouseMove.listen(_handleMouseMove)
        ..onMouseOut.listen(_handleMouseOut)
        ..onMouseOver.listen(_handleMouseOver)
        ..onClick.listen((MouseEvent event) =>
            _dispatchPixelMouseEvent(_clickEventsController, 'pixelclick', event,
                _mouseOveredPx))
        ..onMouseDown.listen(_handleMouseDown)
        ..onMouseUp.listen((MouseEvent event) =>
            _dispatchPixelMouseEvent(_mouseUpEventsController, 'pixelmouseup',
                event, _mouseOveredPx));
    document
        ..onMouseUp.listen((e) {
          if (_isLeftButton(e)) _isMouseDown = false;
        });
  }

  _handleMouseDown(MouseEvent event) {
    _dispatchPixelMouseEvent(_mouseDownEventsController,
        'pixelmousedown', event, _mouseOveredPx);

    _startDrawing(event);
  }

  _handleMouseOver(MouseEvent event) {
    var px = detectPixel(event);
    if (px != null) {
      _dispatchPixelMouseEvent(_mouseOverEventsController, 'pixelmouseover',
          event, px);
    }
    _mouseOveredPx = px;
    _updateCursor(px);
  }

  _handleMouseOut(MouseEvent event) {
    _dispatchPixelMouseEvent(_mouseOutEventsController, 'pixelmouseout',
        event, _mouseOveredPx);
    _mouseOveredPx = null;
  }

  _handleMouseMove(MouseEvent event) {
    var px = detectPixel(event);
    if (px == null) {
      _mouseOveredPx == null;
      return;
    }
    _dispatchPixelMouseEvent(_mouseMoveEventsController, 'pixelmousemove',
        event, px);

    if (px.equalsPoint(_mouseOveredPx)) {
      return;
    }

    if (_mouseOveredPx != null) {
      _dispatchPixelMouseEvent(_mouseOutEventsController, 'pixelmouseout',
          event, _mouseOveredPx);
    }

    _mouseOveredPx = px;
    _dispatchPixelMouseEvent(_mouseOverEventsController, 'pixelmouseover',
        event, px);
    _updateCursor(px);
    if (_isMouseDown) _draw();
  }

  void _updateCursor(Pixel px) {
    if (px != null && px.isSelected) {
      this.style.cursor = 'crosshair';
    } else {
      this.style.cursor = 'default';
    }
  }

  _dispatchPixelMouseEvent(StreamController c, String type, MouseEvent e, Pixel p) =>
      c.add(new PixelMouseEvent(type, this, p, e));

  void _startDrawing(MouseEvent e) {
    if (!_isLeftButton(e)) return;

    _isMouseDown = true;
    _draw();
  }

  void _draw() {
    if (!drawable || _mouseOveredPx == null) return;
    _mouseOveredPx.color = drawingColor;
    clearSelection();
  }

  static bool _isLeftButton(MouseEvent e) => LEFT_BUTTON == e.which;

  void _initPixels() {
    _pixels.onColorChange.listen((e) {
      var p = new Pixel(e.x, e.y, e.newColor, this);
      var change = new PixelColorChangeEvent('pixelcolorchange', this, p, e.oldColor);
      _colorChangeEventsController.add(change);
      render();
    });
    _editor = new Editor(_pixels);
  }

  void render() {
    if (_rendererTimer != null) return;

    _rendererTimer = new Timer(RENDERER_DELAY, () {
      renderImmediately();
    });
  }

  void renderImmediately() {
    _beforeRenderingEventController.add(
        new PixelCanvesEvent('beforerendering', this));

    final ctx = _canvasContext;
    _render(ctx);
    _rendererTimer = null;

    _afterRenderingEventController.add(
        new PixelCanvesEvent('afterrendering', this));
  }

  void _render(CanvasRenderingContext2D ctx) {
    _clear(ctx);

    _renderPixels(ctx);
    if (!noGridlines) {
      _renderGridlines(ctx);
    }
    if (selectedBounds != null) {
      _renderOutline(ctx, selectedBounds.outline);
    } else if (floatLayer != null) {
      _renderOutline(ctx, floatLayer.outline);
    }
  }

  void _renderGridlines(CanvasRenderingContext2D ctx) {
    ctx.beginPath();

    // horizontal gridlines
    for (int i = 0; i < verticalPixels + 1; i++) {
      var y = pixelSize * i;
      ctx
          ..moveTo(0, y)
          ..lineTo(_canvas.width, y);
    }

    // vertical gridlines
    for (int i = 0; i < horizontalPixels + 1; i++) {
      var x = pixelSize * i;
      ctx
          ..moveTo(x, 0)
          ..lineTo(x, _canvas.height);
    }

    ctx
        ..lineWidth = gridlineWidth
        ..strokeStyle = gridlineColor
        ..setLineDash([])
        ..stroke();
  }

  void _renderOutline(CanvasRenderingContext2D ctx, Set<Line> lines) {
    ctx.beginPath();
    for(Line l in lines) {
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

  void _renderPixels(CanvasRenderingContext2D ctx) {
    _pixels.eachColorWithIndex((color, x, y) {
      if (color == null || color.isEmpty) return;
      ctx
        ..fillStyle = color
        ..fillRect(x * pixelSize, y * pixelSize, pixelSize, pixelSize);
    });
  }

  void _clear(CanvasRenderingContext2D ctx) {
    ctx.clearRect(0, 0, _canvas.width, _canvas.height);
  }

  String getColor(int x, int y) => _pixels.get(x, y);
  String getColorByPoint(Point<int> p) => _pixels.getByPoint(p);
  void setColor(int x, int y, String color) => _pixels.set(x, y, color.trim());
  void setColorByPoint(Point<int> p, String color) =>
      _pixels.setByPoint(p, color.trim());

  Pixel detectPixel(MouseEvent event) {
    var rect = _canvas.getBoundingClientRect();
    var client = event.client;

    if (!rect.containsPoint(client)) {
      return null;
    }

    double eventX = client.x - rect.left;
    double eventY = client.y - rect.top;
    int x = (eventX/pixelSize).floor();
    int y = (eventY/pixelSize).floor();

    if (x >= horizontalPixels || y >= verticalPixels) {
      return null;
    }

    return new Pixel(x, y, getColor(x, y), this);
  }

  String toDataUrl([String type = 'image/png', num quality]) =>
    _canvas.toDataUrl(type, quality);

  void downloadAs(String name, [String type = 'image/png', num quality]) {
    AnchorElement anchor = new AnchorElement()
      ..href = toDataUrl(type, quality)
      ..download = name
      ..dispatchEvent(new MouseEvent('click'));
  }

  void select(Iterable<Point<int>> points) {
    selectedBounds = _editor.select(points);
  }
  void selectByRectangle(int top, int left, int width, int height) {
    selectedBounds = _editor.selectByRectangle(top, left, width, height);
  }
  void selectByColor(String color) {
    selectedBounds = _editor.selectByColor(color);
  }
  void selectByColorNeibors(Point<int> p) {
    selectedBounds = _editor.selectByColorNeighbors(p);
  }
  void clearSelection() {
    selectedBounds = null;
  }
  bool isSelectedPoint(Point<int> p) =>
      (selectedBounds != null) && selectedBounds.contains(p);
  void fillColor(String color) {
    if (selectedBounds == null) return;
    _editor.fillColor(selectedBounds, color);
  }
  bool isFloatedPoint(Point<int> p) =>
      (floatLayer != null) && floatLayer.contains(p);
}

class Pixel extends Point<int>{
  String _color;
  final PixelCanvasElement _canvas;

  Pixel(int x, int y, this._color, this._canvas): super(x, y);

  String get color => _color;
  void set color(String newColor) {
    _color = newColor;
    _canvas.setColor(x, y, newColor);
  }

  bool get isSelected => _canvas.isSelectedPoint(toPoint());
  bool get isFloated => _canvas.isSelectedPoint(toPoint());

  Point<int> toPoint() => new Point(x, y);
  bool equalsPoint(Pixel o) => super == o;
  @override
  String toString() => 'Pixel($x,$y,$color)';
  @override
  bool operator ==(o) =>
      o is Pixel && color == o.color && x == o.x && y == o.y;
  @override
  int get hashCode => (color.hashCode * 31 + super.hashCode) & 0x3fffffff;
}

class PixelCanvesEvent {
  final String type;
  final PixelCanvasElement canvas;
  PixelCanvesEvent(this.type, this.canvas);
}
class PixelEvent extends PixelCanvesEvent{
  final Pixel pixel;
  PixelEvent(String type, PixelCanvasElement c, this.pixel): super(type, c);
}
class PixelMouseEvent extends PixelEvent {
  final MouseEvent origin;
  PixelMouseEvent(String type, PixelCanvasElement c, Pixel p, this.origin):
    super(type, c, p);
}
class PixelColorChangeEvent extends PixelEvent {
  final String oldColor;
  PixelColorChangeEvent(String type, PixelCanvasElement c, Pixel p,
      this.oldColor): super(type, c, p);
}
