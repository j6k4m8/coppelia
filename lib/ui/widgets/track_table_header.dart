import 'package:flutter/material.dart';

import '../../core/color_tokens.dart';

/// Table header with resizable columns for track lists.
class TrackTableHeader extends StatefulWidget {
  const TrackTableHeader({
    super.key,
    required this.onColumnWidthsChanged,
    this.initialWidths = const {
      'index': 60.0,
      'title': 300.0,
      'artist': 200.0,
      'album': 200.0,
      'duration': 80.0,
    },
  });

  final ValueChanged<Map<String, double>> onColumnWidthsChanged;
  final Map<String, double> initialWidths;

  @override
  State<TrackTableHeader> createState() => _TrackTableHeaderState();
}

class _TrackTableHeaderState extends State<TrackTableHeader> {
  late Map<String, double> _widths;
  final Set<String> _visibleColumns = {
    'index',
    'title',
    'artist',
    'album',
    'duration',
  };

  @override
  void initState() {
    super.initState();
    _widths = Map.from(widget.initialWidths);
  }

  void _showColumnMenu() {
    // Show menu to toggle column visibility
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(1000, 100, 0, 0),
      items: [
        for (final column in ['index', 'title', 'artist', 'album', 'duration'])
          CheckedPopupMenuItem<String>(
            value: column,
            checked: _visibleColumns.contains(column),
            child: Text(_columnLabel(column)),
            onTap: () {
              setState(() {
                if (_visibleColumns.contains(column)) {
                  _visibleColumns.remove(column);
                } else {
                  _visibleColumns.add(column);
                }
              });
            },
          ),
      ],
    );
  }

  String _columnLabel(String column) {
    switch (column) {
      case 'index':
        return '#';
      case 'title':
        return 'Title';
      case 'artist':
        return 'Artist';
      case 'album':
        return 'Album';
      case 'duration':
        return 'Time';
      default:
        return column;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: ColorTokens.border(context, 0.12),
          ),
        ),
      ),
      child: Row(
        children: [
          if (_visibleColumns.contains('index'))
            SizedBox(
              width: _widths['index'],
              child: Text(
                '#',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColorTokens.textSecondary(context, 0.7),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          if (_visibleColumns.contains('title'))
            Expanded(
              flex: 3,
              child: Text(
                'Title',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColorTokens.textSecondary(context, 0.7),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          if (_visibleColumns.contains('artist'))
            Expanded(
              flex: 2,
              child: Text(
                'Artist',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColorTokens.textSecondary(context, 0.7),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          if (_visibleColumns.contains('album'))
            Expanded(
              flex: 2,
              child: Text(
                'Album',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColorTokens.textSecondary(context, 0.7),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          if (_visibleColumns.contains('duration'))
            SizedBox(
              width: _widths['duration'],
              child: Text(
                'Time',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColorTokens.textSecondary(context, 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.right,
              ),
            ),
          IconButton(
            icon: Icon(
              Icons.view_column,
              size: 16,
              color: ColorTokens.textSecondary(context, 0.7),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            onPressed: _showColumnMenu,
          ),
        ],
      ),
    );
  }
}
