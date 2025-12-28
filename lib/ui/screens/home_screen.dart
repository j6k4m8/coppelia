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
import '../widgets/playlist_card.dart';
import '../widgets/track_row.dart';
import '../widgets/search_results_view.dart';
import '../widgets/settings_view.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/sidebar_resize_handle.dart';
import '../widgets/genre_detail_view.dart';
import '../widgets/play_history_view.dart';
import '../widgets/queue_view.dart';
import '../widgets/tracks_view.dart';

/// Main shell for authenticated users.
class HomeScreen extends StatelessWidget {
  /// Creates the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    final content = _MainContent(state: state);
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              top: (14 * densityScale).clamp(12.0, 20.0),
            ),
            child: Column(
              children: [
                Expanded(child: content),
              ],
            ),
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final stats = state.libraryStats;
    final playlistCount = stats?.playlistCount ?? state.playlists.length;
    final int trackCount = stats?.trackCount ??
        state.playlists.fold<int>(
          0,
          (total, playlist) => total + playlist.trackCount,
        );
    final albumCount = stats?.albumCount ?? state.albums.length;
    final artistCount = stats?.artistCount ?? state.artists.length;
    final bodyContent = LayoutBuilder(
      builder: (context, constraints) {
        const autoCollapseWidth = 640.0;
        const collapseThreshold = 140.0;
        final autoCollapsed = constraints.maxWidth < autoCollapseWidth;
        final allowManual = !autoCollapsed;
        final effectiveCollapsed = autoCollapsed || state.isSidebarCollapsed;
        final currentWidth =
            effectiveCollapsed ? 0.0 : state.sidebarWidth;
        final overlayWidth = state.sidebarWidth.clamp(220.0, 320.0);

        if (!autoCollapsed && _sidebarOverlayOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _sidebarOverlayOpen = false;
              });
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
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(32, 24, 24, 24).scale(densityScale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  userName: state.session?.userName ?? 'Listener',
                  playlistCount: playlistCount,
                  trackCount: trackCount,
                  albumCount: albumCount,
                  artistCount: artistCount,
                  state: state,
                ),
                SizedBox(height: space(24)),
                SizedBox(
                  height: 6,
                  child: AnimatedOpacity(
                    opacity: state.isLoadingLibrary ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const LinearProgressIndicator(minHeight: 2),
                  ),
                ),
                SizedBox(height: space(12)),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _LibraryContent(state: state),
                  ),
                ),
              ],
            ),
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
              child: SidebarNavigation(
                onCollapse: () => setState(() {
                  _sidebarOverlayOpen = false;
                }),
                onNavigate: () => setState(() {
                  _sidebarOverlayOpen = false;
                }),
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
                      onTap: () => setState(() {
                        _sidebarOverlayOpen = false;
                      }),
                      child: Container(
                        color: Colors.black.withOpacity(0.15),
                      ),
                    ),
                  ),
                ),
              ),
              overlayPanel,
            ],
            if (allowManual && effectiveCollapsed)
              Positioned(
                top: 28,
                left: 4,
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
                top: 28,
                left: 4,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    _sidebarOverlayOpen = true;
                  }),
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

class _Header extends StatefulWidget {
  const _Header({
    required this.userName,
    required this.playlistCount,
    required this.trackCount,
    required this.albumCount,
    required this.artistCount,
    required this.state,
  });

  final String userName;
  final int playlistCount;
  final int trackCount;
  final int albumCount;
  final int artistCount;
  final AppState state;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  late final TextEditingController _searchController;
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  late VoidCallback _stateListener;
  late int _lastSearchFocusRequest;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.searchQuery);
    _lastSearchFocusRequest = widget.state.searchFocusRequest;
    _stateListener = () {
      if (widget.state.searchQuery.isEmpty &&
          _searchController.text.isNotEmpty) {
        _searchController.clear();
        setState(() {});
      }
      if (widget.state.searchFocusRequest != _lastSearchFocusRequest) {
        _lastSearchFocusRequest = widget.state.searchFocusRequest;
        _searchFocusNode.requestFocus();
      }
    };
    widget.state.addListener(_stateListener);
  }

  @override
  void didUpdateWidget(covariant _Header oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_stateListener);
      _lastSearchFocusRequest = widget.state.searchFocusRequest;
      widget.state.addListener(_stateListener);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.state.removeListener(_stateListener);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final isSearch = state.searchQuery.isNotEmpty || state.isSearching;
    final hasSelection = state.selectedPlaylist != null ||
        state.selectedAlbum != null ||
        state.selectedArtist != null ||
        state.selectedGenre != null;
    final isHome = state.selectedView == LibraryView.home &&
        !hasSelection &&
        !isSearch;

    String title;
    String? subtitle;
    Widget? subtitleWidget;
    TextStyle? titleStyle;

    if (isSearch) {
      title = 'Search';
      subtitle = state.searchQuery.isEmpty
          ? 'Find tracks, albums, artists, and genres'
          : 'Results for "${state.searchQuery}"';
      titleStyle = theme.textTheme.headlineMedium;
    } else if (state.selectedPlaylist != null) {
      final playlist = state.selectedPlaylist!;
      title = playlist.name;
      subtitle = '${playlist.trackCount} tracks';
      titleStyle = theme.textTheme.headlineMedium;
    } else if (state.selectedAlbum != null) {
      final album = state.selectedAlbum!;
      title = album.name;
      subtitle = '${album.trackCount} tracks • ${album.artistName}';
      titleStyle = theme.textTheme.headlineMedium;
      final artistName = album.artistName;
      final canLinkArtist =
          artistName.isNotEmpty && artistName != 'Unknown Artist';
      subtitleWidget = _AlbumHeaderSubtitle(
        trackCount: album.trackCount,
        artistName: artistName,
        onArtistTap:
            canLinkArtist ? () => state.selectArtistByName(artistName) : null,
      );
    } else if (state.selectedArtist != null) {
      final artist = state.selectedArtist!;
      title = artist.name;
      subtitle = artist.albumCount > 0
          ? '${artist.albumCount} albums • ${artist.trackCount} tracks'
          : '${artist.trackCount} tracks';
      titleStyle = theme.textTheme.headlineMedium;
    } else if (state.selectedGenre != null) {
      final genre = state.selectedGenre!;
      title = genre.name;
      subtitle = '${genre.trackCount} tracks';
      titleStyle = theme.textTheme.headlineMedium;
    } else if (isHome) {
      final greeting = _greetingFor(DateTime.now());
      title = '$greeting, ${widget.userName}';
      subtitle = '${widget.trackCount} tracks • '
          '${widget.albumCount} albums • '
          '${widget.artistCount} artists • '
          '${widget.playlistCount} playlists';
      titleStyle = theme.textTheme.headlineLarge;
    } else {
      title = state.selectedView.title;
      subtitle = state.selectedView.subtitle;
      titleStyle = theme.textTheme.headlineMedium;
    }

    final VoidCallback? backAction = state.selectedPlaylist != null
        ? (state.canGoBack ? state.goBack : state.clearPlaylistSelection)
        : state.selectedAlbum != null ||
                state.selectedArtist != null ||
                state.selectedGenre != null
            ? state.clearBrowseSelection
            : state.canGoBack && state.selectedView != LibraryView.home
                ? state.goBack
                : null;
    final titleRow = backAction == null
        ? Text(title, style: titleStyle)
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _BackButton(onPressed: backAction),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: titleStyle,
                ),
              ),
            ],
          );

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titleRow,
        if (subtitleWidget != null) ...[
          const SizedBox(height: 4),
          subtitleWidget!,
        ] else if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: ColorTokens.textSecondary(context, 0.7),
            ),
          ),
        ],
      ],
    );

    final searchField = TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search',
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: _clearSearch,
              ),
        filled: true,
        fillColor: ColorTokens.cardFill(context, 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 560;
        final controls = isNarrow
            ? SizedBox(width: double.infinity, child: searchField)
            : ConstrainedBox(
                constraints:
                    const BoxConstraints(minWidth: 200, maxWidth: 280),
                child: searchField,
              );
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 12),
              controls,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 24),
            Align(
              alignment: Alignment.topRight,
              child: controls,
            ),
          ],
        );
      },
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.state.searchLibrary(value);
    });
    setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    widget.state.clearSearch();
    setState(() {});
  }
}

String _greetingFor(DateTime time) {
  final hour = time.hour;
  if (hour >= 4 && hour < 6) {
    return 'Some early bird tunes';
  }
  if (hour >= 22 || hour < 4) {
    return 'Late night vibes';
  }
  if (hour >= 5 && hour < 12) {
    return 'Good morning';
  }
  if (hour >= 12 && hour < 18) {
    return 'Good afternoon';
  }
  return 'Welcome back';
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorTokens.cardFill(context, 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.chevron_left),
        ),
      ),
    );
  }
}

class _AlbumHeaderSubtitle extends StatelessWidget {
  const _AlbumHeaderSubtitle({
    required this.trackCount,
    required this.artistName,
    this.onArtistTap,
  });

  final int trackCount;
  final String artistName;
  final VoidCallback? onArtistTap;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: ColorTokens.textSecondary(context, 0.7),
        );
    final linkStyle = baseStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    return Row(
      children: [
        Text('$trackCount tracks', style: baseStyle),
        const SizedBox(width: 6),
        Text(
          '•',
          style: TextStyle(
            color: ColorTokens.textSecondary(context, 0.4),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: onArtistTap == null
              ? Text(
                  artistName,
                  style: baseStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onArtistTap,
                    child: Text(
                      artistName,
                      style: linkStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
        ),
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
      return const SearchResultsView();
    }
    if (state.selectedPlaylist != null) {
      return const PlaylistDetailView();
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
      return _HomeRecentView(tracks: state.playHistory, fallback: state.recentTracks);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 220).floor();
        final columns = crossAxisCount < 1 ? 1 : crossAxisCount;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return PlaylistCard(
              playlist: playlist,
              onTap: () =>
                  context.read<AppState>().selectPlaylist(playlist),
              onPlay: () =>
                  context.read<AppState>().playPlaylist(playlist),
            );
          },
        );
      },
    );
  }
}
