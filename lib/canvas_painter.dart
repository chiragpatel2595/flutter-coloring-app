import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'models.dart';

/// Paints a picture: white background → template outline → the user's layers
/// (strokes and paint-bucket fills, in draw order).
///
/// The layers go into their own `saveLayer` so the eraser can use
/// `BlendMode.clear` to punch real holes back to the outline/background,
/// rather than the old trick of painting white over the top.
class CanvasPainter extends CustomPainter {
  final List<Layer> layers;
  final ColoringTemplate template;

  /// The stroke that just finished, if one is currently playing its "pop"
  /// animation, and how far through that animation we are (0 → 1). The pop is
  /// purely visual: it scales the drawn width, and never touches the stored
  /// [Stroke], so undo/redo and saving are unaffected.
  final Stroke? popStroke;
  final double popT;

  CanvasPainter(this.layers, this.template, {this.popStroke, this.popT = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;

    // Opaque white background.
    canvas.drawRect(bounds, Paint()..color = Colors.white);

    // Outline goes *under* the user's paint layer so the eraser reveals it
    // instead of wiping it out.
    template.drawOutline?.call(canvas, size);

    canvas.saveLayer(bounds, Paint());
    for (final layer in layers) {
      switch (layer) {
        case Stroke s:
          _drawStroke(canvas, size, s);
        case Fill f:
          // Baked pixels — stretch the fill image to the current canvas size.
          canvas.drawImageRect(
            f.image,
            Rect.fromLTWH(
              0,
              0,
              f.image.width.toDouble(),
              f.image.height.toDouble(),
            ),
            bounds,
            Paint(),
          );
      }
    }
    canvas.restore();
  }

  void _drawStroke(Canvas canvas, Size size, Stroke s) {
    // Points are stored normalized (0..1); scale them back to pixels for the
    // current canvas size.
    final pts = [
      for (final p in s.points) Offset(p.dx * size.width, p.dy * size.height),
    ];
    final paint = _paintFor(s, _popScale(s));

    // Spray is a cloud of baked dots; every other brush is a line/dot.
    if (!s.erase && s.type == BrushType.spray) {
      canvas.drawPoints(ui.PointMode.points, pts, paint);
    } else if (pts.length == 1) {
      // a single tap -> draw a dot
      canvas.drawPoints(ui.PointMode.points, pts, paint);
    } else {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  /// How much wider to draw [s] right now — 1.0 is its normal width.
  ///
  /// Only the just-finished stroke pops. `sin` over one and a half turns
  /// wobbles fat → thin → fat, and multiplying by `(1 - t)` damps that wobble
  /// down to nothing, so the stroke springs like rubber and settles at exactly
  /// 1.0. (A plain half-turn `sin` gives one smooth swell — correct, but far
  /// too polite for a children's app.)
  double _popScale(Stroke s) {
    if (!identical(s, popStroke)) return 1;
    final t = popT.clamp(0.0, 1.0);
    final wobble = math.sin(t * math.pi * 3) * (1 - t);
    return 1 + 0.5 * wobble;
  }

  /// Builds the [Paint] for a stroke based on its brush type, widened by
  /// [scale] for the pop animation. The eraser (`s.erase`) always wins — it
  /// punches through with `BlendMode.clear` regardless of brush.
  Paint _paintFor(Stroke s, double scale) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = s.width * scale
      ..style = PaintingStyle.stroke;

    if (s.erase) {
      return paint
        ..color = s.color
        ..blendMode = BlendMode.clear;
    }

    switch (s.type) {
      case BrushType.pen:
        paint.color = s.color;
      case BrushType.marker:
        // Semi-transparent with a flat cap, so it reads like a felt marker.
        paint
          ..color = s.color.withValues(alpha: 0.55)
          ..strokeCap = StrokeCap.square;
      case BrushType.highlighter:
        // Very transparent + flat: classic see-through highlighter.
        paint
          ..color = s.color.withValues(alpha: 0.30)
          ..strokeCap = StrokeCap.butt;
      case BrushType.spray:
        // Baked dots; low alpha so overlapping dots build up density. The
        // dot size is a fraction of the brush (which sets the scatter radius).
        paint
          ..color = s.color.withValues(alpha: 0.45)
          ..strokeWidth = (s.width * 0.22).clamp(2.0, 12.0) * scale;
    }
    return paint;
  }

  @override
  // Strokes are mutated in place (same list instance) as you draw, so we can't
  // detect changes by reference — always repaint. See the caching idea in
  // CLAUDE.md's next steps if this ever gets expensive.
  bool shouldRepaint(CanvasPainter old) => true;
}
