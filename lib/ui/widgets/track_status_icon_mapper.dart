import 'package:flutter/material.dart';

import '../../models/track_status_icon_state.dart';

/// Returns the icon used for a track timestamp status, or null when hidden.
IconData? iconForTrackStatus(TrackStatusIconState state) {
  return switch (state) {
    TrackStatusIconState.none => null,
    TrackStatusIconState.inQueue => Icons.downloading_rounded,
    TrackStatusIconState.downloaded => Icons.download_done_rounded,
  };
}
