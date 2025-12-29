import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../models/playlist.dart';
import '../../state/app_state.dart';

/// Result from a playlist picker dialog.
class PlaylistPickerResult {
  /// Creates a selection result.
  const PlaylistPickerResult({
    required this.playlist,
    required this.isNew,
  });

  /// Selected playlist.
  final Playlist playlist;

  /// Indicates if the playlist was newly created.
  final bool isNew;
}

/// Prompts for a playlist name.
Future<String?> promptPlaylistName(
  BuildContext context, {
  required String title,
  String? initialName,
  String confirmLabel = 'Save',
}) async {
  final controller = TextEditingController(text: initialName ?? '');
  String value = controller.text;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          onChanged: (text) => setState(() {
            value = text;
          }),
          onSubmitted: (_) => Navigator.of(context).pop(value),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: value.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(value),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  final trimmed = result?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

/// Shows a confirmation dialog for deleting a playlist.
Future<bool> confirmPlaylistDelete(
  BuildContext context,
  Playlist playlist,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete playlist?'),
      content: Text(
        '“${playlist.name}” will be deleted from your library.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Prompts to create a playlist and optionally add tracks.
Future<Playlist?> showCreatePlaylistDialog(
  BuildContext context, {
  List<MediaItem> initialTracks = const [],
  String? initialName,
}) async {
  final state = context.read<AppState>();
  final name = await promptPlaylistName(
    context,
    title: 'New playlist',
    initialName: initialName,
    confirmLabel: 'Create',
  );
  if (name == null) {
    return null;
  }
  return state.createPlaylist(name: name, initialTracks: initialTracks);
}

/// Shows a playlist picker with an optional create action.
Future<PlaylistPickerResult?> showPlaylistPickerDialog(
  BuildContext context, {
  List<MediaItem> initialTracks = const [],
  bool allowCreate = true,
}) async {
  final state = context.read<AppState>();
  final playlists = state.playlists;
  final choice = await showDialog<_PlaylistPickerChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add to playlist'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (allowCreate)
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('New playlist'),
                onTap: () => Navigator.of(context).pop(
                  const _PlaylistPickerChoice.createNew(),
                ),
              ),
            if (playlists.isEmpty)
              const ListTile(
                title: Text('No playlists yet'),
              )
            else
              for (final playlist in playlists)
                ListTile(
                  leading: const Icon(Icons.queue_music),
                  title: Text(playlist.name),
                  onTap: () => Navigator.of(context).pop(
                    _PlaylistPickerChoice.select(playlist),
                  ),
                ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
  if (choice == null) {
    return null;
  }
  if (choice.createNew) {
    final created = await showCreatePlaylistDialog(
      context,
      initialTracks: initialTracks,
    );
    if (created == null) {
      return null;
    }
    return PlaylistPickerResult(playlist: created, isNew: true);
  }
  if (choice.playlist == null) {
    return null;
  }
  return PlaylistPickerResult(playlist: choice.playlist!, isNew: false);
}

class _PlaylistPickerChoice {
  const _PlaylistPickerChoice.select(this.playlist) : createNew = false;
  const _PlaylistPickerChoice.createNew()
      : playlist = null,
        createNew = true;

  final Playlist? playlist;
  final bool createNew;
}
