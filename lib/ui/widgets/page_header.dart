import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import '../../core/color_tokens.dart';
import 'header_controls.dart';

/// Shared title row that contains a back caret and search affordance.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.showSearchButton = true,
  });

  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final bool showSearchButton;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final theme = Theme.of(context);
    final canGoBack = state.canGoBack;
    final textStyle = theme.textTheme.titleLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HeaderControlButton(
              icon: Icons.arrow_back_ios_new,
              tooltip: 'Go back',
              onTap: canGoBack ? state.goBack : null,
            ),
            SizedBox(width: space(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textStyle,
                  ),
                  if (subtitle != null || subtitleWidget != null) ...[
                    SizedBox(height: space(4)),
                    subtitleWidget ??
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ColorTokens.textSecondary(context),
                          ),
                        ),
                  ],
                ],
              ),
            ),
            if (showSearchButton) ...[
              SizedBox(width: space(12)),
              SearchCircleButton(
                onTap: state.requestSearchFocus,
              ),
            ],
          ],
        ),
        if (trailing != null) ...[
          SizedBox(height: space(8)),
          trailing!,
        ],
      ],
    );
  }
}
