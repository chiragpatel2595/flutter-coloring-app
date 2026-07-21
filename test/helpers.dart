import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Presses Ctrl+Shift+Z.
///
/// There is deliberately no redo *button* — redo needs a history-stack mental
/// model a small child doesn't have, and it sat disabled most of the time — so
/// the keyboard is the only way to reach redo, and the only way to test it.
Future<void> pressRedo(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}
