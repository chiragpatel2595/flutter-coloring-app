import 'package:flutter/material.dart';

/// One continuous finger/mouse stroke: a color, a width, whether it erases,
/// and the points it covers.
///
/// Points are stored *normalized* to the canvas size — each is a fraction in
/// 0..1 of the width/height at draw time. That way, when the window resizes
/// the strokes scale with the canvas (and stay put over the outline) instead
/// of being pinned to stale pixel coordinates.
class Stroke {
  final Color color;
  final double width;
  final bool erase;
  final List<Offset> points;
  Stroke({
    required this.color,
    required this.width,
    required this.erase,
    required this.points,
  });
}

/// The signature for a function that strokes a template's outline onto the
/// canvas. A null drawer (see [ColoringTemplate]) means a blank page.
typedef OutlineDrawer = void Function(Canvas canvas, Size size);

/// A coloring picture: a name plus an optional outline to draw as the
/// (non-erasable) background. A null [drawOutline] means a blank canvas.
class ColoringTemplate {
  final String name;
  final OutlineDrawer? drawOutline;
  const ColoringTemplate(this.name, this.drawOutline);
}

/// The strokes (and redo history) for a single picture. Each template gets
/// its own board so switching pictures keeps their artwork.
class Artboard {
  final List<Stroke> strokes = [];
  final List<Stroke> redo = [];
}
