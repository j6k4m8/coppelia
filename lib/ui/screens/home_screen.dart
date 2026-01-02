import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../models/playlist.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import '../../state/library_view.dart';
import '../../state/now_playing_layout.dart';
import '../../core/color_tokens.dart';
import '../widgets/album_detail_view.dart';
import '../widgets/albums_view.dart';
import '../widgets/artist_detail_view.dart';
import '../widgets/artists_view.dart';
import '../widgets/favorite_albums_view.dart';
import '../widgets/favorite_artists_view.dart';
import '../widgets/favorite_tracks_view.dart';
import '../widgets/gradient_background.dart';
import '../widgets/library_overview.dart';
import '../widgets/library_placeholder_view.dart';
import '../widgets/genres_view.dart';
import '../widgets/now_playing_panel.dart';
import '../widgets/offline_albums_view.dart';
import '../widgets/offline_artists_view.dart';
import '../widgets/offline_playlists_view.dart';
import '../widgets/offline_tracks_view.dart';
import '../widgets/playlist_detail_view.dart';
import '../widgets/smart_list_detail_view.dart';
import '../widgets/playlist_card.dart';
import '../widgets/track_row.dart';
import '../widgets/artwork_image.dart';
import '../widgets/search_results_view.dart';
import '../widgets/settings_view.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/sidebar_resize_handle.dart';
import '../widgets/genre_detail_view.dart';
import '../widgets/play_history_view.dart';
import '../widgets/queue_view.dart';
import '../widgets/tracks_view.dart';
import '../widgets/header_controls.dart';
import '../widgets/page_header.dart';
import '../widgets/library_browse_view.dart';

/// Main shell for authenticated users.
class HomeScreen extends StatelessWidget {
  /// Creates the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: GradientBackground(
        child: _MainContent(state: state),
      ),
    );
  }
}

class _MainContent extends StatefulWidget {
  const _MainContent({required this.state});

  final AppState state;

  @override
  State<_MainContent> createState() => _MainContentState();
}

class _MainContentState extends State<_MainContent> {
  bool _sidebarOverlayOpen = false;
  double _sidebarOpenDrag = 0;
  double _sidebarCloseDrag = 0;

  void _setSidebarOverlayOpen(bool value) {
    if (_sidebarOverlayOpen == value) {
      return;
    }
    setState(() {
      _sidebarOverlayOpen = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final densityScale = state.layoutDensity.scaleDouble;
    final safeTop = MediaQuery.of(context).padding.top;
    final chromeInset = (14 * densityScale).clamp(12.0, 20.0).toDouble();
    final topInset = safeTop + chromeInset;
    final topGutter = (24 * densityScale).clamp(12.0, 32.0).toDouble();
    final overlayButtonTop =
        (28 * densityScale).clamp(20.0, 34.0).toDouble() + topInset;
    final bodyContent = LayoutBuilder(
      builder: (context, constraints) {
        const autoCollapseWidth = 640.0;
        const collapseThreshold = 140.0;
        final autoCollapsed = constraints.maxWidth < autoCollapseWidth;
        final allowManual = !autoCollapsed;
        final effectiveCollapsed = autoCollapsed || state.isSidebarCollapsed;
        final currentWidth = effectiveCollapsed ? 0.0 : state.sidebarWidth;
        final overlayWidth = state.sidebarWidth.clamp(220.0, 320.0);

        if (!autoCollapsed && _sidebarOverlayOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _setSidebarOverlayOpen(false);
            }
          });
        }

        final navigation = effectiveCollapsed
            ? const SizedBox.shrink()
            : SizedBox(
                width: state.sidebarWidth,
                child: SidebarNavigation(
                  onCollapse: allowManual
                      ? () => state.setSidebarCollapsed(true)
                      : null,
                ),
              );

        final handle = autoCollapsed
            ? const SizedBox.shrink()
            : SidebarResizeHandle(
                onDragUpdate: allowManual
                    ? (delta) {
                        final nextWidth =
                            (currentWidth + delta).clamp(0.0, 360.0);
                        if (nextWidth < collapseThreshold) {
                          state.setSidebarCollapsed(true, persist: false);
                        } else {
                          if (state.isSidebarCollapsed) {
                            state.setSidebarCollapsed(false, persist: false);
                          }
                          state.setSidebarWidth(nextWidth, persist: false);
                        }
                      }
                    : (_) {},
                onDragEnd: allowManual
                    ? () {
                        if (state.isSidebarCollapsed) {
                          state.setSidebarCollapsed(true, persist: true);
                        } else {
                          state.setSidebarWidth(
                            state.sidebarWidth,
                            persist: true,
                          );
                          state.setSidebarCollapsed(false, persist: true);
                        }
                      }
                    : null,
              );

        final content = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: topInset + topGutter),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _LibraryContent(state: state),
                  ),
                ),
              ),
            ],
          ),
        );

        final row = Row(
          children: [
            navigation,
            handle,
            content,
          ],
        );

        final overlayPanel = AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          left: _sidebarOverlayOpen ? 0 : -overlayWidth - 12,
          top: 0,
          bottom: 0,
          child: Material(
            color: Colors.transparent,
            elevation: 12,
            child: SizedBox(
              width: overlayWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) {
                  _sidebarCloseDrag = 0;
                },
                onHorizontalDragUpdate: (details) {
                  _sidebarCloseDrag += details.delta.dx;
                },
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -300 || _sidebarCloseDrag < -24) {
                    _setSidebarOverlayOpen(false);
                  }
                },
                child: SidebarNavigation(
                  onCollapse: () => _setSidebarOverlayOpen(false),
                  onNavigate: () => _setSidebarOverlayOpen(false),
                ),
              ),
            ),
          ),
        );

        return Stack(
          children: [
            row,
            if (autoCollapsed) ...[
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_sidebarOverlayOpen,
                  child: AnimatedOpacity(
                    opacity: _sidebarOverlayOpen ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _setSidebarOverlayOpen(false),
                      onHorizontalDragStart: (_) {
                        _sidebarCloseDrag = 0;
                      },
                      onHorizontalDragUpdate: (details) {
                        _sidebarCloseDrag += details.delta.dx;
                      },
                      onHorizontalDragEnd: (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        if (velocity < -300 || _sidebarCloseDrag < -24) {
                          _setSidebarOverlayOpen(false);
                        }
                      },
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ),
              ),
              overlayPanel,
              if (!_sidebarOverlayOpen)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: 28,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: (_) {
                      _sidebarOpenDrag = 0;
                    },
                    onHorizontalDragUpdate: (details) {
                      _sidebarOpenDrag += details.delta.dx;
                    },
                    onHorizontalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity > 300 || _sidebarOpenDrag > 24) {
                        _setSidebarOverlayOpen(true);
                      }
                    },
                  ),
                ),
            ],
            if (allowManual && effectiveCollapsed)
              Positioned(
                top: overlayButtonTop,
                left: -10,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => state.setSidebarCollapsed(false),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ColorTokens.cardFill(context, 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ColorTokens.border(context)),
                    ),
                    child: const Icon(Icons.chevron_right, size: 18),
                  ),
                ),
              ),
            if (autoCollapsed && !_sidebarOverlayOpen)
              Positioned(
                top: overlayButtonTop,
                left: -10,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _setSidebarOverlayOpen(true),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ColorTokens.cardFill(context, 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ColorTokens.border(context)),
                    ),
                    child: const Icon(Icons.chevron_right, size: 18),
                  ),
                ),
              ),
          ],
        );
      },
    );

    if (state.nowPlayingLayout == NowPlayingLayout.side) {
      return Row(
        children: [
          Expanded(child: bodyContent),
          NowPlayingPanel(layout: state.nowPlayingLayout),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: bodyContent),
        NowPlayingPanel(layout: state.nowPlayingLayout),
      ],
    );
  }
}

class _LibraryContent extends StatelessWidget {
  const _LibraryContent({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.searchQuery.isNotEmpty || state.isSearching) {
      return const _SearchView();
    }
    if (state.selectedPlaylist != null) {
      return const PlaylistDetailView();
    }
    if (state.selectedSmartList != null) {
      return const SmartListDetailView();
    }
    if (state.selectedAlbum != null) {
      return const AlbumDetailView();
    }
    if (state.selectedArtist != null) {
      return const ArtistDetailView();
    }
    if (state.selectedGenre != null) {
      return const GenreDetailView();
    }
    if (state.selectedView == LibraryView.home) {
      return const LibraryOverview();
    }
    if (state.selectedView == LibraryView.homeFeatured) {
      return _HomeFeaturedView(tracks: state.featuredTracks);
    }
    if (state.selectedView == LibraryView.homeRecent) {
      return _HomeRecentView(
          tracks: state.playHistory, fallback: state.recentTracks);
    }
    if (state.selectedView == LibraryView.homePlaylists) {
      return _HomePlaylistsView(playlists: state.playlists);
    }
    if (state.selectedView == LibraryView.albums) {
      return const AlbumsView();
    }
    if (state.selectedView == LibraryView.artists) {
      return const ArtistsView();
    }
    if (state.selectedView == LibraryView.genres) {
      return const GenresView();
    }
    if (state.selectedView == LibraryView.tracks) {
      return const TracksView();
    }
    if (state.selectedView == LibraryView.favoritesAlbums) {
      return const FavoriteAlbumsView();
    }
    if (state.selectedView == LibraryView.favoritesArtists) {
      return const FavoriteArtistsView();
    }
    if (state.selectedView == LibraryView.favoritesSongs) {
      return const FavoriteTracksView();
    }
    if (state.selectedView == LibraryView.offlineAlbums) {
      return const OfflineAlbumsView();
    }
    if (state.selectedView == LibraryView.offlineArtists) {
      return const OfflineArtistsView();
    }
    if (state.selectedView == LibraryView.offlinePlaylists) {
      return const OfflinePlaylistsView();
    }
    if (state.selectedView == LibraryView.offlineTracks) {
      return const OfflineTracksView();
    }
    if (state.selectedView == LibraryView.history) {
      return const PlayHistoryView();
    }
    if (state.selectedView == LibraryView.queue) {
      return const QueueView();
    }
    if (state.selectedView == LibraryView.settings) {
      return const SettingsView();
    }
    return LibraryPlaceholderView(view: state.selectedView);
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  late int _lastSearchFocusRequest;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _controller = TextEditingController(text: state.searchQuery);
    _lastSearchFocusRequest = state.searchFocusRequest;

    state.addListener(_handleAppStateChange);

    // When entering the search page, focus inside the field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _handleAppStateChange() {
    final state = context.read<AppState>();
    if (state.searchQuery != _controller.text) {
      _controller.value = _controller.value.copyWith(text: state.searchQuery);
    }
    if (state.searchFocusRequest != _lastSearchFocusRequest) {
      _lastSearchFocusRequest = state.searchFocusRequest;
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    context.read<AppState>().removeListener(_handleAppStateChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      context.read<AppState>().searchLibrary(value);
    });
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    context.read<AppState>().clearSearch();
    _focusNode.requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final leftGutter = (32 * densityScale).clamp(16.0, 40.0).toDouble();
    final rightGutter = (24 * densityScale).clamp(12.0, 32.0).toDouble();

    final searchField = TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: _onChanged,
      decoration: InputDecoration(
        hintText: 'Search',
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: _clear,
              ),
        filled: true,
        fillColor: ColorTokens.cardFill(context, 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(leftGutter, 0, rightGutter, 0),
          child: Row(
            children: [
              HeaderControlButton(
                icon: Icons.arrow_back_ios_new,
                onTap: state.goBack,
              ),
              SizedBox(width: space(10)),
              Expanded(
                child: SizedBox(width: double.infinity, child: searchField),
              ),
            ],
          ),
        ),
        SizedBox(height: space(16)),
        Expanded(
          child: state.searchQuery.isEmpty
              ? Center(
                  child: Text(
                    'Search your library',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: ColorTokens.textSecondary(context),
                        ),
                  ),
                )
              : const SearchResultsView(),
        ),
      ],
    );
  }
}

class _HomeFeaturedView extends StatelessWidget {
  const _HomeFeaturedView({required this.tracks});

  final List<MediaItem> tracks;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    if (tracks.isEmpty) {
      return const LibraryPlaceholderView(view: LibraryView.homeFeatured);
    }
    return ListView.separated(
      itemCount: tracks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final track = tracks[index];
        return TrackRow(
          track: track,
          index: index,
          isActive: false,
          onTap: () => state.playFromList(tracks, track),
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
    );
  }
}

class _HomeRecentView extends StatelessWidget {
  const _HomeRecentView({required this.tracks, required this.fallback});

  final List<MediaItem> tracks;
  final List<MediaItem> fallback;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final effectiveTracks = tracks.isNotEmpty ? tracks : fallback;
    if (effectiveTracks.isEmpty) {
      return const LibraryPlaceholderView(view: LibraryView.homeRecent);
    }
    return ListView.separated(
      itemCount: effectiveTracks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final track = effectiveTracks[index];
        return TrackRow(
          track: track,
          index: index,
          isActive: false,
          onTap: () => state.playFromList(effectiveTracks, track),
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
    );
  }
}

class _HomePlaylistsView extends StatelessWidget {
  const _HomePlaylistsView({required this.playlists});

  final List<Playlist> playlists;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return const LibraryPlaceholderView(view: LibraryView.homePlaylists);
    }
    return LibraryBrowseView<Playlist>(
      view: LibraryView.homePlaylists,
      title: 'Playlists',
      items: playlists,
      titleBuilder: (playlist) => playlist.name,
      subtitleBuilder: (playlist) => '${playlist.trackCount} tracks',
      gridItemBuilder: (context, playlist) {
        final state = context.read<AppState>();
        return PlaylistCard(
          playlist: playlist,
          onTap: () => state.selectPlaylist(playlist),
          onPlay: () => state.playPlaylist(playlist),
        );
      },
      listItemBuilder: (context, playlist) {
        final state = context.read<AppState>();
        return PlaylistListRow(
          playlist: playlist,
          onTap: () => state.selectPlaylist(playlist),
          onPlay: () => state.playPlaylist(playlist),
        );
      },
    );
  }
}

class PlaylistListRow extends StatelessWidget {
  const PlaylistListRow({
    super.key,
    required this.playlist,
    required this.onTap,
    required this.onPlay,
  });

  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final densityScale =
        context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final artSize = (52 * densityScale).clamp(28.0, 64.0);
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final subtitleStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: ColorTokens.textSecondary(context));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: space(12).clamp(6.0, 14.0),
          horizontal: space(12).clamp(8.0, 16.0),
        ),
        decoration: BoxDecoration(
          color: ColorTokens.cardFill(context, 0.04),
          borderRadius: BorderRadius.circular(space(16)),
          border: Border.all(color: ColorTokens.border(context)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(space(12)),
              child: ArtworkImage(
                imageUrl: playlist.imageUrl,
                width: artSize,
                height: artSize,
                fit: BoxFit.cover,
                placeholder: Container(
                  width: artSize,
                  height: artSize,
                  color: ColorTokens.cardFillStrong(context),
                  child: Icon(
                    Icons.queue_music,
                    size: space(20),
                  ),
                ),
              ),
            ),
            SizedBox(width: space(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  SizedBox(height: space(4)),
                  Text(
                    '${playlist.trackCount} tracks',
                    style: subtitleStyle,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow),
            ),
          ],
        ),
      ),
    );
  }
}
