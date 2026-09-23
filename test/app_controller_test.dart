import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http_latency/app_controller.dart';
import 'package:http_latency/app_database.dart';
import 'package:http_latency/models.dart';
import 'package:http_latency/network_service.dart';

class _MemoryDatabase extends AppDatabase {
  @override
  Future<void> saveConfiguration(SavedConfiguration configuration) async {}

  @override
  Future<void> saveRun(TestRun run) async {}
}

class _FakeNetworkService extends NetworkService {
  _FakeNetworkService(this.snapshot);

  final NetworkSnapshot snapshot;
  int loads = 0;

  @override
  Future<NetworkSnapshot> load() async {
    loads++;
    return snapshot;
  }
}

void main() {
  late HttpServer server;
  late int requests;

  setUp(() async {
    requests = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      request.response.write('ok');
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

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
