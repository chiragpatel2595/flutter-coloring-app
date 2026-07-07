import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

// ---------------------------------------------------------------------------
// Outline templates. Each strokes a simple, recognizable shape scaled into a
// centered box, so the same picture works on any screen size.
// ---------------------------------------------------------------------------

/// The pictures you can color. Vector outlines keep the app package- and
/// asset-free; add more templates by writing another drawer below and adding
/// it to this list.
const List<ColoringTemplate> kTemplates = [
  ColoringTemplate('Blank', null),
  ColoringTemplate('Fish', drawFish),
  ColoringTemplate('Flower', drawFlower),
  ColoringTemplate('House', drawHouse),
  ColoringTemplate('Star', drawStar),
];

Paint _outlinePaint() => Paint()
  ..color = Colors.black
  ..style = PaintingStyle.stroke
  ..strokeWidth = 4
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// A centered square box covering ~70% of the smaller dimension.
Rect _box(Size size) {
  final side = math.min(size.width, size.height) * 0.7;
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: side,
    height: side,
  );
}

void drawFish(Canvas canvas, Size size) {
  final p = _outlinePaint();
  final b = _box(size);
  final cy = b.center.dy;
  final body = Rect.fromCenter(
      center: b.center, width: b.width * 0.8, height: b.height * 0.5);
  canvas.drawOval(body, p);
  // tail fin
  final tail = Path()
    ..moveTo(body.right - 2, cy)
    ..lineTo(b.right, cy - b.height * 0.18)
    ..lineTo(b.right, cy + b.height * 0.18)
    ..close();
  canvas.drawPath(tail, p);
  // eye
  canvas.drawCircle(
      Offset(body.left + b.width * 0.18, cy - b.height * 0.06), b.width * 0.03, p);
}

void drawFlower(Canvas canvas, Size size) {
  final p = _outlinePaint();
  final b = _box(size);
  final c = Offset(b.center.dx, b.top + b.height * 0.3);
  final petalR = b.width * 0.12;
  final ringR = b.width * 0.2;
  for (var i = 0; i < 6; i++) {
    final a = i * math.pi / 3;
    canvas.drawCircle(
        Offset(c.dx + ringR * math.cos(a), c.dy + ringR * math.sin(a)), petalR, p);
  }
  canvas.drawCircle(c, petalR, p); // flower center
  // stem + leaf
  canvas.drawLine(Offset(c.dx, c.dy + ringR + petalR), Offset(c.dx, b.bottom), p);
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(c.dx + b.width * 0.1, b.bottom - b.height * 0.15),
      width: b.width * 0.18,
      height: b.height * 0.08,
    ),
    p,
  );
}

void drawHouse(Canvas canvas, Size size) {
  final p = _outlinePaint();
  final b = _box(size);
  final wallTop = b.top + b.height * 0.4;
  final wall = Rect.fromLTRB(
      b.left + b.width * 0.1, wallTop, b.right - b.width * 0.1, b.bottom);
  canvas.drawRect(wall, p);
  // roof
  final roof = Path()
    ..moveTo(wall.left - b.width * 0.05, wallTop)
    ..lineTo(b.center.dx, b.top)
    ..lineTo(wall.right + b.width * 0.05, wallTop)
    ..close();
  canvas.drawPath(roof, p);
  // door
  canvas.drawRect(
    Rect.fromLTWH(b.center.dx - b.width * 0.08, b.bottom - b.height * 0.22,
        b.width * 0.16, b.height * 0.22),
    p,
  );
  // window
  canvas.drawRect(
    Rect.fromLTWH(wall.left + b.width * 0.08, wallTop + b.height * 0.06,
        b.width * 0.14, b.height * 0.12),
    p,
  );
}

void drawStar(Canvas canvas, Size size) {
  final p = _outlinePaint();
  final b = _box(size);
  final c = b.center;
  final outer = b.width / 2;
  final inner = outer * 0.4;
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? outer : inner;
    final angle = -math.pi / 2 + i * math.pi / 5;
    final pt = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
    if (i == 0) {
      path.moveTo(pt.dx, pt.dy);
    } else {
      path.lineTo(pt.dx, pt.dy);
    }
  }
  path.close();
  canvas.drawPath(path, p);
}
