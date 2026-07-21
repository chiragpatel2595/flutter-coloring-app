import 'package:flutter/material.dart';

/// The app's *chrome* colors — the toolbar, tray, and outlines.
///
/// Deliberately quiet and warm: the crayons the child picks are the only loud
/// thing on screen, so everything around them stays out of the way. Nothing
/// here is pure black or pure grey — a coloring app should feel like paper and
/// cardboard, not like a settings screen.
class KidPalette {
  KidPalette._();

  /// Warm sugar-paper. The toolbar and app background.
  static const paper = Color(0xFFFFF6E9);

  /// Cardboard — the tray the crayons stand in.
  static const kraft = Color(0xFFE0B072);

  /// A slightly deeper cardboard for the tray's front lip.
  static const kraftDark = Color(0xFFC98F52);

  /// Soft dark brown for text and outlines. Reads as drawn rather than printed.
  static const cocoa = Color(0xFF4A3428);

  /// Cocoa at low opacity, for resting (unselected) outlines.
  static const cocoaSoft = Color(0x334A3428);
}

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
