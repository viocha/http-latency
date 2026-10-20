import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_latency/ip_lookup_provider.dart';
import 'package:http_latency/network_service.dart';

class _StalledClient implements HttpClient {
  Uri? requestedUrl;
  bool forceClosed = false;

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    requestedUrl = url;
    return Completer<HttpClientRequest>().future;
  }

  @override
  void close({bool force = false}) => forceClosed = force;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  for (final seconds in [1, 2, 3, 5]) {
    testWidgets('使用选定接口，连接未完成时在配置的 $seconds 秒总超时后关闭客户端', (tester) async {
      const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => ['wifi'],
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final client = _StalledClient();
      final pending = HttpOverrides.runZoned(
        () => NetworkService().load(
          provider: IpLookupProvider.ipSb,
          timeout: Duration(seconds: seconds),
        ),
        createHttpClient: (_) => client,
      );
      await tester.pump();
      expect(client.requestedUrl, Uri.parse('https://api.ip.sb/geoip'));
      await tester.pump(Duration(milliseconds: seconds * 1000 - 1));
      expect(client.forceClosed, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      final snapshot = await pending;
      expect(snapshot.error, '公网 IP 查询超时');
      expect(snapshot.ip, isNull);
      expect(snapshot.connectionType, 'Wi‑Fi');
      expect(client.forceClosed, isTrue);
    });
  }
}
