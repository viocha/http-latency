import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http_latency/app_controller.dart';
import 'package:http_latency/app_database.dart';
import 'package:http_latency/ip_lookup_provider.dart';
import 'package:http_latency/models.dart';
import 'package:http_latency/network_service.dart';

class _MemoryDatabase extends AppDatabase {
  SavedConfiguration? saved;

  @override
  Future<void> saveConfiguration(SavedConfiguration configuration) async {
    saved = configuration;
  }

  @override
  Future<void> saveRun(TestRun run) async {}
}

class _FakeNetworkService extends NetworkService {
  _FakeNetworkService(this.snapshot);

  final NetworkSnapshot snapshot;
  int loads = 0;

  @override
  Future<NetworkSnapshot> load({
    IpLookupProvider provider = IpLookupProvider.ipwhoIs,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    loads++;
    return snapshot;
  }
}

void main() {
  late HttpServer server;
  late int requests;
  Future<void> Function(HttpRequest)? beforeRespond;

  setUp(() async {
    requests = 0;
    beforeRespond = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      await beforeRespond?.call(request);
      request.response.write('ok');
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  test('请求进行时可修改设置，本次请求、进度和历史使用发起时的参数', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final paths = <String>[];
    beforeRespond = (request) async {
      paths.add(request.uri.path);
      if (!started.isCompleted) started.complete();
      await release.future;
    };
    final database = _MemoryDatabase();
    final controller = AppController(
      database: database,
      networkService: _FakeNetworkService(
        const NetworkSnapshot(connectionType: 'Wi‑Fi', ip: '198.51.100.2'),
      ),
    );
    controller.selectAll(false);
    controller.addCustomTarget('本次目标', 'http://127.0.0.1:${server.port}/');
    final target = controller.targets.last;
    controller.setTargetSelected(target.id, true);
    controller.setRepetitions(2);
    controller.setWarmUpCount(1);
    final pending = controller.runTest();
    await started.future;
    try {
      controller.setRepetitions(5);
      controller.setWarmUpCount(0);
      controller.setTimeoutSeconds(1);
      controller.selectAll(false);
      controller.updateCustomTarget(
        target.id,
        '下次目标',
        'http://127.0.0.1:${server.port}/next',
      );
      controller.setTargetSelected(target.id, true);
      expect(controller.repetitions, 5);
      expect(controller.warmUpCount, 0);
      expect(controller.timeoutSeconds, 1);
      expect(controller.totalOperations, 3);
      expect(controller.resultRepetitions, 2);
      expect(database.saved!.repetitions, 5);
      expect(database.saved!.timeoutSeconds, 1);
    } finally {
      release.complete();
    }
    await pending;
    expect(paths, ['/', '/', '/']);
    expect(controller.completedOperations, 3);
    expect(controller.progress, 1);
    final run = controller.history.single;
    expect(run.repetitions, 2);
    expect(run.warmUpCount, 1);
    expect(run.results.single.target.name, '本次目标');
    expect(run.results.single.target.url, target.url);
    expect(run.results.single.samples, hasLength(2));
    expect(controller.targets.last.name, '下次目标');
    controller.dispose();
  });

  Future<AppController> prepare(_FakeNetworkService service) async {
    final controller = AppController(
      database: _MemoryDatabase(),
      networkService: service,
    );
    controller.selectAll(false);
    controller.addCustomTarget('本地', 'http://127.0.0.1:${server.port}/');
    controller.setTargetSelected(controller.targets.last.id, true);
    return controller;
  }

  test('按设置预热并把测试前刷新的 IP 固定到历史', () async {
    final service = _FakeNetworkService(
      const NetworkSnapshot(connectionType: 'Wi‑Fi', ip: '198.51.100.2'),
    );
    final controller = await prepare(service);
    controller.network = const NetworkSnapshot(
      connectionType: 'Wi‑Fi',
      ip: '198.51.100.1',
    );
    controller.setRepetitions(2);
    controller.setWarmUpCount(3);

    await controller.runTest();

    expect(service.loads, 1);
    expect(requests, 5);
    expect(controller.completedOperations, 5);
    expect(controller.history.single.warmUpCount, 3);
    expect(controller.history.single.results.single.samples.length, 2);
    expect(controller.history.single.network.ip, '198.51.100.2');
    controller.dispose();
  });

  test('IP 查询失败时历史不沿用旧地址', () async {
    final service = _FakeNetworkService(
      const NetworkSnapshot(connectionType: 'Wi‑Fi', error: '查询失败'),
    );
    final controller = await prepare(service);
    controller.network = const NetworkSnapshot(
      connectionType: 'Wi‑Fi',
      ip: '198.51.100.1',
    );
    controller.setWarmUpCount(0);
    controller.setRepetitions(1);

    await controller.runTest();

    expect(requests, 1);
    expect(controller.history.single.network.ip, isNull);
    expect(controller.history.single.network.error, '查询失败');
    controller.dispose();
  });
}
