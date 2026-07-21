import 'dart:typed_data';

/// Pure flood-fill over a raw RGBA pixel buffer — no Flutter/engine needed, so
/// it's easy to unit-test.
///
/// Starting at pixel (`sx`, `sy`) in [src] (`w`×`h`, 4 bytes/pixel, RGBA),
/// it walks the contiguous region whose pixels are within [tol] on every RGB
/// channel of the seed pixel, and writes [fillArgb] into those pixels of a new
/// transparent buffer (the same size), which it returns.
///
/// Returns null when there's nothing to do — the seed is already within 8 of
/// the fill color — so the caller can skip creating an empty fill.
Uint8List? floodFill(
  Uint8List src,
  int w,
  int h,
  int sx,
  int sy,
  int fillArgb,
  int tol,
) {
  final seed = (sy * w + sx) * 4;
  final sr = src[seed], sg = src[seed + 1], sb = src[seed + 2];

  final fA = (fillArgb >> 24) & 0xff;
  final fR = (fillArgb >> 16) & 0xff;
  final fG = (fillArgb >> 8) & 0xff;
  final fB = fillArgb & 0xff;

  // Seed already the fill color -> nothing to fill.
  if (_within(sr, sg, sb, fR, fG, fB, 8)) return null;

  final out = Uint8List(w * h * 4); // transparent
  final visited = Uint8List(w * h);
  final stack = <int>[sy * w + sx];
  visited[sy * w + sx] = 1;

  while (stack.isNotEmpty) {
    final p = stack.removeLast();
    final idx = p * 4;
    // Only fill (and expand from) pixels close to the seed color.
    if (!_within(src[idx], src[idx + 1], src[idx + 2], sr, sg, sb, tol)) {
      continue;
    }
    out[idx] = fR;
    out[idx + 1] = fG;
    out[idx + 2] = fB;
    out[idx + 3] = fA;

    final x = p % w, y = p ~/ w;
    if (x > 0 && visited[p - 1] == 0) {
      visited[p - 1] = 1;
      stack.add(p - 1);
    }
    if (x < w - 1 && visited[p + 1] == 0) {
      visited[p + 1] = 1;
      stack.add(p + 1);
    }
    if (y > 0 && visited[p - w] == 0) {
      visited[p - w] = 1;
      stack.add(p - w);
    }
    if (y < h - 1 && visited[p + w] == 0) {
      visited[p + w] = 1;
      stack.add(p + w);
    }
  }
  return out;
}

/// True if RGB (1) and (2) are within [tol] on every channel.
bool _within(int r1, int g1, int b1, int r2, int g2, int b2, int tol) =>
    (r1 - r2).abs() <= tol && (g1 - g2).abs() <= tol && (b1 - b2).abs() <= tol;
