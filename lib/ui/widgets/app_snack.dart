import 'package:flutter/material.dart';

/// Shows a standard snack bar message.
void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

/// Runs an async action and shows any error message in a snack bar.
Future<void> runWithSnack(
  BuildContext context,
  Future<String?> Function() action,
) async {
  final error = await action();
  if (error != null && context.mounted) {
    showAppSnack(context, error);
  }
}
