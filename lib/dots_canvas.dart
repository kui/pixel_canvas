library dots_canvas.element;

import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:convert';
import 'dart:async';
import 'dots.dart';

@CustomTag('dots-canvas')
class DotsCanvasElement extends PolymerElement {

  static const JSON_PARSER = const JsonDecoder();
  static const CANVAS_FPS = 30;
  static final RENDERER_DELAY =
      new Duration(milliseconds: (1000/CANVAS_FPS).floor());

  @published
  int verticalDots = 32;

  @published
  int horizontalDots = 32;

  @published
  int dotSize = 20;

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
  Dots _dots;
  Timer _rendererTimer;
  final listenerMap = <DotEventListener, EventListener>{};

  DotsCanvasElement.created() : super.created() {
    _canvas = shadowRoot.getElementsByTagName('canvas').first;
    initCanvasContext();

    List<List<String>> matrix = JSON_PARSER.convert(this.text);
    if (matrix == null) {
      _dots = new Dots(verticalDots, horizontalDots);
    } else {
      _dots =
          new Dots.fromColorMatrix(matrix, verticalDots, horizontalDots);
    }

    onPropertyChange(this, #noGridlines, onNoGridlinesChange);
    onPropertyChange(this, #dotSize, onDotSizeChange);

    onPropertyChange(this, #verticalDots, onCanvasChange);
    onPropertyChange(this, #horizontalDots, onCanvasChange);

    _dots.listeners.add((x, y, oldColor, newColor) {
      log('change color(x:$x, y:$y, oldColor:${oldColor}, '
          'newColor:${newColor})');
      renderWithDelay();
    });

    render();
  }

  // callbacks

  void onNoGridlinesChange() {
    renderWithDelay();
  }

  void onCanvasChange() {
    if (verticalDots == _dots.verticalDots &&
        horizontalDots == _dots.horizontalDots)
      return;
    _dots = new Dots.fromDots(_dots, horizontalDots, verticalDots);
    initCanvasContext();
    renderWithDelay();
  }

  void onDotSizeChange() {
    renderWithDelay();
  }

  //

  void initCanvasContext() {
    if (_canvasContext != null) {
      clearCanvas();
    }

    _canvasContext = _canvas.getContext('2d');

    // horizontal gridlines
    for (int i = 0; i < verticalDots + 1; i++) {
      var y = dotSize * i;
      _canvasContext
          ..moveTo(0, y)
          ..lineTo(_canvas.width, y);
    }

    // vertical gridlines
    for (int i = 0; i < horizontalDots + 1; i++) {
      var x = dotSize * i;
      _canvasContext
          ..moveTo(x, 0)
          ..lineTo(x, _canvas.height);
    }

    _canvasContext
        ..lineWidth = gridlineWidth
        ..strokeStyle = gridlineColor;
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

    renderDots();
    if (!noGridlines) {
      renderGridlines();
    }
  }

  void renderGridlines() {
    _canvasContext.stroke();
  }

  void renderDots() {
    _dots.eachColorWithIndex((color, x, y) {
      if (color == null) return;
      if (color.length == 0) return;
      _canvasContext
        ..fillStyle = color
        ..fillRect(x * dotSize, y * dotSize, dotSize, dotSize);
    });
  }

  void clearCanvas() {
    _canvasContext.clearRect(0, 0, _canvas.width, _canvas.height);
  }

  String getColor(int x, int y) => _dots.get(x, y);
  String getColorByPoint(Point<int> p) => _dots.getByPoint(p);
  void setColor(int x, int y, String color) => _dots.set(x, y, color);
  void setColorByPoint(Point<int> p, String color) =>
      _dots.setByPoint(p, color);

  void addDotEventListener(String eventType,
                           DotEventListener listener,
                           [bool useCapture]) =>
    _canvas.addEventListener(
        eventType, createEventListener(listener), useCapture);

  void removeDotEventListener(String eventType,
                              DotEventListener listener,
                              [bool useCapture]) =>
    _canvas.removeEventListener(
        eventType, listenerMap[listener], useCapture);

  EventListener createEventListener(DotEventListener listener) {
    var l = (Event event) {
      if (!(event is MouseEvent)) return;
      var p = detectPoint(event);
      listener(event, p, getColorByPoint(p));
    };
    listenerMap[listener] = l;
    return l;
  }

  Point<int> detectPoint(MouseEvent event) {
    var rect = _canvas.getBoundingClientRect();
    double x = event.client.x - rect.left;
    double y = event.client.y - rect.top;
    return new Point((x/dotSize).floor(), (y/dotSize).floor());
  }

  void log(Object o) {
    if (logging) print('${new DateTime.now()}: ${o}');
  }
}

typedef DotEventListener(Event event, Point<int> point, String color);
