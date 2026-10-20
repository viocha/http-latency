import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_latency/app_controller.dart';
import 'package:http_latency/app_database.dart';
import 'package:http_latency/app_ui.dart';
import 'package:http_latency/models.dart';

class _MemoryDatabase extends AppDatabase {
  @override
  Future<void> saveConfiguration(SavedConfiguration configuration) async {}
}

void main() {
  testWidgets('测速中可修改次数、预热和目标，结果按本次次数显示', (tester) async {
    final controller = AppController(database: _MemoryDatabase())
      ..isRunning = true
      ..resultRepetitions = 3
      ..currentResults = [
        TargetResult(target: builtInTargets.first, samples: const []),
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controller,
            builder: (_, _) => TestPage(controller),
          ),
        ),
      ),
    );
    final dropdowns = find.byType(DropdownButton<int>);
    await tester.tap(dropdowns.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 次').last);
    await tester.pumpAndSettle();
    expect(controller.repetitions, 5);
    expect(find.text('测试中 0/3'), findsOneWidget);
    await tester.tap(dropdowns.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('0 次').last);
    await tester.pumpAndSettle();
    expect(controller.warmUpCount, 0);
    await tester.tap(find.text('测试目标'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'ChatGPT'));
    await tester.pumpAndSettle();
    expect(controller.targets.first.selected, isFalse);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });
  testWidgets('an empty in-progress result is shown as testing', (
    tester,
  ) async {
    final result = TargetResult(
      target: builtInTargets.first,
      samples: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultCard(result, testing: true, expectedSamples: 3),
        ),
      ),
    );

    expect(find.text('测试中 0/3'), findsOneWidget);
    expect(find.text('无有效结果'), findsNothing);
  });

  testWidgets('a completed result with no successes shows no valid result', (
    tester,
  ) async {
    final result = TargetResult(
      target: builtInTargets.first,
      samples: const [
        RequestSample(
          index: 1,
          durationMs: null,
          statusCode: null,
          bytes: 0,
          error: '请求超时',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ResultCard(result))),
    );

    expect(find.text('无有效结果'), findsOneWidget);
    expect(find.textContaining('测试中'), findsNothing);
  });
}
