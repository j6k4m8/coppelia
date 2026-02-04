import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'page_header.dart';

/// Shared header + track list layout for simple track sections.
class TrackListSection extends StatelessWidget {
  const TrackListSection({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.itemCount,
    this.itemBuilder,
    this.controller,
    this.headerPadding,
    this.listPadding,
    this.listBottomPadding,
    this.headerBottomSpacing,
    this.gap,
    this.bodyBuilder,
    this.headerWidget,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final ScrollController? controller;
  final EdgeInsets? headerPadding;
  final EdgeInsets? listPadding;
  final double? listBottomPadding;
  final double? headerBottomSpacing;
  final double? gap;
  final Widget Function(
    BuildContext context,
    EdgeInsets listPadding,
    double gap,
  )? bodyBuilder;
  final Widget? headerWidget;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final leftGutter = (32 * densityScale).clamp(16.0, 40.0).toDouble();
    final rightGutter = (24 * densityScale).clamp(12.0, 32.0).toDouble();
    final resolvedHeaderPadding =
        headerPadding ?? EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0);
    final resolvedListPadding = listPadding ??
        EdgeInsets.fromLTRB(
          leftGutter,
          0,
          rightGutter,
          listBottomPadding ?? 0,
        );
    final resolvedGap = gap ?? space(6).clamp(4.0, 10.0);
    final resolvedHeaderBottomSpacing = headerBottomSpacing ?? space(16);

    assert(
      bodyBuilder != null || (itemCount != null && itemBuilder != null),
      'Provide either bodyBuilder or itemCount/itemBuilder.',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: resolvedHeaderPadding,
          child: PageHeader(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
          ),
        ),
        SizedBox(height: resolvedHeaderBottomSpacing),
        if (headerWidget != null) headerWidget!,
        Expanded(
          child: bodyBuilder != null
              ? bodyBuilder!(context, resolvedListPadding, resolvedGap)
              : ListView.separated(
                  controller: controller,
                  padding: resolvedListPadding,
                  itemCount: itemCount!,
                  separatorBuilder: (_, __) => SizedBox(height: resolvedGap),
                  itemBuilder: itemBuilder!,
                ),
        ),
      ],
    );
  }
}
