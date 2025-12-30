// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coppelia/app.dart';

void main() {
  testWidgets('Search is accessible from sidebar', (WidgetTester tester) async {
    await tester.pumpWidget(const CoppeliaApp());
    await tester.pumpAndSettle();

    // Make the layout narrow enough that the UI is stable for the test.
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpAndSettle();

    // Tap the new sidebar Search item.
    expect(find.text('Search'), findsWidgets);
    await tester.tap(find.text('Search').first);
    await tester.pumpAndSettle();

    // Search page should always have a visible search field at the top.
    expect(find.byType(TextField), findsOneWidget);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.focusNode?.hasFocus ?? false, isTrue);
  });
}
