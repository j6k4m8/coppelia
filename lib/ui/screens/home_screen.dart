import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
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
import '../widgets/glowing_loading_bar.dart';
import '../widgets/library_overview.dart';
import '../widgets/library_placeholder_view.dart';
import '../widgets/genres_view.dart';
import '../widgets/now_playing_panel.dart';
import '../widgets/playlist_detail_view.dart';
import '../widgets/search_results_view.dart';
import '../widgets/settings_view.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/sidebar_resize_handle.dart';
import '../widgets/genre_detail_view.dart';
import '../widgets/play_history_view.dart';
import '../widgets/queue_view.dart';

/// Main shell for authenticated users.
class HomeScreen extends StatelessWidget {
  /// Creates the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final content = _MainContent(state: state);
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              GlowingLoadingBar(isVisible: state.isBuffering),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainContent extends StatelessWidget {
  const _MainContent({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final stats = state.libraryStats;
    final playlistCount = stats?.playlistCount ?? state.playlists.length;
    final int trackCount = stats?.trackCount ??
        state.playlists.fold<int>(
          0,
          (total, playlist) => total + playlist.trackCount,
        );
    final albumCount = stats?.albumCount ?? state.albums.length;
    final artistCount = stats?.artistCount ?? state.artists.length;
    final bodyContent = Row(
      children: [
        SizedBox(
          width: state.sidebarWidth,
          child: const SidebarNavigation(),
        ),
        SidebarResizeHandle(
          onDragUpdate: (delta) {
            final nextWidth = (state.sidebarWidth + delta).clamp(200.0, 360.0);
            state.setSidebarWidth(nextWidth, persist: false);
          },
          onDragEnd: () {
            state.setSidebarWidth(state.sidebarWidth, persist: true);
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 24, 24),
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
                const SizedBox(height: 24),
                SizedBox(
                  height: 6,
                  child: AnimatedOpacity(
                    opacity: state.isLoadingLibrary ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const LinearProgressIndicator(minHeight: 2),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _LibraryContent(state: state),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
  Timer? _debounce;
  late VoidCallback _stateListener;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.searchQuery);
    _stateListener = () {
      if (widget.state.searchQuery.isEmpty &&
          _searchController.text.isNotEmpty) {
        _searchController.clear();
        setState(() {});
      }
    };
    widget.state.addListener(_stateListener);
  }

  @override
  void didUpdateWidget(covariant _Header oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_stateListener);
      widget.state.addListener(_stateListener);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.state.removeListener(_stateListener);
    _searchController.dispose();
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
      title = 'Good evening, ${widget.userName}';
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

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: titleStyle,
        ),
        if (subtitle != null) ...[
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

    final searchField = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
      child: TextField(
        controller: _searchController,
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
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 860;
        final controls = searchField;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 16),
              Align(alignment: Alignment.centerRight, child: controls),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            const SizedBox(width: 24),
            Flexible(child: Align(
              alignment: Alignment.centerRight,
              child: controls,
            )),
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
    if (state.selectedView == LibraryView.albums) {
      return const AlbumsView();
    }
    if (state.selectedView == LibraryView.artists) {
      return const ArtistsView();
    }
    if (state.selectedView == LibraryView.genres) {
      return const GenresView();
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
