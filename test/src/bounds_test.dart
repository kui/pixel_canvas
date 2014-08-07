import 'dart:math';
import 'package:unittest/unittest.dart';
import 'package:pixel_canvas/src/pixels.dart';
import 'package:pixel_canvas/src/bounds.dart';
import 'package:pixel_canvas/src/outlinable.dart';

final colors =
    [['a',  'a',  'a',  'b',  'b'],
     [null, 'a',  'a',  'c',  'c'],
     ['d', null,  'a',  'c',  'a',  'e'],
     [null, 'b',  'b',  'b',  'b']
     ];
final Pixels pixels = new Pixels.fromColorMatrix(colors, 6, 5);
Point<int> p(int x, int y) => new Point(x, y);
HorizontalLine hl(int x, int y) => new HorizontalLine(p(x,y));
VerticalLine vl(int x, int y) => new VerticalLine(p(x,y));

main() {
  test('Default constractor: non-empty', () {
    final r1 = new Bounds(pixels, [p(0,0),p(0,1),p(1,0),p(6,5)].toSet());
    expect(r1.points, [p(0,0),p(0,1),p(1,0)].toSet());
    expect(r1.outline, [hl(0,0),hl(1,0),vl(2,0),hl(1,1),vl(1,1),hl(0,2),vl(0,1),vl(0,0)].toSet());
  });
  test('Default constractor: empty', () {
    final r1 = new Bounds(pixels, [p(6,5)].toSet());
    expect(r1.points, [].toSet());
    expect(r1.outline, [].toSet());
  });
  test('Bounds.fromRectangle: the internal rect', () {
    final r1 = new Bounds.fromRectangle(pixels, new Rectangle(0, 0, 1, 1));
    expect(r1.points, [p(0,0),p(1,0),p(1,1),p(0,1)].toSet());
    expect(r1.outline, [hl(0,0),hl(1,0),vl(2,0),vl(2,1),hl(1,2),hl(0,2),vl(0,1),vl(0,0)].toSet());

    final r2 = new Bounds.fromRectangle(pixels, new Rectangle(3, 2, 0, 0));
    expect(r2.points, [p(3,2)].toSet());
    expect(r2.outline, [hl(3,2),vl(4,2),hl(3,3),vl(3,2)].toSet());

    final r3 = new Bounds.fromRectangle(pixels, new Rectangle(2, 1, 2, 0));
    expect(r3.points, [p(2,1),p(3,1),p(4,1)].toSet());
    expect(r3.outline, [hl(2,1),hl(3,1),hl(4,1),hl(2,2),hl(3,2),hl(4,2),vl(5,1),vl(2,1)].toSet());
  });
  test('Bounds.fromRectangle: the overlapping rect', () {
    final r5 = new Bounds.fromRectangle(pixels, new Rectangle(5, 2, 3, 5));
    expect(r5.points, [p(5,2),p(5,3),p(5,4)].toSet());
    expect(r5.outline, [hl(5,2),hl(5,5),vl(5,2),vl(5,3),vl(5,4),vl(6,2),vl(6,3),vl(6,4)].toSet());
  });
  test('Bounds.fromRectangle: the non-overlapping rect', () {
    final r8 = new Bounds.fromRectangle(pixels, new Rectangle(5, 6, 3, 4));
    expect(r8.points, [].toSet());
    expect(r8.outline, [].toSet());
  });
  test('Bounds.sameColor: exsiting color', () {
    final r1 = new Bounds.sameColor(pixels, 'c');
    expect(r1.points, [p(3,1),p(4,1),p(3,2)].toSet());
    expect(r1.outline, [hl(3,1),hl(4,1),hl(3,3),hl(4,2),vl(3,1),vl(3,2),vl(5,1),vl(4,2)].toSet());

    final r2 = new Bounds.sameColor(pixels, 'd');
    expect(r2.points, [p(0,2)].toSet());
    expect(r2.outline, [hl(0,2),hl(0,3),vl(0,2),vl(1,2)].toSet());

    final r3 = new Bounds.sameColor(pixels, null);
    expect(
        r3.points,
        [p(0,1),p(0,3),p(1,2),p(5,0),p(5,1),p(5,3),p(5,4),
         p(0,4),p(1,4),p(2,4),p(3,4),p(4,4)].toSet());
  });
  test('Bounds.sameColor: non-exsiting color', () {
    final r1 = new Bounds.sameColor(pixels, 'foo');
    expect(r1.points, [].toSet());
    expect(r1.outline, [].toSet());

    final r2 = new Bounds.sameColor(pixels, '');
    expect(r2.points, [].toSet());
    expect(r2.outline, [].toSet());
  });
  test('Bounds.sameColorNeighbors: valid point', () {
    final r1 = new Bounds.sameColorNeighbors(pixels, p(0,0));
    expect(r1.points, [p(0,0),p(1,0),p(2,0),p(1,1),p(2,1),p(2,2)].toSet());

    final r2 = new Bounds.sameColorNeighbors(pixels, p(0,2));
    expect(r2.points, [p(0,2)].toSet());

    final r3 = new Bounds.sameColorNeighbors(pixels, p(5,0));
    expect(r3.points, [p(5,0),p(5,1)].toSet());
  });
  test('Bounds.sameColorNeighbors: invalid point', () {
    expect(
        () => new Bounds.sameColorNeighbors(pixels, p(6,0)),
        throwsA(new isInstanceOf<RangeError>()));
  });
}
