import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coppelia/ui/widgets/playlist_dialogs.dart';

void main() {
  testWidgets('promptPlaylistName cancel does not use disposed controller',
      (tester) async {
    final flutterErrors = <FlutterErrorDetails>[];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      flutterErrors.add(details);
    };

    addTearDown(() {
      FlutterError.onError = oldOnError;
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: _OpenDialogButton(),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Dialog is open.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);

    final disposedControllerErrors = flutterErrors.where(
      (e) => e.exceptionAsString().contains(
            'A TextEditingController was used after being disposed',
          ),
    );
    expect(disposedControllerErrors, isEmpty);
  });
}

class _OpenDialogButton extends StatelessWidget {
  const _OpenDialogButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () async {
          await promptPlaylistName(
            context,
            title: 'Rename playlist',
            initialName: 'Test',
            confirmLabel: 'Save',
          );
        },
        child: const Text('Open'),
      ),
    );
  }
}
