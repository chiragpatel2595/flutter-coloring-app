import 'package:flutter_test/flutter_test.dart';

import 'package:coloring_app/main.dart';

void main() {
  testWidgets('app renders the coloring page', (WidgetTester tester) async {
    await tester.pumpWidget(const ColoringApp());
    expect(find.text('Coloring Practice'), findsOneWidget);
  });
}
