import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/artist.dart';
import '../../core/formatters.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import 'artist_context_menu.dart';
import 'library_browse_view.dart';
import 'library_card.dart';
import 'library_list_tile.dart';
import 'offline_empty_view.dart';

/// Displays offline-ready artists.
class OfflineArtistsView extends StatelessWidget {
  /// Creates the offline artists view.
  const OfflineArtistsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return FutureBuilder<List<Artist>>(
      future: state.loadOfflineArtists(),
      builder: (context, snapshot) {
        final artists = snapshot.data ?? const <Artist>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            artists.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (artists.isEmpty) {
          return OfflineEmptyView(
            title: LibraryView.offlineArtists.title,
            subtitle: LibraryView.offlineArtists.subtitle,
          );
        }
        return LibraryBrowseView<Artist>(
          view: LibraryView.offlineArtists,
          title: LibraryView.offlineArtists.title,
          items: artists,
          titleBuilder: (artist) => artist.name,
          subtitleBuilder: (artist) => formatArtistSubtitle(artist),
          gridItemBuilder: (context, artist) {
            final subtitle = formatArtistSubtitle(artist);
            return LibraryCard(
              title: artist.name,
              subtitle: subtitle,
              imageUrl: artist.imageUrl,
              icon: Icons.people_alt,
              onTap: () => state.selectArtist(artist, offlineOnly: true),
              onContextMenu: (position) => showArtistContextMenu(
                context,
                position,
                artist,
                state,
              ),
            );
          },
          listItemBuilder: (context, artist) {
            final subtitle = formatArtistSubtitle(artist);
            return LibraryListTile(
              title: artist.name,
              subtitle: subtitle,
              imageUrl: artist.imageUrl,
              icon: Icons.people_alt,
              onTap: () => state.selectArtist(artist, offlineOnly: true),
              onContextMenu: (position) => showArtistContextMenu(
                context,
                position,
                artist,
                state,
              ),
            );
          },
        );
      },
    );
  }
}
