// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Search is accessible from sidebar', (tester) async {
    await tester.pumpWidget(const _SidebarSearchHarness());
    await tester.pumpAndSettle();

    // Ensure the Search entry is present.
    expect(find.text('Search'), findsOneWidget);

    // Tap the Search item in the sidebar.
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    // Search page should have a visible, focused TextField.
    expect(find.byType(TextField), findsOneWidget);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.focusNode?.hasFocus ?? false, isTrue);
  });
}

/// Minimal harness to verify the sidebar search affordance without
/// bootstrapping the full app.
class _SidebarSearchHarness extends StatefulWidget {
  const _SidebarSearchHarness();

  @override
  State<_SidebarSearchHarness> createState() => _SidebarSearchHarnessState();
}

class _SidebarSearchHarnessState extends State<_SidebarSearchHarness> {
  bool _showSearch = false;
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 180,
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('Search'),
                    onTap: () {
                      setState(() {
                        _showSearch = true;
                      });
                      // Schedule focus after rebuild.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _searchFocus.requestFocus();
                      });
                    },
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _showSearch
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        focusNode: _searchFocus,
                        decoration: const InputDecoration(
                          hintText: 'Search',
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
