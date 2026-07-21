import 'package:flutter/material.dart';

/// The app's *chrome* colors — background, toolbar, and the few semantic
/// accents.
///
/// Deliberately plainer than [kCrayonColors]: sixteen crayons are already a lot
/// of color, so the surfaces around them stay near-white and the accents are
/// reserved for state (what's selected, what worked, what's destructive).
/// Nothing here competes with the child's drawing.
class KidPalette {
  KidPalette._();

  /// The surface the paper sits on — think of a sheet laid on a colored table.
  ///
  /// Soft aqua rather than a bold primary: it's on screen the entire session
  /// and sits directly around the child's drawing, so it has to be cheerful
  /// without competing with the artwork. The white sheet reads as *paper*
  /// precisely because something colored surrounds it.
  static const table = Color(0xFFA0E7E5);

  /// Warm off-white, for surfaces that want warmth rather than pure white.
  static const background = Color(0xFFFFFDF6);

  /// Pure white. The toolbar and app bar surfaces.
  static const toolbar = Color(0xFFFFFFFF);

  /// The selected/active accent — a tool that's currently in use.
  static const primary = Color(0xFF4D96FF);

  /// The softer accent, for the "mix your own color" affordance.
  static const secondary = Color(0xFFFFD93D);

  /// Confirmation — a picture saved.
  static const success = Color(0xFF6BCB77);

  /// Destructive or failed — clearing the board, a save that didn't work.
  static const error = Color(0xFFFF6B6B);

  /// Text and outlines. Soft black, never pure #000.
  static const ink = Color(0xFF3D3D3D);

  /// Resting borders and dividers, and disabled icons.
  static const outline = Color(0xFFBDBDBD);
}

/// The sixteen crayons in the tray, in spectrum order so the row reads like a
/// real crayon box: warm → cool → neutrals.
///
/// The names are what tooltips and screen readers announce, so they're the
/// plain words a child would use, not hex or Material shade numbers.
const kCrayonColors = <(String, Color)>[
  ('Red', Color(0xFFFF5252)),
  ('Orange', Color(0xFFFF9F45)),
  ('Yellow', Color(0xFFFFD93D)),
  ('Lime', Color(0xFFB5E61D)),
  ('Green', Color(0xFF6BCB77)),
  ('Teal', Color(0xFF00C2A8)),
  ('Blue', Color(0xFF4D96FF)),
  ('Indigo', Color(0xFF5E60CE)),
  ('Purple', Color(0xFF9B5DE5)),
  ('Pink', Color(0xFFFF7EB6)),
  ('Brown', Color(0xFF8B5A2B)),
  ('Gray', Color(0xFFBDBDBD)),
  ('Black', Color(0xFF3D3D3D)),
  ('White', Color(0xFFFFFFFF)),
  ('Peach', Color(0xFFFFD6A5)),
  ('Sky', Color(0xFFA0E7E5)),
];

/// The four brush sizes a child can pick, smallest to biggest.
///
/// A slider labelled "12px" asks a five-year-old to think in pixels. Four dots
/// they can see and compare does the same job with no reading required — the
/// dot *is* the label.
const kBrushSizes = <(String, double)>[
  ('Thin', 6),
  ('Medium', 14),
  ('Thick', 26),
  ('Chunky', 40),
];
