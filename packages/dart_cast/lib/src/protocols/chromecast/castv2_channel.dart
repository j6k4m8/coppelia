/// CASTV2 TLS channel with length-prefixed protobuf message framing.
///
/// Handles connecting to a Chromecast device over TLS on port 8009,
/// serialising/deserialising [CastMessage] protobuf messages, and
/// framing them with a 4-byte big-endian length prefix.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_cast/src/protocols/chromecast/proto/cast_channel.dart';

/// Manages a TLS connection to a Chromecast and provides
/// length-prefixed protobuf message framing.
class CastV2Channel {
  /// The underlying TLS socket (null until [connect] is called).
  SecureSocket? _socket;

  /// Controller that emits parsed [CastMessage]s from the socket.
  StreamController<CastMessage>? _messageController;

  /// Subscription to the parsed message stream from the socket.
  StreamSubscription<CastMessage>? _socketSubscription;

  // ---------------------------------------------------------------------------
  // Static framing helpers (public for unit-testing)
  // ---------------------------------------------------------------------------

  /// Encodes [length] as a 4-byte big-endian [Uint8List].
  static Uint8List writeLength(int length) {
    final data = ByteData(4)..setUint32(0, length, Endian.big);
    return data.buffer.asUint8List();
  }

  /// Decodes a 4-byte big-endian [Uint8List] into an integer.
  static int readLength(Uint8List bytes) {
    return ByteData.sublistView(bytes).getUint32(0, Endian.big);
  }

  /// Wraps a [CastMessage] in a length-prefixed frame suitable for the wire.
  ///
  /// Returns a [Uint8List] of `4 + N` bytes where the first 4 bytes are
  /// the big-endian uint32 length of the protobuf payload.
  static Uint8List frameMessage(CastMessage message) {
    final protobufBytes = message.writeToBuffer();
    final header = writeLength(protobufBytes.length);
    final frame = Uint8List(4 + protobufBytes.length);
    frame.setRange(0, 4, header);
    frame.setRange(4, frame.length, protobufBytes);
    return frame;
  }

  /// Transforms a raw byte stream into a stream of [CastMessage]s.
  ///
  /// Handles partial reads — buffers data until a complete
  /// length-prefixed message is available.
  static Stream<CastMessage> parseMessages(Stream<List<int>> source) async* {
    final buffer = BytesBuilder(copy: false);

    await for (final chunk in source) {
      buffer.add(chunk);

      // Process as many complete messages as the buffer contains.
      while (true) {
        final accumulated = buffer.takeBytes();

        if (accumulated.length < 4) {
          // Not enough data for the length header — put it back.
          buffer.add(accumulated);
          break;
        }

        final messageLength = readLength(
          Uint8List.fromList(accumulated.sublist(0, 4)),
        );

        if (accumulated.length < 4 + messageLength) {
          // Header read but body incomplete — put everything back.
          buffer.add(accumulated);
          break;
        }

        // Full message available.
        final messageBytes = accumulated.sublist(4, 4 + messageLength);
        final remaining = accumulated.sublist(4 + messageLength);

        yield CastMessage.fromBuffer(messageBytes);

        // Put any leftover bytes back for the next iteration.
        if (remaining.isNotEmpty) {
          buffer.add(remaining);
        } else {
          break;
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Connection lifecycle
  // ---------------------------------------------------------------------------

  /// Opens a TLS connection to [host] on [port] (default 8009).
  ///
  /// Chromecast devices use self-signed certificates, so certificate
  /// verification is intentionally skipped.
  Future<void> connect(String host, {int port = 8009}) async {
    _socket = await SecureSocket.connect(
      host,
      port,
      onBadCertificate: (_) => true,
      timeout: const Duration(seconds: 5),
    );

    _messageController = StreamController<CastMessage>.broadcast();

    _socketSubscription = parseMessages(_socket!).listen(
      _messageController!.add,
      onError: _messageController!.addError,
      onDone: () => _messageController!.close(),
    );
  }

  /// Stream of incoming [CastMessage]s from the device.
  Stream<CastMessage> get messageStream {
    if (_messageController == null) {
      throw StateError('Not connected. Call connect() first.');
    }
    return _messageController!.stream;
  }

  /// Sends a [CastMessage] built from the given parameters.
  void sendMessage({
    required String namespace,
    required String sourceId,
    required String destinationId,
    required String payload,
  }) {
    if (_socket == null) {
      throw StateError('Not connected. Call connect() first.');
    }

    final message =
        CastMessage()
          ..protocolVersion = CastMessage_ProtocolVersion.CASTV2_1_0
          ..sourceId = sourceId
          ..destinationId = destinationId
          ..namespace_ = namespace
          ..payloadType = CastMessage_PayloadType.STRING
          ..payloadUtf8 = payload;

    final framed = frameMessage(message);
    _socket!.add(framed);
  }

  /// Closes the TLS connection and cleans up resources.
  Future<void> close() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socket?.close();
    _socket = null;
    await _messageController?.close();
    _messageController = null;
  }
}
