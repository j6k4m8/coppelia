/// Streaming MPEG-TS packet filter that drops DVB-only tables.
///
/// Some HLS providers emit TS segments whose leading packets sit on
/// DVB-specific PIDs (Service Description Table on 0x0011, Network
/// Information Table on 0x0010, Event Information Table on 0x0012, …).
/// Chromecast's Shaka Player only probes the first few packets of a
/// segment to discover the PAT (`PID 0x0000`). If the PAT isn't in that
/// window — because DVB tables came first — the demuxer rejects the
/// segment and Cast returns `LOAD_FAILED` with no diagnostic detail.
///
/// Lenient demuxers (FFmpeg, mdk, VLC) scan the whole segment to find
/// PAT, so the same source plays fine in local playback. The fix on the
/// Cast path is to strip the DVB tables on egress so the receiver sees
/// PAT in the very first packet.
///
/// Usage (stream-friendly, handles arbitrary chunk boundaries):
/// ```dart
/// final filter = TsDvbStripper();
/// await for (final chunk in upstream) {
///   final out = filter.process(chunk);
///   if (out.isNotEmpty) sink.add(out);
/// }
/// final tail = filter.flush();
/// if (tail.isNotEmpty) sink.add(tail);
/// ```
class TsDvbStripper {
  /// MPEG-TS packet size in bytes.
  static const int packetSize = 188;

  /// PIDs of DVB-only tables that are not required for HLS playback and
  /// are likely to confuse strict TS demuxers when they appear before
  /// the PAT.
  static const Set<int> dvbPids = {
    0x0010, // NIT  — Network Information Table
    0x0011, // SDT/BAT — Service Description / Bouquet Association
    0x0012, // EIT  — Event Information Table
    0x0013, // RST  — Running Status Table
    0x0014, // TDT/TOT — Time / Time Offset Table
    0x001E, // DIT  — Discontinuity Information Table
    0x001F, // SIT  — Selection Information Table
  };

  /// Bytes carried over from the previous chunk that didn't form a
  /// complete TS packet on their own.
  final List<int> _carry = [];

  /// Count of packets kept (not on a DVB PID).
  int packetsKept = 0;

  /// Count of packets dropped (on a DVB PID).
  int packetsDropped = 0;

  /// Histogram of all PIDs seen in the stream (kept + dropped), keyed by
  /// PID. Used to diagnose TS structure issues — e.g. "no PAT (0x0000)
  /// present in this segment" or "audio PID not announced in PMT".
  final Map<int, int> pidCounts = {};

  /// Order in which previously-unseen PIDs appeared, useful for spotting
  /// "PAT not first" patterns that stricter demuxers reject.
  final List<int> pidArrivalOrder = [];

  /// Filters [chunk] and returns the bytes that should be written to the
  /// downstream response. Whole TS packets are kept or dropped; partial
  /// trailing packets are buffered internally until enough bytes arrive.
  List<int> process(List<int> chunk) {
    if (chunk.isEmpty) return const <int>[];

    // Combine carry + new chunk. Most segments arrive in just a few
    // chunks so allocation cost is negligible.
    final buf = [..._carry, ...chunk];
    _carry.clear();

    final output = <int>[];
    var i = 0;

    while (i + packetSize <= buf.length) {
      if (buf[i] != 0x47) {
        // Resync — search forward for the next sync byte. This handles
        // garbage at the start of the very first chunk and recovers if
        // a non-188-aligned upstream injects padding.
        var next = i + 1;
        while (next < buf.length && buf[next] != 0x47) {
          next++;
        }
        i = next;
        continue;
      }

      // Bytes 1–2 carry the PID in the low 13 bits.
      final pid = ((buf[i + 1] & 0x1F) << 8) | buf[i + 2];

      // Histogram + arrival order — capped at first 4096 distinct PIDs
      // so a malformed stream can't grow the map unboundedly.
      if (!pidCounts.containsKey(pid)) {
        if (pidArrivalOrder.length < 4096) {
          pidArrivalOrder.add(pid);
        }
      }
      pidCounts[pid] = (pidCounts[pid] ?? 0) + 1;

      if (dvbPids.contains(pid)) {
        packetsDropped++;
      } else {
        packetsKept++;
        output.addAll(buf.getRange(i, i + packetSize));
      }

      i += packetSize;
    }

    // Stash any incomplete trailing packet for the next call.
    if (i < buf.length) {
      _carry.addAll(buf.getRange(i, buf.length));
    }
    return output;
  }

  /// Final byte flush. Returns any leftover bytes that didn't form a
  /// complete 188-byte packet — passed through unfiltered so we don't
  /// truncate the response if upstream returned a non-multiple of 188.
  /// In practice this is almost always empty for well-formed TS files.
  List<int> flush() {
    final remaining = List<int>.from(_carry);
    _carry.clear();
    return remaining;
  }

  /// Whether this stripper actually changed anything.
  bool get didDropAny => packetsDropped > 0;

  @override
  String toString() =>
      'TsDvbStripper(kept=$packetsKept, dropped=$packetsDropped)';
}
