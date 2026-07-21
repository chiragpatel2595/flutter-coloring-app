import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

// ---------------------------------------------------------------------------
// Outline templates. Each strokes a simple, recognizable shape scaled into a
// centered box, so the same picture works on any screen size.
// ---------------------------------------------------------------------------

/// The one picture the app currently shows.
///
/// Page navigation is switched off for now, so the app opens straight onto
/// this. The rest of [kTemplates] is deliberately left intact — bringing the
/// pager back means wiring up navigation again, not rewriting the outlines.
/// Point this at another entry to change which picture you get.
ColoringTemplate get kActiveTemplate => kTemplates.first;

/// The pictures you can color. Vector outlines keep the app package- and
/// asset-free; add more templates by writing another drawer below and adding
/// it to this list.
const List<ColoringTemplate> kTemplates = [
  ColoringTemplate('Blank', null),
  ColoringTemplate('Fish', drawFish),
  ColoringTemplate('Flower', drawFlower),
  ColoringTemplate('House', drawHouse),
  ColoringTemplate('Star', drawStar),
  ColoringTemplate('Heart', drawHeart),
  ColoringTemplate('Sun', drawSun),
  ColoringTemplate('Tree', drawTree),
  ColoringTemplate('Car', drawCar),
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
    center: b.center,
    width: b.width * 0.8,
    height: b.height * 0.5,
  );
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
    Offset(body.left + b.width * 0.18, cy - b.height * 0.06),
    b.width * 0.03,
    p,
  );
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
      Offset(c.dx + ringR * math.cos(a), c.dy + ringR * math.sin(a)),
      petalR,
      p,
    );
  }
  canvas.drawCircle(c, petalR, p); // flower center
  // stem + leaf
  canvas.drawLine(
    Offset(c.dx, c.dy + ringR + petalR),
    Offset(c.dx, b.bottom),
    p,
  );
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
    b.left + b.width * 0.1,
    wallTop,
    b.right - b.width * 0.1,
    b.bottom,
  );
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
    Rect.fromLTWH(
      b.center.dx - b.width * 0.08,
      b.bottom - b.height * 0.22,
      b.width * 0.16,
      b.height * 0.22,
    ),
    p,
  );
  // window
  canvas.drawRect(
    Rect.fromLTWH(
      wall.left + b.width * 0.08,
      wallTop + b.height * 0.06,
      b.width * 0.14,
      b.height * 0.12,
    ),
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

void drawHeart(Canvas canvas, Size size) {
  final p = _outlinePaint();
  final b = _box(size);
  final cx = b.center.dx;
  final topY = b.top + b.height * 0.32;
  final bottomY = b.bottom - b.height * 0.08;
  final path = Path()
    ..moveTo(cx, bottomY)
    // left lobe
    ..cubicTo(b.left, b.center.dy, b.left + b.width * 0.05, b.top, cx, topY)
    // right lobe
    ..cubicTo(
      b.right - b.width * 0.05,
      b.top,
      b.right,
      b.center.dy,
      cx,
      bottomY,
    )
    ..close();
  canvas.drawPath(path, p);
}

void drawSun(Canvas canvas, Size size) {
  final p = _outlinePaint();
  final b = _box(size);
  final c = b.center;
  final r = b.width * 0.22;
  canvas.drawCircle(c, r, p);
  // rays
  for (var i = 0; i < 12; i++) {
    final a = i * math.pi / 6;
    final dir = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(c + dir * (r * 1.3), c + dir * (r * 1.8), p);
  }
}

void drawTree(Canvas canvas, Size size) {
  final p = _outlinePaint();
  final b = _box(size);
  final cx = b.center.dx;
  // trunk
  final trunkW = b.width * 0.14;
  canvas.drawRect(
    Rect.fromLTWH(cx - trunkW / 2, b.center.dy, trunkW, b.bottom - b.center.dy),
    p,
  );
  // foliage
  canvas.drawCircle(Offset(cx, b.top + b.height * 0.32), b.width * 0.28, p);
}

void drawCar(Canvas canvas, Size size) {
  final p = _outlinePaint();
  final b = _box(size);
  final bodyTop = b.center.dy;
  final bodyBottom = b.center.dy + b.height * 0.2;
  // body
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTRB(b.left, bodyTop, b.right, bodyBottom),
      const Radius.circular(10),
    ),
    p,
  );
  // roof / cabin
  final roof = Path()
    ..moveTo(b.left + b.width * 0.25, bodyTop)
    ..lineTo(b.left + b.width * 0.36, b.top + b.height * 0.28)
    ..lineTo(b.left + b.width * 0.64, b.top + b.height * 0.28)
    ..lineTo(b.left + b.width * 0.75, bodyTop);
  canvas.drawPath(roof, p);
  // wheels
  final wheelR = b.width * 0.09;
  canvas.drawCircle(Offset(b.left + b.width * 0.28, bodyBottom), wheelR, p);
  canvas.drawCircle(Offset(b.left + b.width * 0.72, bodyBottom), wheelR, p);
}
