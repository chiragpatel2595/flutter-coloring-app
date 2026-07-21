import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coloring_app/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('app renders the coloring page with its tools',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ColoringApp());

    // Core tools are present. Brush size is four preset dots, not a slider.
    expect(find.byTooltip('Thin'), findsOneWidget);
    expect(find.byTooltip('Chunky'), findsOneWidget);
    expect(find.byIcon(Icons.undo), findsOneWidget);
    expect(find.byIcon(Icons.save_alt), findsOneWidget);

    // Redo is keyboard-only by design — no button on screen.
    expect(find.byIcon(Icons.redo), findsNothing);

    // The picture's name appears once, in the app bar. It used to be repeated
    // below the canvas with a "(1/9)" counter; both were cut.
    expect(find.widgetWithText(AppBar, 'Blank'), findsOneWidget);
    expect(find.textContaining('1/9'), findsNothing);
  });

  testWidgets('undo enables with strokes, and Ctrl+Shift+Z redoes',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ColoringApp());

    IconButton undoBtn() => tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(Icons.undo), matching: find.byType(IconButton)));

    // Nothing drawn yet.
    expect(undoBtn().onPressed, isNull);

    await tester.drag(find.byType(CustomPaint).first, const Offset(40, 40));
    await tester.pump();
    expect(undoBtn().onPressed, isNotNull);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(undoBtn().onPressed, isNull);

    // Redo restores the stroke — visible here as undo becoming available again.
    await pressRedo(tester);
    expect(undoBtn().onPressed, isNotNull);
  });
}
