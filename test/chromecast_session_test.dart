import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_cast/dart_cast.dart';
import 'package:flutter_test/flutter_test.dart';

const _receiverNamespace = 'urn:x-cast:com.google.cast.receiver';
const _mediaNamespace = 'urn:x-cast:com.google.cast.media';

class _FakeChannel {
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final sent = <Map<String, dynamic>>[];

  Stream<Map<String, dynamic>> get messageStream => _messages.stream;

  Future<void> connect(String host, {int port = 8009}) async {}

  void sendMessage({
    required String namespace,
    required String sourceId,
    required String destinationId,
    required String payload,
  }) {
    sent.add({
      'namespace': namespace,
      'sourceId': sourceId,
      'destinationId': destinationId,
      'payload': jsonDecode(payload),
    });
  }

  void emit(String namespace, Map<String, dynamic> payload) {
    _messages.add({'namespace': namespace, 'payload': payload});
  }

  Future<void> close() => _messages.close();
}

CastDevice _device() => CastDevice(
      id: 'receiver-1',
      name: 'Living Room',
      protocol: CastProtocol.chromecast,
      address: InternetAddress.loopbackIPv4,
      port: 8009,
    );

void main() {
  test('connects from receiver status and stops media before disconnecting',
      () async {
    final channel = _FakeChannel();
    final session = ChromecastSession.withMocks(
      device: _device(),
      channel: channel,
    );
    addTearDown(session.dispose);

    final connecting = session.connect();
    await Future<void>.delayed(Duration.zero);
    channel.emit(_receiverNamespace, {
      'type': 'RECEIVER_STATUS',
      'status': {
        'applications': [
          {
            'transportId': 'web-transport',
            'sessionId': 'session-1',
            'appId': 'CC1AD845',
          },
        ],
        'volume': {'level': 0.75, 'muted': false},
      },
    });
    await connecting;
    expect(session.state, SessionState.connected);
    session.stateMachine.transitionTo(SessionState.loading);

    channel.emit(_mediaNamespace, {
      'type': 'MEDIA_STATUS',
      'status': [
        {
          'mediaSessionId': 42,
          'playerState': 'PLAYING',
          'currentTime': 12.5,
          'media': {'duration': 180.0},
        },
      ],
    });
    await Future<void>.delayed(Duration.zero);
    expect(session.state, SessionState.playing);
    expect(session.position, const Duration(milliseconds: 12500));

    await session.disconnect();

    final stopMessages = channel.sent
        .where((message) =>
            message['namespace'] == _mediaNamespace &&
            (message['payload'] as Map)['type'] == 'STOP')
        .toList();
    expect(stopMessages, hasLength(1));
    expect((stopMessages.single['payload'] as Map)['mediaSessionId'], 42);
    expect(session.state, SessionState.disconnected);
  });

  test('allows receiver playback to recover directly from idle', () {
    final machine = SessionStateMachine();
    machine.transitionTo(SessionState.connecting);
    machine.transitionTo(SessionState.connected);
    machine.transitionTo(SessionState.loading);
    machine.transitionTo(SessionState.idle);

    expect(machine.canTransitionTo(SessionState.playing), isTrue);
    machine.transitionTo(SessionState.playing);
    expect(machine.state, SessionState.playing);
    machine.dispose();
  });
}
