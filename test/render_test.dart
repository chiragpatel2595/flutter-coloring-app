import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coloring_app/main.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pixel-level regression guard. The earlier shipped bug was `shouldRepaint`
/// returning false, so the canvas only redrew on a window resize — every
/// widget-state test still passed because buttons enabled correctly. These
/// tests capture the actual rendered canvas and assert the pixels change, so
/// that class of "looks wired up but nothing draws" bug can't slip through.
void main() {
  testWidgets('each stroke actually repaints the canvas', (tester) async {
    await tester.pumpWidget(const ColoringApp());

    // The keyed RepaintBoundary that wraps the canvas is the nearest
    // RepaintBoundary ancestor of the drawing CustomPaint.
    RenderRepaintBoundary boundary() =>
        tester.renderObject<RenderRepaintBoundary>(
          find
              .ancestor(
                of: find.byType(CustomPaint).first,
                matching: find.byType(RepaintBoundary),
              )
              .first,
        );

    Future<Uint8List> snapshot() async {
      final bytes = await tester.runAsync(() async {
        final image = await boundary().toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      return bytes!;
    }

    final blank = await snapshot();

    // First stroke must change pixels.
    await tester.drag(find.byType(CustomPaint).first, const Offset(80, 80));
    await tester.pump();
    final afterFirst = await snapshot();
    expect(
      listEquals(blank, afterFirst),
      isFalse,
      reason: 'the first stroke must draw something',
    );

    // A second, separate stroke must ALSO change pixels. This is precisely
    // what the broken shouldRepaint regressed: the canvas stopped repainting
    // on later strokes.
    await tester.drag(find.byType(CustomPaint).first, const Offset(-80, 60));
    await tester.pump();
    final afterSecond = await snapshot();
    expect(
      listEquals(afterFirst, afterSecond),
      isFalse,
      reason: 'a later stroke must repaint the canvas, not just the first',
    );
  });
}
