import 'package:flutter/material.dart';

/// The kind of brush a [Stroke] was drawn with. Each renders differently in
/// `CanvasPainter` (see there for the exact paint used):
/// - [pen]: solid, opaque line.
/// - [marker]: semi-transparent flat line that layers where it overlaps.
/// - [highlighter]: very transparent, wide, flat line.
/// - [spray]: an airbrush — scattered dots that build up density.
enum BrushType { pen, marker, highlighter, spray }

/// One continuous finger/mouse stroke: a brush type, a color, a width, whether
/// it erases, and the points it covers.
///
/// Points are stored *normalized* to the canvas size — each is a fraction in
/// 0..1 of the width/height at draw time. That way, when the window resizes
/// the strokes scale with the canvas (and stay put over the outline) instead
/// of being pinned to stale pixel coordinates.
///
/// For [BrushType.spray] the points are pre-scattered at draw time (baked), so
/// the airbrush stays stable across repaints instead of shimmering.
class Stroke {
  final BrushType type;
  final Color color;
  final double width;
  final bool erase;
  final List<Offset> points;
  Stroke({
    required this.type,
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
