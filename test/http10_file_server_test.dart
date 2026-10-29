import 'dart:io';

import 'package:dart_cast/src/core/http10_file_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late File file;
  late HttpClient client;
  Uri url(String path) => Uri.parse(
        'http://${InternetAddress.loopbackIPv4.address}:${server.port}$path',
      );

  setUp(() async {
    final directory = await Directory.systemTemp.createTemp('http10-test-');
    addTearDown(() => directory.delete(recursive: true));
    file = File('${directory.path}/audio.bin');
    await file.writeAsBytes(<int>[0, 1, 2, 3, 4, 5]);

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final socket = await request.response.detachSocket(writeHeaders: false);
      try {
        await Http10FileServer.serve(socket, file, request);
      } finally {
        await socket.close();
      }
    });
    client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });
  });

  test('serves a complete file with HTTP/1.0 headers', () async {
    final request = await client.getUrl(url('/audio.bin'));
    final response = await request.close();
    final body = await response.fold<List<int>>(<int>[], (all, chunk) {
      return all..addAll(chunk);
    });

    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.value('content-type'), 'application/octet-stream');
    expect(response.headers.value('accept-ranges'), 'bytes');
    expect(response.contentLength, 6);
    expect(response.headers.value('x-http-version'), isNull);
    expect(body, <int>[0, 1, 2, 3, 4, 5]);
  });

  test('serves requested byte ranges and HEAD without a body', () async {
    final rangeRequest = await client.getUrl(url('/audio.bin'));
    rangeRequest.headers.set('Range', 'bytes=2-4');
    final rangeResponse = await rangeRequest.close();
    final rangeBody =
        await rangeResponse.fold<List<int>>(<int>[], (all, chunk) {
      return all..addAll(chunk);
    });

    expect(rangeResponse.statusCode, HttpStatus.partialContent);
    expect(rangeResponse.headers.value('content-range'), 'bytes 2-4/6');
    expect(rangeResponse.contentLength, 3);
    expect(rangeBody, <int>[2, 3, 4]);

    final headRequest = await client.headUrl(url('/audio.bin'));
    final headResponse = await headRequest.close();
    expect(headResponse.statusCode, HttpStatus.ok);
    expect(headResponse.contentLength, 6);
    expect(
        await headResponse.fold<List<int>>(<int>[], (all, chunk) {
          return all..addAll(chunk);
        }),
        isEmpty);
  });

  test('rejects ranges outside the file', () async {
    final request = await client.getUrl(url('/audio.bin'));
    request.headers.set('Range', 'bytes=99-');
    final response = await request.close();

    expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
    expect(response.headers.value('content-range'), 'bytes */6');
    expect(await response.drain<List<int>>(<int>[]), isEmpty);
  });
}
