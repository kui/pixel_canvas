library pixel_canvas.element;

import 'dart:html';
import 'dart:async';
import 'package:polymer/polymer.dart';
import 'src/pixels.dart';
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
  static const FLOAT_PIXEL_SIZE_FACTOR = 0.85;

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

  @published
  Pixels pixels;

  CanvasElement _canvas;
  Editor _editor;
  Timer _rendererTimer;
  bool _isMouseDown = false;
  Pixel _mouseOveredPx;

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

    pixels = new Pixels.fromJson(text, verticalPixels, horizontalPixels);
    _initPixels();

    render();
  }

  // property changed callbacks

  noGridlinesChanged() => render();
  pixelSizeChanged()   => render();

  verticalPixelsChanged()   => handleCanvasChange();
  horizontalPixelsChanged() => handleCanvasChange();

  handleCanvasChange() {
    if (verticalPixels == pixels.verticalPixels &&
        horizontalPixels == pixels.horizontalPixels)
      return;

    delete();
    clearSelection();

    pixels = new Pixels.fromPixels(pixels, verticalPixels, horizontalPixels);
    _initPixels();
  }

  pixelsChanged() {
    render();
  }

  selectedBoundsChanged() {
    if (selectedBounds != null) delete();
    render();
  }
  floatLayerChanged() {
    if (floatLayer != null) clearSelection();
    render();
  }

  void _mouseOveredPxChange(Pixel oldPixel, Pixel newPixel, MouseEvent event) {
    if (newPixel != null)
      _dispatchPixelMouseEvent(_mouseOverEventsController, 'mouseover',
          event, newPixel);

    if (oldPixel != null)
      _dispatchPixelMouseEvent(_mouseOutEventsController, 'mouseout',
          event, oldPixel);

    if (_isMouseDown && newPixel != null) {
      if (floatLayer != null) {
        final _old = (oldPixel == null) ?
            new Pixel.fromPoint(floatLayer.grabbedPoint, this) : oldPixel;
        if (_old.isFloated) {
          final delta = newPixel - _old;
          floatLayer.move(delta.x, delta.y);
          render();
        }
      } else {
        _draw(newPixel);
      }
    }
    _updateClassName();
  }

  //

  void _initCanvas() {
    _initEvents();
  }

  void _initEvents() {
    _canvas
        ..onMouseMove.listen(_updateMouseOveredPx)
        ..onMouseOut.listen(_updateMouseOveredPx)
        ..onMouseOver.listen(_updateMouseOveredPx)
        ..onMouseDown.listen(_handleMouseDown)
        ..onClick.listen((MouseEvent event) =>
            _dispatchPixelMouseEvent(_clickEventsController, 'pixelclick',
                event, _mouseOveredPx))
        ..onMouseUp.listen(_handleMouseUp);
    document
        ..onMouseUp.listen(_handleGlobalMouseUp);
  }

  _handleGlobalMouseUp(MouseEvent e) {
    if (_isLeftButton(e)) _isMouseDown = false;
    _updateClassName();
    if (floatLayer != null) floatLayer.grabbedPoint = null;
  }

  _handleMouseUp(MouseEvent event) {
    _dispatchPixelMouseEvent(_mouseUpEventsController, 'pixelmouseup',
        event, _mouseOveredPx);
  }

  _updateMouseOveredPx(MouseEvent mouseEvent) {
    final newPx = detectPixel(mouseEvent);
    final oldPx = _mouseOveredPx;
    if (oldPx == newPx) return;
    if (oldPx != null && oldPx.equalsPoint(newPx)) return;
    _mouseOveredPx = newPx;
    _mouseOveredPxChange(oldPx, newPx, mouseEvent);
  }

  _handleMouseDown(MouseEvent event) {
    _dispatchPixelMouseEvent(_mouseDownEventsController,
        'pixelmousedown', event, _mouseOveredPx);

    _startDragging(event);
    _updateClassName();
  }

  _updateClassName() {
    final px = _mouseOveredPx;
    if (px == null) {
      _canvas.className = '';
    } else if (px.isSelected) {
      _canvas.className = 'selected';
    } else if (px.isFloated) {
      _canvas.className = _isMouseDown ? 'grabbing' : 'grab';
    } else {
      _canvas.className = '';
    }
  }

  _dispatchPixelMouseEvent(StreamController c, String type, MouseEvent e, Pixel p) =>
      c.add(new PixelMouseEvent(type, this, p, e));

  void _startDragging(MouseEvent e) {
    if (!_isLeftButton(e)) return;

    _isMouseDown = true;
    if (_mouseOveredPx.isFloated) {
      floatLayer.grabbedPoint = _mouseOveredPx.toPoint();
    } else {
      _draw(_mouseOveredPx);
    }
  }

  void _draw(Pixel px) {
    if (px == null || floatLayer != null) return;
    px.color = drawingColor;
    clearSelection();
  }

  static bool _isLeftButton(MouseEvent e) => LEFT_BUTTON == e.which;

  void _initPixels() {
    pixels.onColorChange.listen((e) {
      var p = new Pixel._(e.x, e.y, e.newColor, this);
      var change = new PixelColorChangeEvent('pixelcolorchange', this, p, e.oldColor);
      _colorChangeEventsController.add(change);
      render();
    });
    _editor = new Editor(pixels);
  }

  //

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
    if (floatLayer != null) _renderFloatLayer(ctx);

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
    pixels.eachColorWithIndex((color, x, y) {
      if (color == null || color.isEmpty) return;
      ctx
        ..fillStyle = color
        ..fillRect(x * pixelSize, y * pixelSize, pixelSize, pixelSize);
    });
  }

  void _renderFloatLayer(CanvasRenderingContext2D ctx) {
    final size = pixelSize * FLOAT_PIXEL_SIZE_FACTOR;
    final margin = (pixelSize - size) / 2;
    floatLayer.forEach((point, color) {
      if (color == null || color.isEmpty) return;
      ctx
        ..fillStyle = color
        ..fillRect(point.x * pixelSize + margin, point.y * pixelSize + margin, size, size);
    });
  }

  void _clear(CanvasRenderingContext2D ctx) {
    ctx.clearRect(0, 0, _canvas.width, _canvas.height);
  }

  String getColor(int x, int y) => pixels.get(x, y);
  String getColorByPoint(Point<int> p) => pixels.getByPoint(p);
  void setColor(int x, int y, String color) {
    if (!drawable) return;
    pixels.set(x, y, color.trim());
  }
  void setColorByPoint(Point<int> p, String color) =>
      setColor(p.x, p.y, color);

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

    return new Pixel(x, y, this);
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
    if (!drawable) return;
    selectedBounds = _editor.select(points);
  }
  void selectByRectangle(int top, int left, int width, int height) {
    if (!drawable) return;
    selectedBounds = _editor.selectByRectangle(top, left, width, height);
  }
  void selectByColor(String color) {
    if (!drawable) return;
    selectedBounds = _editor.selectByColor(color);
  }
  void selectByColorNeibors(Point<int> p) {
    if (!drawable) return;
    selectedBounds = _editor.selectByColorNeighbors(p);
  }
  void clearSelection() {
    if (!drawable) return;
    selectedBounds = null;
  }
  bool isSelectedPoint(Point<int> p) =>
      (selectedBounds != null) && selectedBounds.contains(p);
  void fillColor() {
    if (!drawable || selectedBounds == null) return;
    _editor.fillColor(selectedBounds, drawingColor);
  }
  void copy() {
    if (!drawable || selectedBounds == null) return;
    print('copy');
    floatLayer = _editor.copy(selectedBounds);
    selectedBounds = null;
  }
  void cut() {
    if (!drawable || selectedBounds == null) return;
    print('cut');
    floatLayer = _editor.cut(selectedBounds);
    selectedBounds = null;
  }
  void paste() {
    if (!drawable || floatLayer == null) return;
    _editor.paste(floatLayer);
    floatLayer = null;
  }
  void delete() {
    if (!drawable || floatLayer == null) return;
    floatLayer = null;
  }
  bool isFloatedPoint(Point<int> p) =>
      (floatLayer != null) && floatLayer.contains(p);
}

class Pixel extends Point<int>{
  String _color;
  final PixelCanvasElement _canvas;

  Pixel._(int x, int y, this._color, this._canvas): super(x, y);
  factory Pixel(int x, int y, PixelCanvasElement canvas) =>
      new Pixel._(x, y, canvas.getColor(x, y), canvas);
  factory Pixel.fromPoint(Point<int> point, PixelCanvasElement canvas) =>
      new Pixel(point.x, point.y, canvas);

  String get color => _color;
  set color(String newColor) {
    _color = newColor;
    _canvas.setColor(x, y, newColor);
  }

  bool get isSelected => _canvas.isSelectedPoint(toPoint());
  bool get isFloated => _canvas.isFloatedPoint(toPoint());

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
