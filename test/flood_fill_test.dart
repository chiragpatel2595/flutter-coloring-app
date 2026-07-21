import 'dart:typed_data';

import 'package:coloring_app/flood_fill.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a `w`×`h` RGBA buffer from a grid of colors (each an ARGB int).
Uint8List _buffer(int w, int h, int Function(int x, int y) colorAt) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final c = colorAt(x, y);
      final i = (y * w + x) * 4;
      out[i] = (c >> 16) & 0xff; // r
      out[i + 1] = (c >> 8) & 0xff; // g
      out[i + 2] = c & 0xff; // b
      out[i + 3] = (c >> 24) & 0xff; // a
    }
  }
  return out;
}

const _white = 0xFFFFFFFF;
const _black = 0xFF000000;
const _red = 0xFFFF0000;

void main() {
  test('fills a white region bounded by a black divider', () {
    // 5x1 strip: white | white | black | white | white
    const w = 5, h = 1;
    final src = _buffer(w, h, (x, y) => x == 2 ? _black : _white);

    // Fill starting on the left white side.
    final out = floodFill(src, w, h, 0, 0, _red, 48)!;

    Uint8List px(int x) {
      final i = (x) * 4;
      return Uint8List.fromList([out[i], out[i + 1], out[i + 2], out[i + 3]]);
    }

    // Left two pixels become opaque red...
    expect(px(0), [255, 0, 0, 255]);
    expect(px(1), [255, 0, 0, 255]);
    // ...the black divider stops the fill (stays transparent)...
    expect(px(2), [0, 0, 0, 0]);
    // ...and the region on the far side of the divider is untouched.
    expect(px(3), [0, 0, 0, 0]);
    expect(px(4), [0, 0, 0, 0]);
  });

  test('grows into an anti-aliased edge but not into the stroke itself', () {
    // A stroke edge in miniature: white | white | pale pink | solid red.
    // The pale pixel is what anti-aliasing leaves behind — too far from white
    // to pass the normal tolerance, too pale to read as part of the stroke, so
    // without the soft-edge pass it stays unfilled and shows as a halo.
    const w = 4, h = 1;
    const pale = 0xFFFFC8C8; // ~(255, 200, 200)
    final src = _buffer(
      w,
      h,
      (x, y) => switch (x) {
        0 || 1 => _white,
        2 => pale,
        _ => _red,
      },
    );

    final out = floodFill(src, w, h, 0, 0, 0xFF00FF00, 48)!;
    Uint8List px(int x) {
      final i = x * 4;
      return Uint8List.fromList([out[i], out[i + 1], out[i + 2], out[i + 3]]);
    }

    expect(px(0), [0, 255, 0, 255]);
    expect(px(1), [0, 255, 0, 255]);
    // The anti-aliased pixel gets covered — this is the halo fix.
    expect(px(2), [0, 255, 0, 255], reason: 'AA edge should be filled');
    // The stroke itself is far from the seed color, so growth stops.
    expect(px(3), [0, 0, 0, 0], reason: 'must not paint over the stroke');
  });

  test('soft edges never cross a solid one-pixel barrier', () {
    // The growth test is against the *seed* color, not the neighbor, so even a
    // barrier thinner than the number of passes holds.
    const w = 5, h = 1;
    final src = _buffer(w, h, (x, y) => x == 2 ? _black : _white);
    final out = floodFill(src, w, h, 0, 0, _red, 48, edgePasses: 4)!;

    // Far side stays untouched no matter how many growth passes run.
    expect(out[3 * 4 + 3], 0, reason: 'barrier must not be crossed');
    expect(out[4 * 4 + 3], 0, reason: 'barrier must not be crossed');
  });

  test('returns null when the seed is already the fill color', () {
    const w = 3, h = 1;
    final src = _buffer(w, h, (x, y) => _red);
    expect(floodFill(src, w, h, 1, 0, _red, 48), isNull);
  });

  test('fills a whole uniform area', () {
    const w = 4, h = 4;
    final src = _buffer(w, h, (x, y) => _white);
    final out = floodFill(src, w, h, 0, 0, _red, 48)!;

    // Every pixel should now be opaque red.
    for (var p = 0; p < w * h; p++) {
      final i = p * 4;
      expect(
        [out[i], out[i + 1], out[i + 2], out[i + 3]],
        [255, 0, 0, 255],
        reason: 'pixel $p',
      );
    }
  });
}
