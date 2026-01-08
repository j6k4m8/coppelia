import 'package:flutter/material.dart';

import '../../state/library_view.dart';
import 'library_browse_view.dart';
import 'offline_section_loader.dart';

/// Shared offline loader + browse layout for library sections.
class OfflineBrowseView<T> extends StatelessWidget {
  const OfflineBrowseView({
    super.key,
    required this.view,
    required this.future,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.gridItemBuilder,
    required this.listItemBuilder,
  });

  final LibraryView view;
  final Future<List<T>> future;
  final String Function(T item) titleBuilder;
  final String Function(T item) subtitleBuilder;
  final Widget Function(BuildContext context, T item) gridItemBuilder;
  final Widget Function(BuildContext context, T item) listItemBuilder;

  @override
  Widget build(BuildContext context) {
    return OfflineSectionLoader<T>(
      future: future,
      emptyTitle: view.title,
      emptySubtitle: view.subtitle,
      builder: (context, items) {
        return LibraryBrowseView<T>(
          view: view,
          title: view.title,
          items: items,
          titleBuilder: titleBuilder,
          subtitleBuilder: subtitleBuilder,
          gridItemBuilder: gridItemBuilder,
          listItemBuilder: listItemBuilder,
        );
      },
    );
  }
}
