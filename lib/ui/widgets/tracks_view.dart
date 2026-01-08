import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_tokens.dart';
import '../../models/media_item.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import 'header_action.dart';
import 'page_header.dart';
import 'track_row.dart';

/// Displays the full library track list with pagination.
class TracksView extends StatefulWidget {
  /// Creates the tracks view.
  const TracksView({super.key});

  @override
  State<TracksView> createState() => _TracksViewState();
}

class _TracksViewState extends State<TracksView> {
  static const List<String> _alphabet = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  late final ScrollController _controller;
  bool _isJumping = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _controller.addListener(_handleScroll);
    final state = context.read<AppState>();
    if (state.libraryTracks.isEmpty && !state.isLoadingTracks) {
      unawaited(state.loadLibraryTracks(reset: true));
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final state = context.read<AppState>();
    if (state.isLoadingTracks || !state.hasMoreTracks) {
      return;
    }
    final max = _controller.position.maxScrollExtent;
    if (max <= 0) {
      return;
    }
    if (_controller.position.pixels >= max - 320) {
      unawaited(state.loadLibraryTracks());
    }
  }

  String _leadingLetter(String raw) {
    final trimmed = raw.trimLeft();
    if (trimmed.isEmpty) {
      return '#';
    }
    final letter = String.fromCharCode(trimmed.runes.first).toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(letter) ? letter : '#';
  }

  int? _indexForLetter(List<MediaItem> tracks, String letter) {
    for (var i = 0; i < tracks.length; i++) {
      if (_leadingLetter(tracks[i].title) == letter) {
        return i;
      }
    }
    return null;
  }

  double _textHeight(TextStyle? style) {
    final fontSize = style?.fontSize ?? 14;
    final height = style?.height ?? 1.2;
    return fontSize * height;
  }

  double _rowExtent({
    required LayoutDensity density,
    required double densityScale,
    required TextTheme textTheme,
  }) {
    final artSize = (44 * densityScale).clamp(24.0, 56.0);
    final verticalPad = density == LayoutDensity.sardine
        ? (6 * densityScale).clamp(2.0, 8.0)
        : (10 * densityScale).clamp(4.0, 14.0);
    final metaGap = density == LayoutDensity.sardine
        ? (1 * densityScale).clamp(0.0, 2.0)
        : (2 * densityScale).clamp(1.0, 4.0);
    final textBlock = _textHeight(textTheme.bodyLarge) +
        _textHeight(textTheme.bodySmall) +
        metaGap;
    final contentHeight = math.max(artSize, textBlock);
    final rowHeight = contentHeight + verticalPad * 2;
    return rowHeight;
  }

  void _jumpToIndex(int index, double rowStride) {
    if (!_controller.hasClients) {
      return;
    }
    final target = rowStride * index;
    final max = _controller.position.maxScrollExtent;
    _controller.jumpTo(target.clamp(0.0, max));
  }

  Future<void> _jumpToLetter(
    AppState state,
    String letter,
    double rowStride,
  ) async {
    if (_isJumping) {
      return;
    }
    _isJumping = true;
    try {
      state.setTrackBrowseLetter(letter);
      var index = _indexForLetter(state.libraryTracks, letter);
      while (index == null && state.hasMoreTracks) {
        await state.loadLibraryTracks();
        if (!mounted) {
          return;
        }
        index = _indexForLetter(state.libraryTracks, letter);
      }
      if (index != null) {
        _jumpToIndex(index, rowStride);
      }
    } finally {
      _isJumping = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final density = state.layoutDensity;
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final leftGutter = (32 * densityScale).clamp(16.0, 40.0).toDouble();
    final rightGutter = (24 * densityScale).clamp(12.0, 32.0).toDouble();
    final gap = (6 * densityScale).clamp(4.0, 10.0);
    final rowExtent = _rowExtent(
      density: density,
      densityScale: densityScale,
      textTheme: Theme.of(context).textTheme,
    );
    final rowStride = rowExtent + gap;
    final total = state.libraryStats?.trackCount ?? 0;
    final count = state.libraryTracks.length;
    final activeLetter = state.trackBrowseLetter;
    final baseLabel = total > 0 ? '$count of $total tracks' : '$count tracks';
    final label = baseLabel;
    final contentRightPadding = space(48).clamp(32.0, 64.0);
    final headerPadding = EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0);
    final listPadding = EdgeInsets.fromLTRB(
      leftGutter,
      0,
      rightGutter + contentRightPadding,
      0,
    );

    if (count == 0 && state.isLoadingTracks) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: headerPadding,
          child: PageHeader(
            title: 'Tracks',
            subtitle: label,
            trailing: activeLetter != null
                ? Row(
                    children: [
                      Text(
                        'Jump: $activeLetter',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ColorTokens.textSecondary(context),
                            ),
                      ),
                      SizedBox(width: space(10)),
                      HeaderAction(
                        label: 'Clear',
                        onTap: () => state.setTrackBrowseLetter(null),
                      ),
                    ],
                  )
                : null,
          ),
        ),
        SizedBox(height: space(16)),
        Expanded(
          child: Stack(
            children: [
              ListView.separated(
                controller: _controller,
                padding: listPadding,
                itemCount: count + (state.hasMoreTracks ? 1 : 0),
                separatorBuilder: (_, __) => SizedBox(height: gap),
                itemBuilder: (context, index) {
                  if (index >= count) {
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: space(12).clamp(8.0, 16.0),
                      ),
                      child: Center(
                        child: state.isLoadingTracks
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : TextButton.icon(
                                onPressed: () => state.loadLibraryTracks(),
                                icon: const Icon(Icons.expand_more),
                                label: const Text('Load more'),
                              ),
                      ),
                    );
                  }
                  final track = state.libraryTracks[index];
                  return TrackRow(
                    track: track,
                    index: index,
                    isActive: state.nowPlaying?.id == track.id,
                    onTap: () => state.playFromList(state.libraryTracks, track),
                    onPlayNext: () => state.playNext(track),
                    onAddToQueue: () => state.enqueueTrack(track),
                    isFavorite: state.isFavoriteTrack(track.id),
                    isFavoriteUpdating: state.isFavoriteTrackUpdating(track.id),
                    onToggleFavorite: () => state.setTrackFavorite(
                      track,
                      !state.isFavoriteTrack(track.id),
                    ),
                    onAlbumTap: track.albumId == null
                        ? null
                        : () => state.selectAlbumById(track.albumId!),
                    onArtistTap: track.artistIds.isEmpty
                        ? null
                        : () => state.selectArtistById(track.artistIds.first),
                    onGoToAlbum: track.albumId == null
                        ? null
                        : () => state.selectAlbumById(track.albumId!),
                    onGoToArtist: track.artistIds.isEmpty
                        ? null
                        : () => state.selectArtistById(track.artistIds.first),
                  );
                },
              ),
              Positioned(
                right: 0,
                top: space(12),
                bottom: space(12),
                child: _AlphabetScroller(
                  letters: _alphabet,
                  selected: activeLetter,
                  onSelected: (letter) =>
                      _jumpToLetter(state, letter, rowStride),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlphabetScroller extends StatelessWidget {
  const _AlphabetScroller({
    required this.letters,
    required this.onSelected,
    required this.selected,
  });

  final List<String> letters;
  final ValueChanged<String> onSelected;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final slotHeight = space(18).clamp(14.0, 22.0);
    return Container(
      width: space(28).clamp(22.0, 36.0),
      padding: EdgeInsets.symmetric(vertical: space(8)),
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.04),
        borderRadius: BorderRadius.circular(
          space(20).clamp(14.0, 24.0),
        ),
        border: Border.all(color: ColorTokens.border(context)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: letters
              .map(
                (letter) => SizedBox(
                  height: slotHeight,
                  child: _AlphabetLetter(
                    letter: letter,
                    selected: selected == letter,
                    onTap: () => onSelected(letter),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _AlphabetLetter extends StatelessWidget {
  const _AlphabetLetter({
    required this.letter,
    required this.onTap,
    required this.selected,
  });

  final String letter;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final baseStyle = Theme.of(context).textTheme.labelSmall;
    return TextButton(
      onPressed: onTap,
      style: ButtonStyle(
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        minimumSize: WidgetStateProperty.all(Size(space(20), space(20))),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (selected) {
            return Theme.of(context).colorScheme.primary;
          }
          if (states.contains(WidgetState.hovered)) {
            return ColorTokens.textPrimary(context);
          }
          return ColorTokens.textSecondary(context, 0.7);
        }),
        textStyle: WidgetStateProperty.all(baseStyle),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return ColorTokens.cardFill(context, 0.08);
          }
          return Colors.transparent;
        }),
      ),
      child: Text(letter),
    );
  }
}
