library pixel_canvas.element;

import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'pixels.dart';

@CustomTag('pixel-canvas')
class PixelCanvasElement extends PolymerElement {

  static const CANVAS_FPS = 30;
  static final RENDERER_DELAY =
      new Duration(milliseconds: (1000/CANVAS_FPS).floor());

  @published
  int verticalPixels = 32;

  @published
  int horizontalPixels = 32;

  @published
  int pixelSize = 20;

  @published
  bool noGridlines = false;

  @published
  String gridlineColor = 'rgba(0, 0, 0, 0.3)';

  @published
  int gridlineWidth = 1;

  CanvasElement _canvas;
  CanvasRenderingContext2D _canvasContext;
  Pixels _pixels;
  Timer _rendererTimer;

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


  PixelCanvasElement.created() : super.created();

  @override
  ready() {
    _canvas = shadowRoot.getElementsByTagName('canvas').first;
    _initCanvas();
    _initCanvasContext();

    _pixels = new Pixels.fromJson(this.text, verticalPixels, horizontalPixels);
    _initPixels();

    render();
  }

  // callbacks

  void noGridlinesChanged() => renderWithDelay();
  void pixelSizeChanged()   => renderWithDelay();

  void verticalPixelsChanged()   => handleCanvasChange();
  void horizontalPixelsChanged() => handleCanvasChange();

  void handleCanvasChange() {
    if (verticalPixels == _pixels.verticalPixels &&
        horizontalPixels == _pixels.horizontalPixels)
      return;
    _pixels = new Pixels.fromPixels(_pixels, horizontalPixels, verticalPixels);
    _initPixels();
    _initCanvasContext();
    renderWithDelay();
  }

  //

  void _initCanvas() {
    _initCustomEventListener();
  }

  void _initCustomEventListener() {
    // binded value: the pixel which be mouse-overed currently
    Pixel currentPx = null;

    _canvas.onMouseMove.listen((MouseEvent event) {
      var px = detectPixel(event);
      if (px == null) {
        currentPx == null;
        return;
      }
      dispatchPixelMouseEvent(_mouseMoveEventsController, 'pixelmousemove',
          event, px);

      if (px.equalsOnPoint(currentPx)) {
        return;
      }

      if (currentPx != null) {
        dispatchPixelMouseEvent(_mouseOutEventsController, 'pixelmouseout',
            event, currentPx);
      }
      dispatchPixelMouseEvent(_mouseOverEventsController, 'pixelmouseover',
          event, px);

      currentPx = px;
    });

    _canvas.onMouseOut.listen((MouseEvent event) {
      dispatchPixelMouseEvent(_mouseOutEventsController, 'pixelmouseout',
          event, currentPx);
      currentPx = null;
    });

    _canvas.onMouseOver.listen((MouseEvent event) {
      var px = detectPixel(event);
      if (px != null) {
        dispatchPixelMouseEvent(_mouseOverEventsController, 'pixelmouseover',
            event, px);
      }
      currentPx = px;
    });

    _canvas.onClick.listen((MouseEvent event) {
      dispatchPixelMouseEvent(_clickEventsController, 'pixelclick', event,
          currentPx);
    });

    _canvas.onMouseDown.listen((MouseEvent event) {
      dispatchPixelMouseEvent(_mouseDownEventsController, 'pixelmousedown',
          event, currentPx);
    });

    _canvas.onMouseUp.listen((MouseEvent event) {
      dispatchPixelMouseEvent(_mouseUpEventsController, 'pixelmouseup', event,
          currentPx);
    });
  }

  dispatchPixelMouseEvent(StreamController c,
                          String type,
                          MouseEvent e,
                          Pixel p) =>
      c.add(new PixelMouseEvent(type, this, p, e));

  void _initCanvasContext() {
    if (_canvasContext != null) {
      clearCanvas();
    }

    _canvasContext = _canvas.getContext('2d');
    _lineAsGrids();
  }

  void _lineAsGrids() {
    // horizontal gridlines
    for (int i = 0; i < verticalPixels + 1; i++) {
      var y = pixelSize * i;
      _canvasContext
          ..moveTo(0, y)
          ..lineTo(_canvas.width, y);
    }

    // vertical gridlines
    for (int i = 0; i < horizontalPixels + 1; i++) {
      var x = pixelSize * i;
      _canvasContext
          ..moveTo(x, 0)
          ..lineTo(x, _canvas.height);
    }

    _canvasContext
        ..lineWidth = gridlineWidth
        ..strokeStyle = gridlineColor;
  }

  void _initPixels() {
    _pixels.onColorChange.listen((e) {
      var p = new Pixel(e.x, e.y, e.newColor, _pixels);
      var change = new PixelColorChangeEvent('pixelcolorchange', this, p, e.oldColor);
      _colorChangeEventsController.add(change);
      renderWithDelay();
    });
  }

  void renderWithDelay() {
    if (_rendererTimer != null) return;

    _rendererTimer = new Timer(RENDERER_DELAY, () {
      _rendererTimer = null;
      render();
    });
  }

  void render() {
    _beforeRenderingEventController.add(
        new PixelCanvesEvent('beforerendering', this));

    _render();

    _afterRenderingEventController.add(
        new PixelCanvesEvent('afterrendering', this));
  }

  void _render() {
    clearCanvas();

    renderPixels();
    if (!noGridlines) {
      renderGridlines();
    }
  }

  void renderGridlines() {
    _canvasContext.stroke();
  }

  void renderPixels() {
    _pixels.eachColorWithIndex((color, x, y) {
      if (color == null) return;
      if (color.length == 0) return;
      _canvasContext
        ..fillStyle = color
        ..fillRect(x * pixelSize, y * pixelSize, pixelSize, pixelSize);
    });
  }

  void clearCanvas() {
    _canvasContext.clearRect(0, 0, _canvas.width, _canvas.height);
  }

  String getColor(int x, int y) => _pixels.get(x, y);
  String getColorByPoint(Point<int> p) => _pixels.getByPoint(p);
  void setColor(int x, int y, String color) => _pixels.set(x, y, color);
  void setColorByPoint(Point<int> p, String color) =>
      _pixels.setByPoint(p, color);

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

    return new Pixel(x, y, getColor(x, y), _pixels);
  }

  String toDataUrl([String type = 'image/png', num quality]) =>
    _canvas.toDataUrl(type, quality);

  void downloadAs(String name, [String type = 'image/png', num quality]) {
    AnchorElement anchor = new AnchorElement()
      ..href = toDataUrl(type, quality)
      ..download = name
      ..dispatchEvent(new MouseEvent('click'));
  }
}

class Pixel {
  final int x, y;
  String _color;
  final Pixels _pixels;

  Pixel(this.x, this.y, this._color, this._pixels) {
  }

  String get color => _color;
  void set color(String newColor) {
    _color = newColor;
    _pixels.set(x, y, newColor);
  }

  bool equalsOnPoint(Pixel o) => o != null && x == o.x && y == o.y;
  Point<int> toPoint() => new Point<int>(x, y);
  String toString() => 'Pixel($x,$y,$color)';
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
