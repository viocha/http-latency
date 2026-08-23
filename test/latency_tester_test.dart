import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http_latency/latency_tester.dart';

void main() {
  late HttpServer server;

  setUp(
    () async => server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
  );
  tearDown(() => server.close(force: true));

  test('uses a 10 MB response limit by default', () {
    final tester = LatencyTester(timeout: const Duration(seconds: 1));
    expect(tester.maxResponseBytes, 10 * 1024 * 1024);
    tester.close();
  });

  test('waits for the complete streamed response', () async {
    server.listen((request) async {
      request.response.write('first');
      await request.response.flush();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      request.response.write('second');
      await request.response.close();
    });
    final tester = LatencyTester(timeout: const Duration(seconds: 2));
    final sample = await tester.measure('http://127.0.0.1:${server.port}/', 1);
    tester.close();

    expect(sample.succeeded, isTrue);
    expect(sample.bytes, 11);
    expect(sample.durationMs, greaterThanOrEqualTo(100));
  });

  test('marks a response over the configured limit as failed', () async {
    server.listen((request) async {
      request.response.write('more than four bytes');
      await request.response.close();
    });
    final tester = LatencyTester(
      timeout: const Duration(seconds: 2),
      maxResponseBytes: 4,
    );
    final sample = await tester.measure('http://127.0.0.1:${server.port}/', 1);
    tester.close();

    expect(sample.succeeded, isFalse);
    expect(sample.error, contains('4 B'));
  });
}
