import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coloring_app/main.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the "pop" animation that plays when a stroke is finished: the stroke
/// briefly swells, then settles back to its stored width.
///
/// A screenshot can't catch a 320ms animation reliably, so this drives the
/// clock by hand — pumping to the midpoint and to the end — and compares the
/// rendered pixels. It would fail if the animation never ran, never finished,
/// or left the stroke permanently fatter.
void main() {
  RenderRepaintBoundary boundary(WidgetTester tester) =>
      tester.renderObject<RenderRepaintBoundary>(find
          .ancestor(
            of: find.byType(CustomPaint).first,
            matching: find.byType(RepaintBoundary),
          )
          .first);

  Future<Uint8List> snapshot(WidgetTester tester) async {
    final bytes = await tester.runAsync(() async {
      final image = await boundary(tester).toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    return bytes!;
  }

  testWidgets('a finished stroke pops, then settles back', (tester) async {
    await tester.pumpWidget(const ColoringApp());

    // drag() ends with a pointer-up, which is what starts the pop.
    await tester.drag(find.byType(CustomPaint).first, const Offset(80, 80));

    // The ticker doesn't start counting until the first frame after forward(),
    // so this pump is frame 0 (popT == 0). Without it the "midpoint" pump below
    // would land on popT == 0, where the stroke is still its normal width.
    await tester.pump();

    // ~halfway through the 320ms pop: popT == 0.5, the stroke is at its widest.
    await tester.pump(const Duration(milliseconds: 160));
    final midPop = await snapshot(tester);

    // Past the end: the controller has completed and the stroke is back to its
    // normal width.
    await tester.pump(const Duration(milliseconds: 400));
    final settled = await snapshot(tester);

    expect(listEquals(midPop, settled), isFalse,
        reason: 'the stroke should be visibly wider mid-pop than once settled');

    // The animation must actually stop — pumping further changes nothing.
    await tester.pump(const Duration(milliseconds: 400));
    final stillSettled = await snapshot(tester);
    expect(listEquals(settled, stillSettled), isTrue,
        reason: 'the pop should finish, not keep animating forever');
  });

  testWidgets('erasing does not pop', (tester) async {
    await tester.pumpWidget(const ColoringApp());

    // Draw something to erase, and let its own pop finish first.
    await tester.drag(find.byType(CustomPaint).first, const Offset(80, 80));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Eraser'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomPaint).first, const Offset(40, 40));

    // With no pop running, the frame right after the erase and the frame a
    // full animation-length later are identical.
    await tester.pump(const Duration(milliseconds: 160));
    final justAfter = await snapshot(tester);
    await tester.pump(const Duration(milliseconds: 400));
    final later = await snapshot(tester);

    expect(listEquals(justAfter, later), isTrue,
        reason: 'an eraser stroke should not animate');
  });
}
