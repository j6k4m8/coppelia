/// Converts between subtitle formats (SRT <-> VTT).
class SubtitleConverter {
  /// Converts SRT content to WebVTT format.
  ///
  /// SRT format:
  /// ```
  /// 1
  /// 00:00:01,000 --> 00:00:04,000
  /// Hello world
  /// ```
  ///
  /// VTT format:
  /// ```
  /// WEBVTT
  ///
  /// 00:00:01.000 --> 00:00:04.000
  /// Hello world
  /// ```
  static String srtToVtt(String srt) {
    final lines = srt.split('\n');
    final vtt = StringBuffer('WEBVTT\n\n');

    for (final line in lines) {
      // Replace SRT comma timestamps with VTT dot timestamps
      // SRT: 00:00:01,000 --> 00:00:04,000
      // VTT: 00:00:01.000 --> 00:00:04.000
      if (line.contains(' --> ')) {
        vtt.writeln(line.replaceAll(',', '.'));
      } else if (RegExp(r'^\d+$').hasMatch(line.trim())) {
        // Skip sequence numbers (SRT has them, VTT doesn't need them)
        continue;
      } else {
        vtt.writeln(line);
      }
    }
    return vtt.toString();
  }

  /// Converts WebVTT content to SRT format.
  ///
  /// Reverses the VTT→SRT transformation: removes WEBVTT header,
  /// replaces dot timestamps with commas, and adds sequence numbers.
  static String vttToSrt(String vtt) {
    final lines = vtt.split('\n');
    final srt = StringBuffer();
    int sequence = 1;
    bool headerDone = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Skip WEBVTT header and metadata lines
      if (!headerDone) {
        if (line.trimLeft().startsWith('WEBVTT')) continue;
        if (line.startsWith('X-TIMESTAMP-MAP')) continue;
        if (line.startsWith('NOTE')) continue;
        if (line.trim().isEmpty) continue;
        headerDone = true;
      }

      if (line.contains(' --> ')) {
        // Add sequence number before timestamp
        srt.writeln(sequence++);
        // Replace VTT dot timestamps with SRT comma timestamps
        // Only target the millisecond separator, not other dots.
        // Also expand MM:SS.mmm to 00:MM:SS,mmm for SRT compatibility.
        srt.writeln(
          line.replaceAllMapped(
            RegExp(r'(\d{2}:\d{2}:\d{2})\.(\d{3})|(\d{2}:\d{2})\.(\d{3})'),
            (m) {
              if (m[1] != null) {
                // HH:MM:SS.mmm → HH:MM:SS,mmm
                return '${m[1]},${m[2]}';
              } else {
                // MM:SS.mmm → 00:MM:SS,mmm
                return '00:${m[3]},${m[4]}';
              }
            },
          ),
        );
      } else {
        srt.writeln(line);
      }
    }
    return srt.toString().trimRight();
  }

  /// Detects if content is SRT format (starts with a number, not WEBVTT).
  static bool isSrt(String content) {
    final trimmed = content.trimLeft();
    return !trimmed.startsWith('WEBVTT') &&
        RegExp(r'^\d+\s*\n').hasMatch(trimmed);
  }

  /// Strips `X-TIMESTAMP-MAP` from VTT content.
  ///
  /// HLS subtitle segments use this header to map MPEG-TS PTS timestamps
  /// to local VTT timestamps. When serving VTT as a sidecar track (not
  /// as HLS segments), this header causes cast devices like Chromecast
  /// (Shaka Player) to apply an incorrect offset, making subtitles out
  /// of sync. Removing it ensures timestamps are used as-is.
  static String stripTimestampMap(String vtt) {
    return vtt.replaceAll(
      RegExp(r'X-TIMESTAMP-MAP[^\n]*\n?', caseSensitive: false),
      '',
    );
  }

  /// Converts VTT or SRT content to ASS (Advanced SubStation Alpha) format
  /// with customizable styling.
  ///
  /// ASS supports font, size, color, outline, shadow, and background.
  /// This is useful for MKV containers where the player renders the
  /// subtitle style defined in the ASS header.
  ///
  /// [fontSize] controls the subtitle size (default 20).
  /// [outlineSize] controls the black border thickness (default 2).
  /// [shadowDepth] controls the shadow offset (default 1).
  /// [marginV] controls the vertical margin from the bottom (default 30).
  static String toAss(
    String content, {
    int fontSize = 20,
    int outlineSize = 2,
    int shadowDepth = 1,
    int marginV = 30,
  }) {
    // Parse cues from VTT or SRT
    String normalized = content;
    bool isVttContent = content.trimLeft().startsWith('WEBVTT');

    if (!isVttContent && isSrt(content)) {
      // Convert SRT timestamps to VTT-style for uniform parsing
      normalized = content.replaceAll(',', '.');
    }

    final lines = normalized.split('\n');
    final dialogues = StringBuffer();
    bool headerDone = !isVttContent;
    String? currentTiming;
    final textLines = <String>[];

    void flushCue() {
      if (currentTiming != null && textLines.isNotEmpty) {
        // Parse "HH:MM:SS.mmm --> HH:MM:SS.mmm"
        final parts = currentTiming!.split(' --> ');
        if (parts.length == 2) {
          final start = _vttTimeToAss(parts[0].trim());
          final end = _vttTimeToAss(parts[1].trim().split(' ').first);
          final text = textLines.join('\\N');
          dialogues.writeln('Dialogue: 0,$start,$end,Default,,0,0,0,,$text');
        }
      }
      currentTiming = null;
      textLines.clear();
    }

    for (final line in lines) {
      if (!headerDone) {
        if (line.trimLeft().startsWith('WEBVTT')) continue;
        if (line.startsWith('X-TIMESTAMP-MAP')) continue;
        if (line.startsWith('NOTE')) continue;
        if (line.trim().isEmpty) continue;
        headerDone = true;
      }

      if (line.contains(' --> ')) {
        flushCue();
        currentTiming = line;
      } else if (line.trim().isEmpty) {
        flushCue();
      } else if (RegExp(r'^\d+$').hasMatch(line.trim())) {
        // Skip SRT sequence numbers
        continue;
      } else {
        // Strip VTT tags like <i>, </i>, <b>, etc.
        textLines.add(line.replaceAll(RegExp(r'<[^>]+>'), ''));
      }
    }
    flushCue();

    // ASS header with style definition
    // Colors in ASS are &HAABBGGRR format (hex, reversed RGB)
    // &H00FFFFFF = white, &H00000000 = black
    // BorderStyle: 1 = outline + shadow, 3 = opaque box
    return '''[Script Info]
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080
WrapStyle: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,$fontSize,&H00FFFFFF,&H000000FF,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,$outlineSize,$shadowDepth,2,20,20,$marginV,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
$dialogues''';
  }

  /// Converts VTT timestamp (HH:MM:SS.mmm or MM:SS.mmm) to ASS format (H:MM:SS.cc).
  static String _vttTimeToAss(String vttTime) {
    // Handle both HH:MM:SS.mmm and MM:SS.mmm
    final parts = vttTime.split(':');
    int hours = 0;
    int minutes;
    double seconds;

    if (parts.length == 3) {
      hours = int.parse(parts[0]);
      minutes = int.parse(parts[1]);
      seconds = double.parse(parts[2]);
    } else {
      minutes = int.parse(parts[0]);
      seconds = double.parse(parts[1]);
    }

    final centiseconds = ((seconds % 1) * 100).round();
    final wholeSeconds = seconds.floor();

    return '$hours:${minutes.toString().padLeft(2, '0')}:${wholeSeconds.toString().padLeft(2, '0')}.${centiseconds.toString().padLeft(2, '0')}';
  }

  /// Injects `X-TIMESTAMP-MAP` into VTT content to align subtitle
  /// timestamps with an MPEG-TS PTS timeline.
  ///
  /// [mpegTsPts] is the first video PTS value (90kHz clock). This tells
  /// the cast device's HLS player that VTT timestamp 00:00:00.000
  /// corresponds to MPEG-TS PTS [mpegTsPts], aligning subtitles with
  /// the video stream.
  static String injectTimestampMap(String vtt, int mpegTsPts) {
    final header = 'X-TIMESTAMP-MAP=MPEGTS:$mpegTsPts,LOCAL:00:00:00.000';
    // Insert after WEBVTT header line
    return vtt.replaceFirst(RegExp(r'(WEBVTT[^\n]*\n)'), '\$1$header\n');
  }
}
