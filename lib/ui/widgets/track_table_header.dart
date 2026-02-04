import 'package:flutter/material.dart';

import '../../core/color_tokens.dart';

/// Table header with resizable columns for track lists.
class TrackTableHeader extends StatefulWidget {
  const TrackTableHeader({
    super.key,
    required this.onVisibleColumnsChanged,
  });

  final ValueChanged<Set<String>> onVisibleColumnsChanged;

  @override
  State<TrackTableHeader> createState() => _TrackTableHeaderState();
}

class _TrackTableHeaderState extends State<TrackTableHeader> {
  final Set<String> _visibleColumns = {
    'title',
    'artist',
    'album',
    'duration',
    'favorite',
  };

  final List<String> _allColumns = [
    'title',
    'artist',
    'album',
    'genre',
    'playCount',
    'bpm',
    'duration',
    'favorite',
  ];

  void _showColumnMenu() {
    // Show menu to toggle column visibility
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 100, 0, 0),
      items: [
        for (final column in _allColumns)
          CheckedPopupMenuItem<String>(
            value: column,
            checked: _visibleColumns.contains(column),
            enabled: column != 'title', // Title always visible
            onTap: column == 'title'
                ? null
                : () {
                    setState(() {
                      if (_visibleColumns.contains(column)) {
                        _visibleColumns.remove(column);
                      } else {
                        _visibleColumns.add(column);
                      }
                      widget.onVisibleColumnsChanged(_visibleColumns);
                    });
                  },
            child: Text(_columnLabel(column)),
          ),
      ],
    );
  }

  String _columnLabel(String column) {
    switch (column) {
      case 'title':
        return 'Title';
      case 'artist':
        return 'Artist';
      case 'album':
        return 'Album';
      case 'genre':
        return 'Genre';
      case 'playCount':
        return 'Plays';
      case 'bpm':
        return 'BPM';
      case 'duration':
        return 'Time';
      case 'favorite':
        return 'Favorite';
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
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Column selector button
          SizedBox(
            width: 40,
            child: Center(
              child: IconButton(
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
            ),
          ),
          const SizedBox(width: 16),
          // Title
          if (_visibleColumns.contains('title'))
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Title',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ColorTokens.textSecondary(context, 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          if (_visibleColumns.contains('title')) const SizedBox(width: 16),
          // Artist
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
          if (_visibleColumns.contains('artist')) const SizedBox(width: 16),
          // Album
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
          if (_visibleColumns.contains('album')) const SizedBox(width: 16),
          // Genre
          if (_visibleColumns.contains('genre'))
            Expanded(
              flex: 2,
              child: Text(
                'Genre',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColorTokens.textSecondary(context, 0.7),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          if (_visibleColumns.contains('genre')) const SizedBox(width: 16),
          // Play count
          if (_visibleColumns.contains('playCount'))
            SizedBox(
              width: 80,
              child: Text(
                'Plays',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColorTokens.textSecondary(context, 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.right,
              ),
            ),
          if (_visibleColumns.contains('playCount')) const SizedBox(width: 16),
          // BPM
          if (_visibleColumns.contains('bpm'))
            SizedBox(
              width: 70,
              child: Text(
                'BPM',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColorTokens.textSecondary(context, 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.right,
              ),
            ),
          if (_visibleColumns.contains('bpm')) const SizedBox(width: 16),
          // Duration
          if (_visibleColumns.contains('duration'))
            SizedBox(
              width: 80,
              child: Text(
                'Time',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColorTokens.textSecondary(context, 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.right,
              ),
            ),
          if (_visibleColumns.contains('duration')) const SizedBox(width: 16),
          // Favorite
          if (_visibleColumns.contains('favorite'))
            SizedBox(
              width: 50,
              child: Icon(
                Icons.favorite_border,
                size: 16,
                color: ColorTokens.textSecondary(context, 0.5),
              ),
            ),
        ],
      ),
    );
  }
}
