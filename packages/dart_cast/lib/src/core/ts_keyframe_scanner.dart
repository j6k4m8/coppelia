import 'dart:io';
import 'dart:typed_data';

import '../utils/logger.dart';

/// Scans an MPEG-TS file for keyframe (IDR) positions.
///
/// Used to create HLS byte-range playlists with segments that start at
/// keyframe boundaries, which is required for correct playback on cast devices.
class TsKeyframeScanner {
  /// Scans [file] and returns byte offsets of TS packets containing keyframes.
  ///
  /// Uses two detection methods:
  /// 1. `random_access_indicator` in the adaptation field (fast, but not always set)
  /// 2. H.264 IDR NAL unit type 5 in PES payloads (reliable fallback)
  ///
  /// Always includes offset 0 (start of file) in the result.
  static List<int> findKeyframeOffsets(File file) {
    final offsets = <int>[0];
    final fileLength = file.lengthSync();
    if (fileLength < 188) return offsets;

    final raf = file.openSync();
    try {
      // Read in large chunks for performance
      const chunkSize = 188 * 1024; // ~192KB chunks
      final chunk = Uint8List(chunkSize);
      int fileOffset = 0;

      // Find initial sync byte
      final syncBuf = Uint8List(1);
      while (fileOffset < fileLength) {
        raf.readIntoSync(syncBuf);
        if (syncBuf[0] == 0x47) break;
        fileOffset++;
      }
      if (fileOffset >= fileLength) return offsets;
      raf.setPositionSync(fileOffset);

      while (fileOffset < fileLength) {
        final remaining = fileLength - fileOffset;
        final toRead = remaining < chunkSize ? remaining : chunkSize;
        final bytesRead = raf.readIntoSync(chunk, 0, toRead);
        if (bytesRead < 188) break;

        // Process each TS packet in the chunk
        for (int pos = 0; pos + 188 <= bytesRead; pos += 188) {
          if (chunk[pos] != 0x47) continue; // Skip if not sync byte

          final packetOffset = fileOffset + pos;

          // Method 1: Check random_access_indicator in adaptation field
          final adaptCtrl = (chunk[pos + 3] >> 4) & 0x03;
          if (adaptCtrl >= 2) {
            final adaptLen = chunk[pos + 4];
            if (adaptLen > 0) {
              final rai = (chunk[pos + 5] >> 6) & 0x01;
              if (rai == 1 && packetOffset > 0) {
                offsets.add(packetOffset);
                continue;
              }
            }
          }

          // Method 2: Check for H.264 IDR NAL unit in payload
          // Only check packets with payload (adaptCtrl == 1 or 3)
          // and payload_unit_start_indicator set (new PES packet)
          if (adaptCtrl == 1 || adaptCtrl == 3) {
            final pusi = (chunk[pos + 1] >> 6) & 0x01;
            if (pusi == 1) {
              // Find payload start
              int payloadStart = pos + 4;
              if (adaptCtrl == 3) {
                payloadStart += 1 + chunk[pos + 4]; // skip adaptation field
              }

              // Check for PES header (0x00 0x00 0x01) followed by video stream
              if (payloadStart + 9 < pos + 188) {
                if (chunk[payloadStart] == 0x00 &&
                    chunk[payloadStart + 1] == 0x00 &&
                    chunk[payloadStart + 2] == 0x01) {
                  final streamId = chunk[payloadStart + 3];
                  // Video stream IDs: 0xE0-0xEF
                  if (streamId >= 0xE0 && streamId <= 0xEF) {
                    // Scan payload for H.264 NAL start code + IDR type
                    for (int j = payloadStart + 9; j + 4 < pos + 188; j++) {
                      if (chunk[j] == 0x00 &&
                          chunk[j + 1] == 0x00 &&
                          chunk[j + 2] == 0x01) {
                        final nalType = chunk[j + 3] & 0x1F;
                        // NAL type 5 = IDR slice (keyframe)
                        if (nalType == 5 && packetOffset > 0) {
                          offsets.add(packetOffset);
                          break;
                        }
                      }
                      // Also check 4-byte start code (0x00 0x00 0x00 0x01)
                      if (j + 5 < pos + 188 &&
                          chunk[j] == 0x00 &&
                          chunk[j + 1] == 0x00 &&
                          chunk[j + 2] == 0x00 &&
                          chunk[j + 3] == 0x01) {
                        final nalType = chunk[j + 4] & 0x1F;
                        if (nalType == 5 && packetOffset > 0) {
                          offsets.add(packetOffset);
                          break;
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        fileOffset += bytesRead;
      }
    } finally {
      raf.closeSync();
    }

    // Deduplicate (a packet might match both methods)
    final unique = offsets.toSet().toList()..sort();

    CastLogger.debug(
      'TsKeyframeScanner: found ${unique.length} keyframes in '
      '${(fileLength / 1024 / 1024).toStringAsFixed(1)}MB file',
    );

    return unique;
  }

  /// Scans [file] and returns both byte offsets and PTS values at each keyframe.
  ///
  /// This is similar to [findKeyframeOffsets] but also extracts the PTS
  /// (Presentation Time Stamp) from the PES header at each keyframe boundary.
  /// The PTS values enable accurate segment duration calculation for HLS
  /// playlists, avoiding the drift caused by byte-proportion estimates on
  /// variable-bitrate content.
  ///
  /// Returns a list of [KeyframeInfo] containing both the byte offset and
  /// PTS value (in 90kHz clock units) for each keyframe. Returns null if
  /// PTS extraction fails or no keyframes with PTS are found.
  static List<KeyframeInfo>? findKeyframeOffsetsWithPts(File file) {
    final fileLength = file.lengthSync();
    if (fileLength < 188) return null;

    final results = <KeyframeInfo>[];
    final raf = file.openSync();
    try {
      const chunkSize = 188 * 1024; // ~192KB chunks
      final chunk = Uint8List(chunkSize);
      int fileOffset = 0;

      // Find initial sync byte
      final syncBuf = Uint8List(1);
      while (fileOffset < fileLength) {
        raf.readIntoSync(syncBuf);
        if (syncBuf[0] == 0x47) break;
        fileOffset++;
      }
      if (fileOffset >= fileLength) return null;
      raf.setPositionSync(fileOffset);

      while (fileOffset < fileLength) {
        final remaining = fileLength - fileOffset;
        final toRead = remaining < chunkSize ? remaining : chunkSize;
        final bytesRead = raf.readIntoSync(chunk, 0, toRead);
        if (bytesRead < 188) break;

        for (int pos = 0; pos + 188 <= bytesRead; pos += 188) {
          if (chunk[pos] != 0x47) continue;

          final packetOffset = fileOffset + pos;
          final adaptCtrl = (chunk[pos + 3] >> 4) & 0x03;

          bool isKeyframe = false;

          // Method 1: random_access_indicator
          if (adaptCtrl >= 2) {
            final adaptLen = chunk[pos + 4];
            if (adaptLen > 0) {
              final rai = (chunk[pos + 5] >> 6) & 0x01;
              if (rai == 1) isKeyframe = true;
            }
          }

          // Method 2: H.264 IDR NAL unit
          if (!isKeyframe && (adaptCtrl == 1 || adaptCtrl == 3)) {
            final pusi = (chunk[pos + 1] >> 6) & 0x01;
            if (pusi == 1) {
              int payloadStart = pos + 4;
              if (adaptCtrl == 3) {
                payloadStart += 1 + chunk[pos + 4];
              }
              if (payloadStart + 9 < pos + 188) {
                if (chunk[payloadStart] == 0x00 &&
                    chunk[payloadStart + 1] == 0x00 &&
                    chunk[payloadStart + 2] == 0x01) {
                  final streamId = chunk[payloadStart + 3];
                  if (streamId >= 0xE0 && streamId <= 0xEF) {
                    for (int j = payloadStart + 9; j + 4 < pos + 188; j++) {
                      if (chunk[j] == 0x00 &&
                          chunk[j + 1] == 0x00 &&
                          chunk[j + 2] == 0x01) {
                        final nalType = chunk[j + 3] & 0x1F;
                        if (nalType == 5) {
                          isKeyframe = true;
                          break;
                        }
                      }
                      if (j + 5 < pos + 188 &&
                          chunk[j] == 0x00 &&
                          chunk[j + 1] == 0x00 &&
                          chunk[j + 2] == 0x00 &&
                          chunk[j + 3] == 0x01) {
                        final nalType = chunk[j + 4] & 0x1F;
                        if (nalType == 5) {
                          isKeyframe = true;
                          break;
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          if (!isKeyframe) continue;

          // Try to extract PTS from this packet's PES header.
          // Only video stream packets (0xE0-0xEF) carry the PTS we want.
          int? pts;
          if (adaptCtrl == 1 || adaptCtrl == 3) {
            final pusi = (chunk[pos + 1] >> 6) & 0x01;
            if (pusi == 1) {
              int payloadStart = pos + 4;
              if (adaptCtrl == 3) {
                payloadStart += 1 + chunk[pos + 4];
              }
              if (payloadStart + 14 < pos + 188) {
                if (chunk[payloadStart] == 0x00 &&
                    chunk[payloadStart + 1] == 0x00 &&
                    chunk[payloadStart + 2] == 0x01) {
                  final streamId = chunk[payloadStart + 3];
                  if (streamId >= 0xE0 && streamId <= 0xEF) {
                    final ptsDtsFlags = (chunk[payloadStart + 7] >> 6) & 0x03;
                    if (ptsDtsFlags >= 2) {
                      final ptsOffset = payloadStart + 9;
                      if (ptsOffset + 5 <= pos + 188) {
                        pts =
                            ((chunk[ptsOffset] >> 1) & 0x07).toUnsigned(64) <<
                                30 |
                            (chunk[ptsOffset + 1]).toUnsigned(64) << 22 |
                            ((chunk[ptsOffset + 2] >> 1) & 0x7F).toUnsigned(
                                  64,
                                ) <<
                                15 |
                            (chunk[ptsOffset + 3]).toUnsigned(64) << 7 |
                            ((chunk[ptsOffset + 4] >> 1) & 0x7F).toUnsigned(64);
                      }
                    }
                  }
                }
              }
            }
          }

          // If we found a keyframe but no PTS in this packet (e.g. RAI-only
          // detection on a non-PUSI packet), we skip it — we need PTS for
          // accurate duration calculation. The keyframe will still be found
          // by the regular findKeyframeOffsets method for byte-range splitting.
          if (pts == null) continue;

          // Always include offset 0 if the first keyframe is at position 0,
          // or add offset 0 with this PTS if it's the first result.
          if (results.isEmpty && packetOffset > 0) {
            // There's content before the first detected keyframe — include
            // offset 0 with the same PTS as the first keyframe (best guess).
            results.add(KeyframeInfo(offset: 0, pts: pts));
          }

          results.add(KeyframeInfo(offset: packetOffset, pts: pts));
        }

        fileOffset += bytesRead;
      }
    } finally {
      raf.closeSync();
    }

    if (results.isEmpty) return null;

    // Deduplicate by offset
    final seen = <int>{};
    final unique = <KeyframeInfo>[];
    for (final kf in results) {
      if (seen.add(kf.offset)) {
        unique.add(kf);
      }
    }
    unique.sort((a, b) => a.offset.compareTo(b.offset));

    CastLogger.debug(
      'TsKeyframeScanner: found ${unique.length} keyframes with PTS in '
      '${(fileLength / 1024 / 1024).toStringAsFixed(1)}MB file '
      '(PTS range: ${(unique.first.pts / 90000).toStringAsFixed(3)}s - '
      '${(unique.last.pts / 90000).toStringAsFixed(3)}s)',
    );

    return unique;
  }

  /// Reads the first video PTS (Presentation Time Stamp) from [file].
  ///
  /// Returns the PTS value in the 90kHz clock used by MPEG-TS, or null
  /// if no video PTS is found in the first ~192KB of the file.
  ///
  /// This is needed because TS files from stream recordings often have
  /// a non-zero starting PTS. When serving TS segments via HLS to
  /// Chromecast, the player uses this PTS for its timeline, causing
  /// subtitle desync and wrong segment selection if not accounted for.
  static int? readFirstVideoPts(File file) {
    final fileLength = file.lengthSync();
    if (fileLength < 188) return null;

    final raf = file.openSync();
    try {
      const chunkSize = 188 * 1024;
      final chunk = Uint8List(chunkSize);
      final toRead = fileLength < chunkSize ? fileLength : chunkSize;
      final bytesRead = raf.readIntoSync(chunk, 0, toRead);

      for (int pos = 0; pos + 188 <= bytesRead; pos += 188) {
        if (chunk[pos] != 0x47) continue;

        final adaptCtrl = (chunk[pos + 3] >> 4) & 0x03;
        if (adaptCtrl != 1 && adaptCtrl != 3) continue;

        final pusi = (chunk[pos + 1] >> 6) & 0x01;
        if (pusi != 1) continue;

        int payloadStart = pos + 4;
        if (adaptCtrl == 3) {
          payloadStart += 1 + chunk[pos + 4];
        }

        if (payloadStart + 14 >= pos + 188) continue;

        // Check for PES header: 0x00 0x00 0x01
        if (chunk[payloadStart] != 0x00 ||
            chunk[payloadStart + 1] != 0x00 ||
            chunk[payloadStart + 2] != 0x01) {
          continue;
        }

        final streamId = chunk[payloadStart + 3];
        // Video stream IDs: 0xE0-0xEF
        if (streamId < 0xE0 || streamId > 0xEF) continue;

        // PES header flags byte 2: PTS/DTS flags in bits 7-6
        final ptsDtsFlags = (chunk[payloadStart + 7] >> 6) & 0x03;
        if (ptsDtsFlags < 2) continue; // No PTS present

        // Parse 33-bit PTS from 5 bytes
        final ptsOffset = payloadStart + 9;
        if (ptsOffset + 5 > pos + 188) continue;

        final pts =
            ((chunk[ptsOffset] >> 1) & 0x07).toUnsigned(64) << 30 |
            (chunk[ptsOffset + 1]).toUnsigned(64) << 22 |
            ((chunk[ptsOffset + 2] >> 1) & 0x7F).toUnsigned(64) << 15 |
            (chunk[ptsOffset + 3]).toUnsigned(64) << 7 |
            ((chunk[ptsOffset + 4] >> 1) & 0x7F).toUnsigned(64);

        CastLogger.info(
          'TsKeyframeScanner: first video PTS = $pts '
          '(${(pts / 90000).toStringAsFixed(3)}s)',
        );
        return pts;
      }
    } finally {
      raf.closeSync();
    }

    return null;
  }

  /// Extracts PAT and PMT packets from the beginning of [file].
  ///
  /// In MPEG-TS, PAT (PID 0x0000) lists which PIDs carry PMTs, and PMT
  /// describes the streams (video, audio, subtitles). HLS requires each
  /// segment to be independently decodable, so PAT+PMT must appear at
  /// the start of every segment. When we split a file into virtual
  /// byte-range segments, only the first segment has the original PAT/PMT.
  ///
  /// Returns the concatenated PAT+PMT packets (typically 376 bytes for
  /// one PAT + one PMT), or null if not found. These bytes should be
  /// prepended to every virtual segment response.
  static Uint8List? extractPatPmt(File file) {
    final fileLength = file.lengthSync();
    if (fileLength < 188) return null;

    final raf = file.openSync();
    try {
      // Read first 64KB — PAT/PMT are always near the start
      const readSize = 188 * 340; // ~64KB
      final toRead = fileLength < readSize ? fileLength : readSize;
      final buf = Uint8List(toRead);
      raf.readIntoSync(buf, 0, toRead);

      Uint8List? patPacket;
      Uint8List? pmtPacket;
      int? pmtPid;

      for (int pos = 0; pos + 188 <= toRead; pos += 188) {
        if (buf[pos] != 0x47) continue;

        final pid = ((buf[pos + 1] & 0x1F) << 8) | buf[pos + 2];

        // PAT is always PID 0
        if (pid == 0 && patPacket == null) {
          patPacket = Uint8List.fromList(buf.sublist(pos, pos + 188));

          // Parse PAT to find PMT PID: skip 4-byte TS header + adaptation
          // field + 1-byte pointer field, then the PAT table.
          final adaptCtrl = (buf[pos + 3] >> 4) & 0x03;
          int payloadStart = pos + 4;
          if (adaptCtrl == 3) {
            payloadStart += 1 + buf[pos + 4];
          }
          // Skip pointer field
          payloadStart += 1 + buf[payloadStart];
          // PAT header: table_id(1) + flags(2) + transport_stream_id(2)
          // + version/flags(1) + section_number(1) + last_section(1)
          // Then program entries: program_number(2) + PMT_PID(2)
          if (payloadStart + 12 < pos + 188) {
            final sectionLength =
                ((buf[payloadStart + 1] & 0x0F) << 8) | buf[payloadStart + 2];
            // Skip 8 bytes of PAT header to reach program entries
            final entriesStart = payloadStart + 8;
            final entriesEnd =
                payloadStart + 3 + sectionLength - 4; // minus CRC
            if (entriesEnd <= pos + 188) {
              for (int e = entriesStart; e + 4 <= entriesEnd; e += 4) {
                final progNum = (buf[e] << 8) | buf[e + 1];
                if (progNum != 0) {
                  // Non-NIT program — this is the PMT PID
                  pmtPid = ((buf[e + 2] & 0x1F) << 8) | buf[e + 3];
                  break;
                }
              }
            }
          }
        }

        // PMT
        if (pmtPid != null && pid == pmtPid && pmtPacket == null) {
          pmtPacket = Uint8List.fromList(buf.sublist(pos, pos + 188));
        }

        if (patPacket != null && pmtPacket != null) break;
      }

      if (patPacket == null) return null;

      // Concatenate PAT + PMT (PMT may be null for single-stream files)
      if (pmtPacket != null) {
        final result = Uint8List(376);
        result.setRange(0, 188, patPacket);
        result.setRange(188, 376, pmtPacket);
        CastLogger.info(
          'TsKeyframeScanner: extracted PAT+PMT (376 bytes, PMT PID=$pmtPid)',
        );
        return result;
      } else {
        CastLogger.info('TsKeyframeScanner: extracted PAT only (188 bytes)');
        return patPacket;
      }
    } finally {
      raf.closeSync();
    }
  }
}

/// A keyframe position with its associated PTS value.
class KeyframeInfo {
  /// Byte offset of the keyframe in the TS file.
  final int offset;

  /// PTS value in 90kHz clock units.
  final int pts;

  /// PTS value converted to seconds.
  double get ptsSeconds => pts / 90000.0;

  KeyframeInfo({required this.offset, required this.pts});
}
