import 'package:flutter/material.dart';

import 'kid_palette.dart';

/// A single crayon in the palette tray.
///
/// Picking a color is the most-used action in the app, so it gets the most
/// personality: the chosen crayon slides up out of the tray and tilts, the way
/// you'd pull one out of a real box. That "which one am I holding?" question is
/// answered by position and angle rather than by a thin selection ring, which
/// is much easier to read at a glance — especially for a child.
class Crayon extends StatelessWidget {
  /// Standing size of one crayon. Comfortably past the 48px minimum touch
  /// target once the surrounding padding is counted.
  static const width = 40.0;
  static const height = 76.0;

  /// How far the chosen crayon rises, as a fraction of [height].
  static const _liftFraction = 0.18;

  /// Blank space reserved *above* each crayon for it to rise into.
  ///
  /// Without this the crayon would animate outside its own bounds and get
  /// clipped by the scrolling tray — the lifted crayon would lose its tip.
  /// The few extra pixels past the lift leave room for the tilt's corners.
  static const liftRoom = height * _liftFraction + 5;

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const Crayon({
    super.key,
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: name,
      child: Semantics(
        button: true,
        selected: selected,
        label: '$name crayon',
        child: InkResponse(
          onTap: onTap,
          radius: width,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: SizedBox(
              width: width,
              height: height + liftRoom,
              // The crayon rests on the tray floor and rises into the space
              // reserved above it.
              child: Align(
                alignment: Alignment.bottomCenter,
                // elasticOut overshoots and springs back, so the crayon doesn't
                // just move — it hops. Curves.easeOut would feel like a menu.
                child: AnimatedSlide(
                  offset:
                      selected ? const Offset(0, -_liftFraction) : Offset.zero,
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.elasticOut,
                  child: AnimatedRotation(
                    turns: selected ? -0.018 : 0, // a slight hand-held tilt
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.elasticOut,
                    child: CustomPaint(
                      size: const Size(width, height),
                      painter: _CrayonPainter(color),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws one crayon: a waxy cone on top, a body, and a paper wrapper with two
/// stripes across the middle.
class _CrayonPainter extends CustomPainter {
  final Color color;
  const _CrayonPainter(this.color);

  /// Nudges [c] lighter or darker by [delta] in HSL space.
  ///
  /// Shifting lightness (rather than blending toward white/black) keeps the
  /// hue intact, so a red crayon's wrapper still reads as red.
  Color _shade(Color c, double delta) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final tipH = h * 0.18;

    // Dark colors need a *lighter* wrapper to stay visible, light colors need a
    // darker one — so pick the direction from the color itself.
    final isDark = HSLColor.fromColor(color).lightness <= 0.5;
    final wrapColor = _shade(color, isDark ? 0.16 : -0.15);
    final stripeColor = _shade(color, isDark ? 0.32 : 0.22);

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..color = KidPalette.cocoa;

    // ---- body (below the tip) ----
    final body = RRect.fromRectAndCorners(
      Rect.fromLTRB(0, tipH * 0.9, w, h),
      bottomLeft: Radius.circular(w * 0.22),
      bottomRight: Radius.circular(w * 0.22),
    );
    canvas.drawRRect(body, Paint()..color = color);

    // ---- paper wrapper ----
    final wrap = Rect.fromLTRB(0, h * 0.30, w, h * 0.94);
    canvas.save();
    canvas.clipRRect(body); // keep the wrapper inside the body's rounded base
    canvas.drawRect(wrap, Paint()..color = wrapColor);
    // two stripes, near the wrapper's top and bottom edges
    for (final y in [h * 0.35, h * 0.87]) {
      canvas.drawRect(
        Rect.fromLTRB(0, y, w, y + h * 0.03),
        Paint()..color = stripeColor,
      );
    }
    canvas.restore();

    // ---- waxy tip ----
    final tip = Path()
      ..moveTo(0, tipH)
      ..lineTo(w * 0.36, h * 0.03)
      ..quadraticBezierTo(w * 0.5, 0, w * 0.64, h * 0.03)
      ..lineTo(w, tipH)
      ..close();
    canvas.drawPath(tip, Paint()..color = color);

    // ---- outlines, drawn last so they sit on top ----
    canvas.drawRRect(body, outline);
    canvas.drawPath(tip, outline);
    canvas.drawLine(Offset(0, wrap.top), Offset(w, wrap.top), outline);
  }

  @override
  bool shouldRepaint(_CrayonPainter old) => old.color != color;
}
