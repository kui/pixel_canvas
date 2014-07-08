library dots_canvas;

import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:convert';
import 'dots.dart';

@CustomTag('dots-canvas')
class DotsCanvasElement extends PolymerElement {

  static final JSON_PARSER = new JsonDecoder();

  @published
  int verticalDots = 32;

  @published
  int horizontalDots = 32;

  @published
  int dotSize = 20;

  @published
  bool noGridlines = false;

  @published
  String gridlineColor = '#999';

  @published
  int gridlineWidth = 1;

  CanvasElement canvas;
  CanvasRenderingContext2D canvasContext;
  Dots dots;

  DotsCanvasElement.created() : super.created() {
    canvas = shadowRoot.getElementsByTagName('canvas').first;
    canvasContext = canvas.getContext('2d');

    List<List<String>> matrix = JSON_PARSER.convert(this.text);
    if (matrix == null) {
      dots = new Dots(verticalDots, horizontalDots);
    } else {
      dots =
          new Dots.fromColorMatrix(matrix, verticalDots, horizontalDots);
    }

    onPropertyChange(this, #noGridlines, onNoGridlinesChange);
    onPropertyChange(this, #dotSize, onDotSizeChange);

    onPropertyChange(this, #verticalDots, onCanvasChange);
    onPropertyChange(this, #horizontalDots, onCanvasChange);

    render();
  }

  // callbacks

  void onNoGridlinesChange() {
    render();
  }

  void onCanvasChange() {
    if (verticalDots == dots.verticalDots &&
        horizontalDots == dots.horizontalDots)
      return;
    dots = new Dots.fromDots(dots, horizontalDots, verticalDots);
    render();
  }

  void onDotSizeChange() {
    render();
  }

  //

  void render() {
    clear();

    renderDots();
    if (!noGridlines) {
      renderGridlines();
    }
  }

  void renderGridlines() {
    // horizontal gridlines
    for (int i = 0; i < verticalDots + 1; i++) {
      var y = dotSize * i;
      canvasContext
          ..moveTo(0, y)
          ..lineTo(canvas.width, y);
    }

    // vertical gridlines
    for (int i = 0; i < horizontalDots + 1; i++) {
      var x = dotSize * i;
      canvasContext
          ..moveTo(x, 0)
          ..lineTo(x, canvas.height);
    }

    canvasContext
        ..lineWidth = gridlineWidth
        ..strokeStyle = gridlineColor
        ..stroke();
  }

  void renderDots() {
    dots.eachColorWithIndex((color, x, y) {
      if (color == null) return;
      if (color.length == 0) return;
      canvasContext
        ..fillStyle = color
        ..fillRect(x * dotSize, y * dotSize, dotSize, dotSize);
    });
  }

  void clear() {
    canvasContext.clearRect(0, 0, canvas.width, canvas.height);
  }
}
