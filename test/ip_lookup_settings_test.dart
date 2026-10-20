import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_latency/app_controller.dart';
import 'package:http_latency/app_database.dart';
import 'package:http_latency/app_ui.dart';
import 'package:http_latency/ip_lookup_provider.dart';
import 'package:http_latency/models.dart';
import 'package:http_latency/network_service.dart';

class _MemoryDatabase extends AppDatabase {
  SavedConfiguration saved = SavedConfiguration(
    targets: builtInTargets,
    repetitions: 3,
    warmUpCount: 1,
    timeoutSeconds: 10,
  );

  @override
  Future<SavedConfiguration> loadConfiguration() async => saved;

  @override
  Future<List<TestRun>> loadHistory() async => [];

  @override
  Future<void> saveConfiguration(SavedConfiguration configuration) async {
    saved = configuration;
  }
}

class _FakeNetworkService extends NetworkService {
  final providers = <IpLookupProvider>[];
  final timeouts = <Duration>[];
  Completer<NetworkSnapshot>? pending;

  @override
  Future<NetworkSnapshot> load({
    IpLookupProvider provider = IpLookupProvider.ipwhoIs,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    providers.add(provider);
    timeouts.add(timeout);
    return pending?.future ??
        const NetworkSnapshot(connectionType: 'Wi‑Fi', ip: '198.51.100.2');
  }
}

void main() {
  test('接口与独立超时自动保存，查询和初始化使用已保存的设置', () async {
    final database = _MemoryDatabase();
    final service = _FakeNetworkService();
    final controller = AppController(
      database: database,
      networkService: service,
    );
    controller.setIpLookupProvider(IpLookupProvider.ipSb);
    controller.setIpLookupTimeoutSeconds(2);
    expect(database.saved.ipLookupProvider, IpLookupProvider.ipSb);
    expect(database.saved.ipLookupTimeoutSeconds, 2);
    expect(controller.timeoutSeconds, 10);
    expect(service.providers, isEmpty);
    await controller.refreshNetwork();
    expect(service.providers, [IpLookupProvider.ipSb]);
    expect(service.timeouts, [const Duration(seconds: 2)]);
    expect(controller.network.ip, '198.51.100.2');
    controller.dispose();

    final restoredService = _FakeNetworkService();
    final restored = AppController(
      database: database,
      networkService: restoredService,
    );
    await restored.initialize();
    await restored.refreshNetwork();
    expect(restored.ipLookupProvider, IpLookupProvider.ipSb);
    expect(restored.ipLookupTimeoutSeconds, 2);
    expect(restored.timeoutSeconds, 10);
    expect(restoredService.providers.first, IpLookupProvider.ipSb);
    expect(restoredService.timeouts.first, const Duration(seconds: 2));
    restored.dispose();
  });

  test('查询和测速期间可以保存下一次查询使用的接口', () async {
    final database = _MemoryDatabase();
    final service = _FakeNetworkService()
      ..pending = Completer<NetworkSnapshot>();
    final controller = AppController(
      database: database,
      networkService: service,
    );
    controller.setIpLookupProvider(IpLookupProvider.ipwhoIs);
    expect(service.providers, isEmpty);
    final pending = controller.refreshNetwork();
    controller.setIpLookupProvider(IpLookupProvider.freeIpApi);
    expect(controller.ipLookupProvider, IpLookupProvider.freeIpApi);
    expect(database.saved.ipLookupProvider, IpLookupProvider.freeIpApi);
    expect(service.providers, [IpLookupProvider.ipwhoIs]);
    service.pending!.complete(const NetworkSnapshot(connectionType: 'Wi‑Fi'));
    await pending;
    controller.isRunning = true;
    controller.setIpLookupProvider(IpLookupProvider.ipSb);
    controller.setIpLookupTimeoutSeconds(1);
    expect(controller.ipLookupProvider, IpLookupProvider.ipSb);
    expect(database.saved.ipLookupProvider, IpLookupProvider.ipSb);
    expect(database.saved.ipLookupTimeoutSeconds, 1);
    expect(service.providers, [IpLookupProvider.ipwhoIs]);
    controller.isRunning = false;
    service.pending = null;
    await controller.refreshNetwork();
    expect(service.providers, [
      IpLookupProvider.ipwhoIs,
      IpLookupProvider.ipSb,
    ]);
    expect(service.timeouts, [
      const Duration(seconds: 3),
      const Duration(seconds: 1),
    ]);
    controller.dispose();
  });

  testWidgets('窄屏设置中查询和测速期间也可以切换接口', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = _MemoryDatabase();
    final service = _FakeNetworkService();
    final controller = AppController(
      database: database,
      networkService: service,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controller,
            builder: (_, _) => SettingsPage(controller),
          ),
        ),
      ),
    );
    final dropdown = find.byType(DropdownButton<IpLookupProvider>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    expect(find.text('IP.SB'), findsOneWidget);
    await tester.tap(find.text('FreeIPAPI').last);
    await tester.pumpAndSettle();
    expect(controller.ipLookupProvider, IpLookupProvider.freeIpApi);
    expect(database.saved.ipLookupProvider, IpLookupProvider.freeIpApi);
    expect(service.providers, isEmpty);
    expect(tester.takeException(), isNull);

    controller.isRunning = true;
    controller.isLoadingNetwork = true;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SettingsPage(controller))),
    );
    expect(
      tester.widget<DropdownButton<IpLookupProvider>>(dropdown).onChanged,
      isNotNull,
    );
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('IP.SB').last);
    await tester.pumpAndSettle();
    expect(controller.ipLookupProvider, IpLookupProvider.ipSb);
    expect(database.saved.ipLookupProvider, IpLookupProvider.ipSb);
    expect(service.providers, isEmpty);
    final timeoutDropdown = find.byKey(const ValueKey('ip_lookup_timeout'));
    await tester.ensureVisible(timeoutDropdown);
    await tester.tap(timeoutDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 秒').last);
    await tester.pumpAndSettle();
    expect(controller.ipLookupTimeoutSeconds, 1);
    expect(database.saved.ipLookupTimeoutSeconds, 1);
    expect(controller.timeoutSeconds, 10);
    expect(service.providers, isEmpty);
    controller.dispose();
  });
}
