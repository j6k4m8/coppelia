import 'package:flutter/material.dart';

/// Title row for content sections.
class SectionHeader extends StatelessWidget {
  /// Creates a section header.
  const SectionHeader({super.key, required this.title, this.action});

  /// Section title.
  final String title;

  /// Optional trailing widget.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        if (action == null) {
          return Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          );
        }
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              action!,
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            action!,
          ],
        );
      },
    );
  }
}
