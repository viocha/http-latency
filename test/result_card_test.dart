import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_latency/app_ui.dart';
import 'package:http_latency/models.dart';

void main() {
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
