library pixel_canvas.element;

import 'dart:html';
import 'dart:async';
import 'package:polymer/polymer.dart';
import 'src/pixels.dart';
import 'src/bounds.dart';
import 'src/float_layer.dart';
import 'src/outlinable.dart';

part 'action.dart';

@CustomTag('pixel-canvas')
class PixelCanvasElement extends PolymerElement {

  static const CANVAS_FPS = 30;
  static final RENDERER_DELAY =
      new Duration(milliseconds: (1000/CANVAS_FPS).floor());
  static const LEFT_BUTTON = 1;
  static const DEFAULT_PIXELS = 32;
  static const DEFAULT_PIXEL_SIZE = 24;
  static const CTRL_CODE = 17;

  @PublishedProperty(reflect: true)
  int get verticalPixels => readValue(#verticalPixels, () => DEFAULT_PIXELS);
  set verticalPixels(int p) => writeValue(#verticalPixels, p);

  @PublishedProperty(reflect: true)
  int get horizontalPixels => readValue(#horizontalPixels, () => DEFAULT_PIXELS);
  set horizontalPixels(int p) => writeValue(#horizontalPixels, p);

  @PublishedProperty(reflect: true)
  int get pixelSize => readValue(#pixelSize, () => DEFAULT_PIXEL_SIZE);
  set pixelSize(int s) => writeValue(#pixelSize, s);

  @PublishedProperty(reflect: true)
  bool get noGridlines => readValue(#noGridlines, () => false);
  set noGridlines(bool b) => writeValue(#noGridlines, b);

  @PublishedProperty(reflect: true)
  String get gridlineColor => readValue(#gridlineColor, () => 'rgba(0, 0, 0, 0.2)');
  set gridlineColor(String c) => writeValue(#gridlineColor, c);

  @PublishedProperty(reflect: true)
  int get gridlineWidth => readValue(#gridlineWidth, () => 1);
  set gridlineWidth(int w) => writeValue(#gridlineWidth, w);

  @PublishedProperty(reflect: true)
  bool get drawable => readValue(#drawable, () => false);
  set drawable(bool b) => writeValue(#drawable, b);

  @PublishedProperty(reflect: true)
  String get drawingColor => readValue(#drawingColor, () => 'Black');
  set drawingColor(String c) => writeValue(#drawingColor, c);

  @observable
  Pixels pixels;

  CanvasElement _canvas;
  Timer _rendererTimer;

  Pixel mouseOveredPixel;

  @published
  Action get currentAction {
    if (_currentAction == null) {
      _currentAction = new DrawingAction(this);
    }
    return _currentAction;
  }
  set currentAction(Action a) {
    final oldValue = _currentAction;
    final newValue = a;
    _currentAction = a;
    notifyPropertyChange(#currentAction, oldValue, newValue);
  }
  Action _currentAction;
  InstantSelectionAction _instantAction;

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
  StreamController<ActionChangeEvent> _actionChangeEventController =
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
  Stream<ActionChangeEvent> get onActionChange =>
      _actionChangeEventController.stream;

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
  gridlineColorChanged() => render();
  pixelSizeChanged() => render();

  verticalPixelsChanged()   => handleCanvasChange();
  horizontalPixelsChanged() => handleCanvasChange();

  handleCanvasChange() {
    if (verticalPixels == pixels.verticalPixels &&
        horizontalPixels == pixels.horizontalPixels)
      return;

    currentAction = null;

    pixels = new Pixels.fromPixels(pixels, verticalPixels, horizontalPixels);
    _initPixels();
  }

  pixelsChanged() => render();
  currentActionChanged(Action old) {
    render();
    _dispachActionChange(old, currentAction);
  }

  void _dispachActionChange(Action oldAction, Action newAction) =>
    _actionChangeEventController.add(
      new ActionChangeEvent(oldAction, newAction));

  void _mouseOveredPxChange(Pixel oldPixel, Pixel newPixel, MouseEvent event) {
    if (newPixel != null)
      _dispatchPixelMouseEvent(_mouseOverEventsController, 'mouseover',
          event, newPixel);

    if (oldPixel != null)
      _dispatchPixelMouseEvent(_mouseOutEventsController, 'mouseout',
          event, oldPixel);

    currentAction.handleMouseOver(newPixel);
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
                event, mouseOveredPixel))
        ..onMouseUp.listen(_handleMouseUp);
    document
        ..onMouseUp.listen(_handleGlobalMouseUp)
        ..onKeyDown.listen(_handleKeyDown)
        ..onKeyUp.listen(_handleKeyUp);
  }

  _handleGlobalMouseUp(MouseEvent e) {
    if (_isLeftButton(e)) {
      currentAction.handleMouseUp(mouseOveredPixel);
    }
  }

  _handleMouseUp(MouseEvent event) {
    _dispatchPixelMouseEvent(_mouseUpEventsController, 'pixelmouseup',
        event, mouseOveredPixel);
  }

  _updateMouseOveredPx(MouseEvent mouseEvent) {
    final newPx = detectPixel(mouseEvent);
    final oldPx = mouseOveredPixel;
    if (oldPx == newPx) return;
    if (oldPx != null && oldPx.equalsPoint(newPx)) return;
    mouseOveredPixel = newPx;
    _mouseOveredPxChange(oldPx, newPx, mouseEvent);
  }

  _handleMouseDown(MouseEvent event) {
    _dispatchPixelMouseEvent(_mouseDownEventsController,
        'pixelmousedown', event, mouseOveredPixel);

    if (_isLeftButton(event)) {
      currentAction.handleMouseDown(mouseOveredPixel);
    }
  }

  void _handleKeyDown(KeyboardEvent event) {
    if (_instantAction == null)
      _createInstantAction();
    if (_instantAction.isReady(event)) {
      _instantAction.isMouseDown = currentAction.isMouseDown;
      currentAction = _instantAction;
    }
    currentAction.handleKeyDown(event);
  }
  void _handleKeyUp(KeyboardEvent event) {
    currentAction.handleKeyUp(event);
  }

  _dispatchPixelMouseEvent(StreamController c, String type, MouseEvent e, Pixel p) =>
      c.add(new PixelMouseEvent(type, this, p, e));

  _createInstantAction() {
    final bounds = new Bounds(pixels, []);
    _instantAction = new InstantSelectionAction(this, bounds, CTRL_CODE);
  }

  static bool _isLeftButton(MouseEvent e) => LEFT_BUTTON == e.which;

  void _initPixels() {
    pixels.onColorChange.listen((e) {
      var p = new Pixel._(e.x, e.y, e.newColor, this);
      var change = new PixelColorChangeEvent('pixelcolorchange', this, p, e.oldColor);
      _colorChangeEventsController.add(change);
      render();
    });
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

    currentAction.renderBeforeGrids(ctx);

    if (!noGridlines) {
      _renderGridlines(ctx);
    }

    currentAction.renderAfterGrids(ctx);
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

  void _renderPixels(CanvasRenderingContext2D ctx) {
    pixels.eachColorWithIndex((color, x, y) {
      if (color == null || color.isEmpty) return;
      ctx
        ..fillStyle = color
        ..fillRect(x * pixelSize, y * pixelSize, pixelSize, pixelSize);
    });
  }

  void _clear(CanvasRenderingContext2D ctx) {
    ctx.clearRect(0, 0, _canvas.width, _canvas.height);
  }

  String getColor(int x, int y) => pixels.get(x, y);
  String getColorByPoint(Point<int> p) => pixels.getByPoint(p);
  void setColor(int x, int y, String color) {
    if (!drawable) return;
    pixels.set(x, y, color);
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

  void setCanvasClass(String classes) {
    _canvas.className = classes;
  }

  String toDataUrl([String type = 'image/png', num quality]) =>
    _canvas.toDataUrl(type, quality);

  void downloadAs(String name, [String type = 'image/png', num quality]) {
    AnchorElement anchor = new AnchorElement()
      ..href = toDataUrl(type, quality)
      ..download = name
      ..dispatchEvent(new MouseEvent('click'));
  }

  // selection

  void startSelection() {
    if (!drawable) return;
    final bounds = new Bounds(pixels, []);
    currentAction = new PointsSelectionAction(this, bounds);
  }
  void startRectSelection() {
    if (!drawable) return;
    final bounds = new Bounds(pixels, []);
    currentAction = new RectangleSelectionAction(this, bounds, null);
  }
  void startSameColorsSelection() {
    if (!drawable) return;
    currentAction = new SameColorsSelectionAction.empty(this);
  }
  void startSameColorNeiborsSelection() {
    if (!drawable) return;
    currentAction = new SameColorNeighborsSelectionAction.empty(this);
  }

  void select(Iterable<Point<int>> points) {
    if (!drawable) return;
    final bounds = new Bounds(pixels, points);
    currentAction = new ImmutableSelectionAction(this, bounds);
  }
  void selectByRectangle(int left, int top, int width, int height) {
    if (!drawable) return;
    final bounds = new Bounds.fromRectangle(pixels, new Rectangle(left, top, width, height));
    currentAction = new ImmutableSelectionAction(this, bounds);
  }
  void selectByColor(String color) {
    if (!drawable) return;
    final bounds = new Bounds.sameColor(pixels, color.toLowerCase());
    currentAction = new ImmutableSelectionAction(this, bounds);
  }
  void selectByColorNeibors(Point<int> point) {
    if (!drawable) return;
    final bounds = new Bounds.sameColorNeighbors(pixels, point);
    currentAction = new ImmutableSelectionAction(this, bounds);
  }

  void fillSelection() {
    if (!drawable) return;
    if (currentAction is! SelectionAction) return;
    final points = (currentAction as SelectionAction).bounds.points;
    _fill(points, drawingColor);
    clearSelection();
  }
  void copySelection() {
    if (!drawable) return;
    if (currentAction is! SelectionAction) return;
    final points = (currentAction as SelectionAction).bounds.points;
    currentAction = new FloatLayerAction(this, points);
  }
  void cutSelection() {
    if (!drawable) return;
    if (currentAction is! SelectionAction) return;
    final points = (currentAction as SelectionAction).bounds.points;
    currentAction = new FloatLayerAction(this, points);
    _fill(points, null);
  }
  void clearSelection() {
    if (currentAction is! SelectionAction) return;
    currentAction = null;
  }
  void deleteSelection() {
    if (currentAction is! SelectionAction) return;
    final points = (currentAction as SelectionAction).bounds.points;
    currentAction = null;
    _fill(points, null);
  }
  void _fill(Iterable<Point<int>> points, String color) {
    points.forEach((p) {
      setColor(p.x, p.y, color);
    });
  }

  void pasteFloatLayer() {
    if (!drawable) return;
    if (currentAction is! FloatLayerAction) return;
    final floatLayer = (currentAction as FloatLayerAction).floatLayer;
    final rect = pixels.rectangle;
    floatLayer.forEach((point, color) {
      if (!rect.containsPoint(point)) return;
      setColorByPoint(point, color);
    });
    currentAction = null;
  }
  void deleteFloatLayer() {
    if (!drawable) return;
    print(currentAction is FloatLayerAction);
    if (currentAction is FloatLayerAction)
      currentAction = null;
  }
}

class Pixel {
  String _color;
  final PixelCanvasElement _canvas;
  final Point<int> point;

  Pixel._(int x, int y, this._color, this._canvas): this.point = new Point(x, y);
  factory Pixel(int x, int y, PixelCanvasElement canvas) =>
      new Pixel._(x, y, canvas.getColor(x, y), canvas);
  factory Pixel.fromPoint(Point<int> point, PixelCanvasElement canvas) =>
      new Pixel(point.x, point.y, canvas);

  String get color => _color;
  set color(String newColor) {
    _color = newColor;
    _canvas.setColor(point.x, point.y, newColor);
  }

  bool equalsPoint(Pixel o) => super == o;
  @override
  String toString() => 'Pixel(${point.x},${point.y},$color)';
  @override
  bool operator ==(o) =>
      o is Pixel && o.point == point;
  @override
  int get hashCode => (color.hashCode * 31 + point.hashCode) & 0x3fffffff;
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
class ActionChangeEvent {
  final oldAction;
  final newAction;
  ActionChangeEvent(this.oldAction, this.newAction);
}
