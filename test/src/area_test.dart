import 'dart:math';
import 'package:unittest/unittest.dart';
import 'package:pixel_canvas/pixels.dart';
import 'package:pixel_canvas/src/area.dart';

Point<int> p(int x, int y) => new Point(x, y);
final colors =
    [['a',  'a',  'a',  'b',  'b'],
     [null, 'a',  'a',  'c',  'c'],
     ['d', null,  'a',  'c',  'a',  'e'],
     [null, 'b',  'b',  'b',  'b']
     ];
final Pixels pixels = new Pixels.fromColorMatrix(colors, 6, 5);

main() {
  testRectArea();
  testSameColorArea();
  testNeighborSameColorArea();
}

void testRectArea() {
  test('RectArea: the internal rect', () {
    final r1 = new RectArea(pixels, 0, 0, 1, 1);
    expect(r1.points, [p(0,0)].toSet());

    final r2 = new RectArea(pixels, 0, 0, 2, 2);
    expect(r2.points, [p(0,0),p(1,0),p(0,1),p(1,1)].toSet());

    final r3 = new RectArea(pixels, 2, 1, 3, 1);
    expect(r3.points, [p(2,1),p(3,1),p(4,1)].toSet());
  });
  test('RectArea: zero width or height', () {
    final r6 = new RectArea(pixels, 2, 1, 0, 1);
    expect(r6.points, [].toSet());

    final r7 = new RectArea(pixels, 2, 1, 1, 0);
    expect(r7.points, [].toSet());
  });
  test('RectArea: the overlapping rect', () {
    final r5 = new RectArea(pixels, 4, 2, 3, 5);
    expect(r5.points, [p(4,2),p(4,3),p(4,4),p(5,2),p(5,3),p(5,4)].toSet());
  });
  test('RectArea: the non-overlapping rect', () {
    final r8 = new RectArea(pixels, 5, 6, 3, 4);
    expect(r8.points, [].toSet());
  });
}

void testSameColorArea() {
  test('SameColorArea: exsiting color', () {
    final r1 = new SameColorArea(pixels, 'a');
    expect(r1.points, [p(0,0),p(1,0),p(2,0),p(1,1),p(2,1),p(2,2),p(4,2)].toSet());

    final r2 = new SameColorArea(pixels, 'd');
    expect(r2.points, [p(0,2)].toSet());

    final r3 = new SameColorArea(pixels, null);
    expect(
        r3.points,
        [p(0,1),p(0,3),p(1,2),p(5,0),p(5,1),p(5,3),p(5,4),
         p(0,4),p(1,4),p(2,4),p(3,4),p(4,4)].toSet());
  });
  test('SameColorArea: non-exsiting color', () {
    final r1 = new SameColorArea(pixels, 'foo');
    expect(r1.points, [].toSet());

    final r2 = new SameColorArea(pixels, '');
    expect(r2.points, [].toSet());
  });
}

void testNeighborSameColorArea() {
  test('NeighborSameColorArea: valid point', () {
    final r1 = new NeighborSameColorArea(pixels, p(0,0));
    expect(r1.points, [p(0,0),p(1,0),p(2,0),p(1,1),p(2,1),p(2,2)].toSet());

    final r2 = new NeighborSameColorArea(pixels, p(0,2));
    expect(r2.points, [p(0,2)].toSet());

    final r3 = new NeighborSameColorArea(pixels, p(5,0));
    expect(r3.points, [p(5,0),p(5,1)].toSet());
  });
  test('NeighborSameColorArea: invalid point', () {
    expect(
        () => new NeighborSameColorArea(pixels, p(6,0)),
        throwsA(new isInstanceOf<RangeError>()));
  });
}
