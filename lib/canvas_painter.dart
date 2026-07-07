import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'models.dart';

/// Paints a picture: white background → template outline → the user's strokes.
///
/// The strokes go into their own `saveLayer` so the eraser can use
/// `BlendMode.clear` to punch real holes back to the outline/background,
/// rather than the old trick of painting white over the top.
class CanvasPainter extends CustomPainter {
  final List<Stroke> strokes;
  final ColoringTemplate template;
  CanvasPainter(this.strokes, this.template);

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;

    // Opaque white background.
    canvas.drawRect(bounds, Paint()..color = Colors.white);

    // Outline goes *under* the user's paint layer so the eraser reveals it
    // instead of wiping it out.
    template.drawOutline?.call(canvas, size);

    canvas.saveLayer(bounds, Paint());
    for (final s in strokes) {
      // Points are stored normalized (0..1); scale them back to pixels for
      // the current canvas size.
      final pts = [
        for (final p in s.points) Offset(p.dx * size.width, p.dy * size.height)
      ];
      final paint = _paintFor(s);

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
    canvas.restore();
  }

  /// Builds the [Paint] for a stroke based on its brush type. The eraser
  /// (`s.erase`) always wins — it punches through with `BlendMode.clear`
  /// regardless of brush.
  Paint _paintFor(Stroke s) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = s.width
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
          ..strokeWidth = (s.width * 0.22).clamp(2.0, 12.0);
    }
    return paint;
  }

  @override
  // Strokes are mutated in place (same list instance) as you draw, so we can't
  // detect changes by reference — always repaint. See the caching idea in
  // CLAUDE.md's next steps if this ever gets expensive.
  bool shouldRepaint(CanvasPainter old) => true;
}
