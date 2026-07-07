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

  IconButton undoButton(WidgetTester tester) => tester.widget<IconButton>(
      find.ancestor(
          of: find.byIcon(Icons.undo), matching: find.byType(IconButton)));
  IconButton redoButton(WidgetTester tester) => tester.widget<IconButton>(
      find.ancestor(
          of: find.byIcon(Icons.redo), matching: find.byType(IconButton)));

  testWidgets('clear asks to confirm, then empties the board', (tester) async {
    await tester.pumpWidget(const ColoringApp());

    await tester.drag(find.byType(CustomPaint).first, const Offset(40, 40));
    await tester.pump();
    expect(undoButton(tester).onPressed, isNotNull);

    // Tapping clear opens a confirmation dialog (nothing wiped yet).
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Clear picture?'), findsOneWidget);
    expect(undoButton(tester).onPressed, isNotNull);

    // Confirming wipes the board.
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();
    expect(undoButton(tester).onPressed, isNull);
  });

  testWidgets('cancelling clear keeps the drawing', (tester) async {
    await tester.pumpWidget(const ColoringApp());

    await tester.drag(find.byType(CustomPaint).first, const Offset(40, 40));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Still there.
    expect(undoButton(tester).onPressed, isNotNull);
  });

  testWidgets('starting a new stroke clears the redo stack', (tester) async {
    await tester.pumpWidget(const ColoringApp());

    // Draw, then undo -> redo becomes available.
    await tester.drag(find.byType(CustomPaint).first, const Offset(40, 40));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(redoButton(tester).onPressed, isNotNull);

    // Draw a fresh stroke -> the redo history is discarded.
    await tester.drag(find.byType(CustomPaint).first, const Offset(-30, 50));
    await tester.pump();
    expect(redoButton(tester).onPressed, isNull);
  });

  testWidgets('two fingers can draw at the same time without error',
      (tester) async {
    await tester.pumpWidget(const ColoringApp());
    final center = tester.getCenter(find.byType(CustomPaint).first);

    // Two independent pointers, interleaved — exercises the per-pointer map.
    final f1 = await tester.startGesture(center.translate(-30, 0), pointer: 1);
    final f2 = await tester.startGesture(center.translate(30, 0), pointer: 2);
    await f1.moveBy(const Offset(-20, 25));
    await f2.moveBy(const Offset(20, 25));
    await tester.pump();
    await f1.up();
    await f2.up();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(undoButton(tester).onPressed, isNotNull);
  });

  testWidgets('selecting the spray brush and drawing works', (tester) async {
    await tester.pumpWidget(const ColoringApp());

    // Pick the spray brush (blur icon), then draw.
    await tester.tap(find.byIcon(Icons.blur_on));
    await tester.pump();
    await tester.drag(find.byType(CustomPaint).first, const Offset(50, 30));
    await tester.pump();

    // Spray bakes a burst of scattered points per move — should not throw and
    // should register a stroke.
    expect(tester.takeException(), isNull);
    expect(undoButton(tester).onPressed, isNotNull);
  });

  testWidgets('custom color picker opens and adds a swatch', (tester) async {
    await tester.pumpWidget(const ColoringApp());

    // Bare circular swatches are InkResponse; count before opening the picker.
    final swatchesBefore = tester.widgetList(find.byType(InkResponse)).length;

    // The add-color button carries the plus icon.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Pick a color'), findsOneWidget);

    // Nudge the hue slider so a distinct custom color is chosen.
    await tester.drag(
      find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(Slider)).first,
      const Offset(60, 0),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Use color'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Pick a color'), findsNothing); // dialog closed
    // A new custom swatch was added to the palette.
    final swatchesAfter = tester.widgetList(find.byType(InkResponse)).length;
    expect(swatchesAfter, greaterThan(swatchesBefore));
  });
}
