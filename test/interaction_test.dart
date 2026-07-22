import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coloring_app/coloring_page.dart';
import 'package:coloring_app/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('shows a single picture with no page navigation', (tester) async {
    await tester.pumpWidget(const ColoringApp());

    // One picture, and the app bar greets rather than names it.
    expect(find.widgetWithText(AppBar, kAppTitle), findsOneWidget);

    // Page navigation is switched off for now, so neither arrow exists. They
    // used to sit at the ends of the crayon tray, where they read as "scroll
    // the crayons" rather than "change the picture".
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('tapping a color swatch and the eraser does not throw', (
    tester,
  ) async {
    await tester.pumpWidget(const ColoringApp());

    // The eraser is the circle carrying the cleaning-services icon.
    await tester.tap(find.byIcon(Icons.cleaning_services));
    await tester.pump();

    // Drag with the eraser active — should not throw.
    await tester.drag(find.byType(CustomPaint).first, const Offset(30, 30));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('picking a brush size selects it', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const ColoringApp());

    void expectSelected(String label, {required bool selected}) => expect(
      tester.getSemantics(find.bySemanticsLabel(label)),
      isSemantics(isSelected: selected),
    );

    // "Medium" is the default size.
    expectSelected('Medium brush', selected: true);
    expectSelected('Chunky brush', selected: false);

    await tester.tap(find.byTooltip('Chunky'));
    await tester.pumpAndSettle();

    expectSelected('Chunky brush', selected: true);
    expectSelected('Medium brush', selected: false);

    // The new size must actually draw without error.
    await tester.drag(find.byType(CustomPaint).first, const Offset(40, 40));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });

  IconButton undoButton(WidgetTester tester) => tester.widget<IconButton>(
    find.ancestor(
      of: find.byIcon(Icons.undo),
      matching: find.byType(IconButton),
    ),
  );

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

    // Draw stroke A, then undo it — A is now sitting in the redo pile.
    await tester.drag(find.byType(CustomPaint).first, const Offset(40, 40));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();

    // Draw a fresh stroke B, which must discard that redo history.
    await tester.drag(find.byType(CustomPaint).first, const Offset(-30, 50));
    await tester.pump();

    // With no redo button to read, prove it by behaviour: redo must restore
    // nothing, so undoing once should empty the board. If A had wrongly
    // survived, the board would hold [B, A] and undo would still be enabled.
    await pressRedo(tester);
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(undoButton(tester).onPressed, isNull);
  });

  testWidgets('two fingers can draw at the same time without error', (
    tester,
  ) async {
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

  testWidgets('paint bucket tool can be selected', (tester) async {
    await tester.pumpWidget(const ColoringApp());
    await tester.tap(find.byIcon(Icons.format_color_fill));
    await tester.pump();
    // Selecting the bucket clears the brush-segment selection and doesn't throw.
    expect(tester.takeException(), isNull);
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
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Slider),
          )
          .first,
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
