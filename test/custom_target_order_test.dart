import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_latency/app_controller.dart';
import 'package:http_latency/app_database.dart';
import 'package:http_latency/app_ui.dart';
import 'package:http_latency/models.dart';

class _MemoryDatabase extends AppDatabase {
  SavedConfiguration? saved;

  @override
  Future<void> saveConfiguration(SavedConfiguration configuration) async {
    saved = configuration;
  }
}

void main() {
  testWidgets('删除自定义 URL 必须确认，取消保留目标', (tester) async {
    final database = _MemoryDatabase();
    final controller = AppController(database: database);
    controller.targets = const [
      TestTarget(
        id: 'custom',
        name: '测试目标',
        url: 'https://example.com',
        isBuiltIn: false,
        selected: true,
      ),
    ];
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
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除自定义 URL？'), findsOneWidget);
    expect(controller.targets, hasLength(1));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(controller.targets, hasLength(1));
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(controller.targets, isEmpty);
    expect(database.saved!.targets, isEmpty);
    expect(find.text('还没有自定义 URL'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('拖动自定义 URL 后保存顺序，测速期间也可以拖动', (tester) async {
    final database = _MemoryDatabase();
    final controller = AppController(database: database);
    const custom = [
      TestTarget(
        id: 'a',
        name: '目标 A',
        url: 'https://a.example',
        isBuiltIn: false,
        selected: true,
      ),
      TestTarget(
        id: 'b',
        name: '目标 B',
        url: 'https://b.example',
        isBuiltIn: false,
        selected: false,
      ),
      TestTarget(
        id: 'c',
        name: '目标 C',
        url: 'https://c.example',
        isBuiltIn: false,
        selected: true,
      ),
    ];
    controller.targets = [...builtInTargets, ...custom];
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

    final handle = tester.getCenter(find.byIcon(Icons.drag_handle).first);
    final destination = tester.getBottomLeft(find.byKey(const ValueKey('c')));
    final gesture = await tester.startGesture(handle);
    await gesture.moveTo(Offset(handle.dx, destination.dy + 80));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.targets.where((t) => !t.isBuiltIn).map((t) => t.id), [
      'b',
      'c',
      'a',
    ]);
    expect(database.saved!.targets.map((t) => t.id), [
      ...builtInTargets.map((t) => t.id),
      'b',
      'c',
      'a',
    ]);
    expect(controller.targets.last.selected, isTrue);
    expect(
      tester.getTopLeft(find.text('目标 B')).dy,
      lessThan(tester.getTopLeft(find.text('目标 A')).dy),
    );

    controller.reorderCustomTargets(2, 0);
    await tester.pumpAndSettle();
    expect(controller.targets.where((t) => !t.isBuiltIn).map((t) => t.id), [
      'a',
      'b',
      'c',
    ]);

    controller.isRunning = true;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SettingsPage(controller))),
    );
    final runningHandle = tester.getCenter(
      find.byIcon(Icons.drag_handle).first,
    );
    final runningDestination = tester.getBottomLeft(
      find.byKey(const ValueKey('c')),
    );
    final runningGesture = await tester.startGesture(runningHandle);
    await runningGesture.moveTo(
      Offset(runningHandle.dx, runningDestination.dy + 80),
    );
    await tester.pumpAndSettle();
    await runningGesture.up();
    await tester.pumpAndSettle();
    expect(controller.targets.where((t) => !t.isBuiltIn).map((t) => t.id), [
      'b',
      'c',
      'a',
    ]);
    expect(database.saved!.targets.last.id, 'a');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '添加'))
          .onPressed,
      isNotNull,
    );
    for (final dropdown in tester.widgetList<DropdownButton<int>>(
      find.byType(DropdownButton<int>),
    )) {
      expect(dropdown.onChanged, isNotNull);
    }
    controller.dispose();
  });
}
