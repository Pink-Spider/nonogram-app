import 'package:rules_nonogram/rules_nonogram.dart';
import 'package:test/test.dart';

/// The library is the game: a shape that needs guessing, or that is mostly
/// empty, ships a puzzle nobody can finish or enjoy. These checks are the
/// gate on adding new pictures.
void main() {
  group('every shape is well-formed', () {
    for (final shape in ShapeLibrary.all) {
      test('${shape.id} (${shape.size}x${shape.size})', () {
        expect(shape.rows.length, shape.size, reason: 'row count');
        for (final row in shape.rows) {
          expect(row.length, shape.size, reason: 'row "$row" width');
        }
        expect(shape.toGrid().length, shape.size * shape.size);
      });
    }
  });

  group('every shape solves by pure logic', () {
    for (final shape in ShapeLibrary.all) {
      test('${shape.id} needs no guessing', () {
        final grid = shape.toGrid();
        final clues = NonogramSolver.cluesFor(
          grid,
          width: shape.size,
          height: shape.size,
        );
        final result = NonogramSolver(
          rowClues: clues.rows,
          colClues: clues.cols,
        ).solve();

        expect(result.solved, isTrue,
            reason: '${shape.id} stalls — line logic cannot finish it');
        expect(result.hardest, isNot(Technique.search));
        // The solver must land on the picture, not some other valid grid.
        for (var i = 0; i < grid.length; i++) {
          final expected = grid[i] == Cell.filled;
          final got = result.board[i] == Cell.filled;
          expect(got, expected, reason: '${shape.id} differs at cell $i');
        }
      });
    }
  });

  group('every shape reads as a picture', () {
    for (final shape in ShapeLibrary.all) {
      test('${shape.id} has usable density', () {
        expect(shape.density, greaterThan(0.2),
            reason: '${shape.id} is too sparse to read');
        expect(shape.density, lessThan(0.85),
            reason: '${shape.id} is nearly solid — little to deduce');
      });
    }
  });

  group('shapes use the board without being padded out', () {
    for (final shape in ShapeLibrary.all) {
      test('${shape.id} reaches most edges', () {
        final grid = shape.toGrid();
        bool rowUsed(int r) => List.generate(shape.size,
            (c) => grid[r * shape.size + c]).any((v) => v == Cell.filled);
        bool colUsed(int c) => List.generate(shape.size,
            (r) => grid[r * shape.size + c]).any((v) => v == Cell.filled);

        // Demanding all four edges was a mistake: it forced filler pixels
        // into the corners and turned recognisable pictures into blobs.
        // What actually matters is that the drawing is not floating in a
        // margin — so require most edges, and let a silhouette keep the
        // one it needs.
        final edgesUsed = [
          rowUsed(0),
          rowUsed(shape.size - 1),
          colUsed(0),
          colUsed(shape.size - 1),
        ].where((used) => used).length;

        expect(edgesUsed, greaterThanOrEqualTo(3),
            reason: '${shape.id} floats inside the board');
      });
    }
  });

  test('each size has enough shapes that dailies do not repeat weekly', () {
    for (final size in ShapeLibrary.sizes) {
      expect(ShapeLibrary.forSize(size).length, greaterThanOrEqualTo(3),
          reason: 'size $size');
    }
  });

  test('ids are unique — saved games reference them', () {
    final ids = ShapeLibrary.all.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('byId finds shapes and rejects unknown ids', () {
    expect(ShapeLibrary.byId('heart')?.size, 5);
    expect(ShapeLibrary.byId('nope'), isNull);
  });
}
