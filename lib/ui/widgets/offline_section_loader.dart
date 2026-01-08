import 'package:flutter/material.dart';

import 'offline_empty_view.dart';

/// Reusable loader + empty-state wrapper for offline sections.
class OfflineSectionLoader<T> extends StatelessWidget {
  const OfflineSectionLoader({
    super.key,
    required this.future,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.builder,
  });

  final Future<List<T>> future;
  final String emptyTitle;
  final String emptySubtitle;
  final Widget Function(BuildContext context, List<T> items) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? <T>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return OfflineEmptyView(
            title: emptyTitle,
            subtitle: emptySubtitle,
          );
        }
        return builder(context, items);
      },
    );
  }
}
