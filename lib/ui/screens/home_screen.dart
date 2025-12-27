import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/library_view.dart';
import '../../state/now_playing_layout.dart';
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
import '../widgets/genre_detail_view.dart';

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
    final bodyContent = Row(
      children: [
        const SidebarNavigation(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  userName: state.session?.userName ?? 'Listener',
                  playlistCount: state.playlists.length,
                  trackCount: state.playlists.fold(
                    0,
                    (total, playlist) => total + playlist.trackCount,
                  ),
                  state: state,
                ),
                const SizedBox(height: 24),
                if (state.isLoadingLibrary)
                  const LinearProgressIndicator(minHeight: 2),
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
    required this.state,
  });

  final String userName;
  final int playlistCount;
  final int trackCount;
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good evening, ${widget.userName}',
              style: theme.textTheme.headlineLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.playlistCount} playlists • ${widget.trackCount} tracks',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
        Row(
          children: [
            SizedBox(
              width: 260,
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
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.music_note, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Copellia • macOS',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
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
    if (state.selectedView == LibraryView.settings) {
      return const SettingsView();
    }
    return LibraryPlaceholderView(view: state.selectedView);
  }
}
