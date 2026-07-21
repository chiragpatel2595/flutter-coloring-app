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
///
/// ## Soft edges
///
/// Strokes are drawn anti-aliased, so a stroke's edge isn't a clean red/white
/// step — it's a 1–2px band of in-between pixels. Those are too far from white
/// to pass [tol], but too pale to look like the stroke, so a plain flood fill
/// leaves a pale halo tracing every stroke.
///
/// After the fill, [edgePasses] extra rings are added: an unfilled pixel joins
/// if it touches the region *and* is within the looser [edgeTol] of the seed.
/// That swallows the anti-aliased band and tucks the fill under the stroke.
///
/// Crucially the test is against the **seed color**, not the neighbor, so this
/// can't walk through a barrier however many passes run: solid black or solid
/// red is nowhere near white, fails [edgeTol], and stops the growth dead.
Uint8List? floodFill(
  Uint8List src,
  int w,
  int h,
  int sx,
  int sy,
  int fillArgb,
  int tol, {
  int edgeTol = 160,
  int edgePasses = 2,
}) {
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
  final filled = Uint8List(w * h);
  final stack = <int>[sy * w + sx];
  visited[sy * w + sx] = 1;

  void paint(int p) {
    final idx = p * 4;
    out[idx] = fR;
    out[idx + 1] = fG;
    out[idx + 2] = fB;
    out[idx + 3] = fA;
    filled[p] = 1;
  }

  while (stack.isNotEmpty) {
    final p = stack.removeLast();
    final idx = p * 4;
    // Only fill (and expand from) pixels close to the seed color.
    if (!_within(src[idx], src[idx + 1], src[idx + 2], sr, sg, sb, tol)) {
      continue;
    }
    paint(p);

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

  // Soft edges: grow into the anti-aliased band around the region. See the doc
  // comment — each ring is collected fully before being painted, so a pixel
  // added this pass can't seed further growth until the next one.
  for (var pass = 0; pass < edgePasses; pass++) {
    final ring = <int>[];
    for (var p = 0; p < w * h; p++) {
      if (filled[p] != 0) continue;
      final x = p % w, y = p ~/ w;
      final touches =
          (x > 0 && filled[p - 1] != 0) ||
          (x < w - 1 && filled[p + 1] != 0) ||
          (y > 0 && filled[p - w] != 0) ||
          (y < h - 1 && filled[p + w] != 0);
      if (!touches) continue;
      final idx = p * 4;
      if (_within(src[idx], src[idx + 1], src[idx + 2], sr, sg, sb, edgeTol)) {
        ring.add(p);
      }
    }
    if (ring.isEmpty) break;
    for (final p in ring) {
      paint(p);
    }
  }
  return out;
}

/// True if RGB (1) and (2) are within [tol] on every channel.
bool _within(int r1, int g1, int b1, int r2, int g2, int b2, int tol) =>
    (r1 - r2).abs() <= tol && (g1 - g2).abs() <= tol && (b1 - b2).abs() <= tol;
