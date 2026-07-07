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
      final paint = Paint()
        ..color = s.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = s.width
        ..style = PaintingStyle.stroke
        ..blendMode = s.erase ? BlendMode.clear : BlendMode.srcOver;

      // Points are stored normalized (0..1); scale them back to pixels for
      // the current canvas size.
      final pts = [
        for (final p in s.points) Offset(p.dx * size.width, p.dy * size.height)
      ];
      if (pts.length == 1) {
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

  @override
  // Strokes are mutated in place (same list instance) as you draw, so we can't
  // detect changes by reference — always repaint. See the caching idea in
  // CLAUDE.md's next steps if this ever gets expensive.
  bool shouldRepaint(CanvasPainter old) => true;
}
