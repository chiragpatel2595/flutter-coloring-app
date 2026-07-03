import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coloring_app/main.dart';

void main() {
  testWidgets('app renders the coloring page with its tools',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ColoringApp());

    // Core tools are present.
    expect(find.byType(Slider), findsOneWidget); // brush size
    expect(find.byIcon(Icons.undo), findsOneWidget);
    expect(find.byIcon(Icons.redo), findsOneWidget);
    expect(find.byIcon(Icons.save_alt), findsOneWidget);

    // Starts on the first ('Blank') picture.
    expect(find.textContaining('Blank'), findsWidgets);
  });

  testWidgets('undo/redo enable and disable as strokes are drawn',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ColoringApp());

    IconButton undoBtn() => tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(Icons.undo), matching: find.byType(IconButton)));
    IconButton redoBtn() => tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(Icons.redo), matching: find.byType(IconButton)));

    // Nothing drawn yet: both disabled.
    expect(undoBtn().onPressed, isNull);
    expect(redoBtn().onPressed, isNull);

    // Draw a stroke on the canvas.
    await tester.drag(find.byType(CustomPaint).first, const Offset(40, 40));
    await tester.pump();

    // Undo is now available, redo still empty.
    expect(undoBtn().onPressed, isNotNull);
    expect(redoBtn().onPressed, isNull);

    // Undo -> redo becomes available.
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(undoBtn().onPressed, isNull);
    expect(redoBtn().onPressed, isNotNull);
  });
}
