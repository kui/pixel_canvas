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

  @published
  bool logging = false;

  CanvasElement _canvas;
  CanvasRenderingContext2D _canvasContext;
  Pixels _pixels;
  Timer _rendererTimer;
  final listenerMap = <PixelEventListener, EventListener>{};

  PixelCanvasElement.created() : super.created() {
    _canvas = shadowRoot.getElementsByTagName('canvas').first;
    initCanvas();
    initCanvasContext();

    _pixels = new Pixels.fromJson(this.text, verticalPixels, horizontalPixels);
    initPixels();

    onPropertyChange(this, #noGridlines, handleNoGridlinesChange);
    onPropertyChange(this, #pixelSize, handlePixelSizeChange);

    onPropertyChange(this, #verticalpixels, handleCanvasChange);
    onPropertyChange(this, #horizontalpixels, handleCanvasChange);

    render();
  }

  // callbacks

  void handleNoGridlinesChange() {
    renderWithDelay();
  }

  void handleCanvasChange() {
    if (verticalPixels == _pixels.verticalPixels &&
        horizontalPixels == _pixels.horizontalPixels)
      return;
    _pixels = new Pixels.fromPixels(_pixels, horizontalPixels, verticalPixels);
    initPixels();
    initCanvasContext();
    renderWithDelay();
  }

  void handlePixelSizeChange() {
    renderWithDelay();
  }

  //

  void initCanvas() {
    on['pixelmouseover'];
    on['pixelmouseout'];
    on['pixelclick'];
    on['pixelmousedown'];
    on['pixelmouseup'];
  }

  void initCanvasContext() {
    if (_canvasContext != null) {
      clearCanvas();
    }

    _canvasContext = _canvas.getContext('2d');
    lineAsGrids();
  }

  void lineAsGrids() {
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

  void initPixels() {
    _pixels.colorChange.listen((e) {
      log('change color(x:${e.x}, y:${e.y}, oldColor:${e.oldColor}, '
          'newColor:${e.newColor})');
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
    log('render');
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

  void addPixelEventListener(String eventType,
                             PixelEventListener listener,
                             [bool useCapture]) =>
    _canvas.addEventListener(
        eventType, _createEventListener(listener), useCapture);

  void removePixelEventListener(String eventType,
                                PixelEventListener listener,
                                [bool useCapture]) =>
    _canvas.removeEventListener(
        eventType, listenerMap[listener], useCapture);

  EventListener _createEventListener(PixelEventListener listener) {
    var l = (Event event) {
      if (!(event is MouseEvent)) return;
      var p = detectPixel(event);
      listener(event, p);
    };
    listenerMap[listener] = l;
    return l;
  }

  Pixel detectPixel(MouseEvent event) {
    var rect = _canvas.getBoundingClientRect();
    double eventX = event.client.x - rect.left;
    double eventY = event.client.y - rect.top;
    int x = (eventX/pixelSize).floor();
    int y = (eventY/pixelSize).floor();
    return new Pixel(x, y, getColor(x, y));
  }

  void log(Object o) {
    if (logging) print('${new DateTime.now()}: ${o}');
  }
}

typedef PixelEventListener(Event event, Pixel pixel);

class Pixel {
  final int x, y;
  final String color;

  Pixel(this.x, this.y, this.color);

  Point<int> toPoint() => new Point<int>(x, y);
}
