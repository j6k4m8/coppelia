import 'dart:convert';
import 'dart:io';

import '../utils/logger.dart';
import 'media_source.dart';

/// Serves files using raw HTTP/1.0 responses over detached sockets.
///
/// Some DLNA renderers (e.g., TCL Google TV) reject HTTP/1.1 responses
/// from Dart's built-in HttpServer. This class writes HTTP/1.0 headers
/// directly to the socket, matching the behavior of Python's
/// SimpleHTTPServer which works universally with DLNA renderers.
///
/// Usage:
/// ```dart
/// final socket = await request.response.detachSocket(writeHeaders: false);
/// try {
///   await Http10FileServer.serve(socket, file, request);
/// } finally {
///   await socket.close();
/// }
/// ```
class Http10FileServer {
  Http10FileServer._();

  /// Serves a file over a detached socket using HTTP/1.0 protocol.
  ///
  /// Supports:
  /// - Full file requests (200 OK)
  /// - Range requests with `bytes=` (206 Partial Content)
  /// - HEAD requests (headers only, no body)
  /// - `Accept-Ranges: bytes` header to advertise seek support
  ///
  /// The [contentType] defaults to `application/octet-stream` if not provided.
  static Future<void> serve(
    Socket socket,
    File file,
    HttpRequest request, {
    ContentType? contentType,
  }) async {
    final source = MediaSource(
      length: await file.length(),
      contentType: contentType?.mimeType ?? 'application/octet-stream',
      read: file.openRead,
    );
    return serveSource(socket, source, request);
  }

  /// Serves any [MediaSource] over a detached socket, with the same HTTP/1.0
  /// framing and range handling [serve] gives a file.
  ///
  /// This is what lets content that is not a file on disk — a Flutter asset,
  /// an Android `content://` URI, decrypted bytes — reach a DLNA renderer
  /// while still supporting seeking.
  static Future<void> serveSource(
    Socket socket,
    MediaSource source,
    HttpRequest request,
  ) async {
    final fileLength = source.length;
    final mime = source.contentType;
    final rangeHeader = request.headers.value('Range');

    int start = 0;
    int end = fileLength - 1;
    int statusCode = 200;
    String statusText = 'OK';

    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final rangeSpec = rangeHeader.substring('bytes='.length);
      final parts = rangeSpec.split('-');

      if (parts[0].isEmpty) {
        // Suffix range: bytes=-500 means last 500 bytes
        final suffixLength = int.parse(parts[1]);
        start = (fileLength - suffixLength).clamp(0, fileLength - 1);
      } else {
        start = int.parse(parts[0]);
        if (parts[1].isNotEmpty) {
          end = int.parse(parts[1]).clamp(0, fileLength - 1);
        }
      }

      // Always respond 206 for Range requests — tells the renderer
      // that byte-range seeking is supported.
      statusCode = 206;
      statusText = 'Partial Content';
    }

    // Validate range: start must not exceed end or file length
    if (start > end || start >= fileLength) {
      final errorHeaders = StringBuffer();
      errorHeaders.write('HTTP/1.0 416 Range Not Satisfiable\r\n');
      errorHeaders.write('Content-Range: bytes */$fileLength\r\n');
      errorHeaders.write('Content-Length: 0\r\n');
      errorHeaders.write('\r\n');
      socket.add(utf8.encode(errorHeaders.toString()));
      return;
    }

    final length = end - start + 1;

    // Write HTTP/1.0 response headers
    final headers = StringBuffer();
    headers.write('HTTP/1.0 $statusCode $statusText\r\n');
    headers.write('Content-Type: $mime\r\n');
    headers.write('Content-Length: $length\r\n');
    headers.write('Accept-Ranges: bytes\r\n');
    if (statusCode == 206) {
      headers.write('Content-Range: bytes $start-$end/$fileLength\r\n');
    }
    headers.write('\r\n');

    CastLogger.debug(
      'Http10FileServer: ${request.method} $mime '
      '${start == 0 && end == fileLength - 1 ? 'full file' : 'bytes $start-$end/$fileLength'} '
      '($length bytes) status=$statusCode',
    );

    socket.add(utf8.encode(headers.toString()));

    // HEAD — no body
    if (request.method == 'HEAD') {
      return;
    }

    // Stream the requested range. `end` is inclusive here, and
    // MediaSourceReader takes an exclusive end, matching File.openRead.
    // The reader may open asynchronously, so resolve it before piping.
    final stream = await source.read(start, end + 1);
    await stream.pipe(socket);
  }
}
