import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/artist.dart';
import '../../state/app_state.dart';
import '../../state/library_view.dart';
import 'artist_context_menu.dart';
import 'artist_browse_view.dart';

/// Displays artist browsing grid.
class ArtistsView extends StatelessWidget {
  /// Creates the artists view.
  const ArtistsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ArtistBrowseView(
      view: LibraryView.artists,
      title: 'Artists',
      artists: state.artists,
      onSelect: state.selectArtist,
      onContextMenu: (context, position, artist) =>
          showArtistContextMenu(context, position, artist, state),
    );
  }
}
