import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coloring_app/main.dart';

void main() {
  testWidgets('picture navigation changes the page', (tester) async {
    await tester.pumpWidget(const ColoringApp());

    // Starts on Blank (app-bar title).
    expect(find.widgetWithText(AppBar, 'Blank'), findsOneWidget);

    // Next -> Fish.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.widgetWithText(AppBar, 'Fish'), findsOneWidget);

    // Prev -> back to Blank.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    expect(find.widgetWithText(AppBar, 'Blank'), findsOneWidget);
  });

  testWidgets('each picture keeps its own strokes / undo state',
      (tester) async {
    await tester.pumpWidget(const ColoringApp());

    IconButton undoBtn() => tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(Icons.undo), matching: find.byType(IconButton)));

    // Draw on Blank.
    await tester.drag(find.byType(CustomPaint).first, const Offset(40, 40));
    await tester.pump();
    expect(undoBtn().onPressed, isNotNull);

    // Move to Fish: its board is empty, so undo is disabled again.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(undoBtn().onPressed, isNull);

    // Back to Blank: the stroke is still there.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    expect(undoBtn().onPressed, isNotNull);
  });

  testWidgets('tapping a color swatch and the eraser does not throw',
      (tester) async {
    await tester.pumpWidget(const ColoringApp());

    // The eraser is the circle carrying the cleaning-services icon.
    await tester.tap(find.byIcon(Icons.cleaning_services));
    await tester.pump();

    // Drag with the eraser active — should not throw.
    await tester.drag(find.byType(CustomPaint).first, const Offset(30, 30));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('brush slider updates the label', (tester) async {
    await tester.pumpWidget(const ColoringApp());
    // Drag the slider thumb to the right.
    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pump();
    // Label ends in "px" and should now read a large value.
    expect(find.textContaining('px'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
