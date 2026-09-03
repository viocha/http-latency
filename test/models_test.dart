import 'package:flutter_test/flutter_test.dart';
import 'package:http_latency/app_controller.dart';
import 'package:http_latency/models.dart';

void main() {
  group('TargetResult statistics', () {
    test('uses only completed samples', () {
      final result = TargetResult(
        target: builtInTargets.first,
        samples: const [
          RequestSample(
            index: 1,
            durationMs: 100,
            statusCode: 200,
            bytes: 10,
            error: null,
          ),
          RequestSample(
            index: 2,
            durationMs: null,
            statusCode: null,
            bytes: 0,
            error: '失败',
          ),
          RequestSample(
            index: 3,
            durationMs: 300,
            statusCode: 200,
            bytes: 10,
            error: null,
          ),
        ],
      );

      expect(result.minimumMs, 100);
      expect(result.maximumMs, 300);
      expect(result.averageMs, 200);
    });

    test('returns no statistics when every request failed', () {
      final result = TargetResult(
        target: builtInTargets.first,
        samples: const [
          RequestSample(
            index: 1,
            durationMs: null,
            statusCode: null,
            bytes: 0,
            error: '超时',
          ),
        ],
      );
      expect(result.minimumMs, isNull);
      expect(result.maximumMs, isNull);
      expect(result.averageMs, isNull);
    });
  });

  test('default selection contains ChatGPT and Gemini', () {
    expect(
      builtInTargets
          .where((target) => target.selected)
          .map((target) => target.id),
      ['chatgpt', 'gemini'],
    );
  });

  group('country and city display', () {
    test('removes a repeated city', () {
      expect(formatCountryAndCity('Hong Kong', 'Hong Kong'), 'Hong Kong');
    });

    test('keeps different country and city names', () {
      expect(
        formatCountryAndCity('United States', 'Los Angeles'),
        'United States · Los Angeles',
      );
    });
  });

  group('country and isp display', () {
    test('removes repeated isp if identical to country', () {
      expect(formatCountryAndIsp('Hong Kong', 'Hong Kong'), 'Hong Kong');
    });

    test('keeps country and isp names', () {
      expect(
        formatCountryAndIsp('China', 'China Telecom'),
        'China · China Telecom',
      );
    });

    test('handles null and empty values', () {
      expect(formatCountryAndIsp('China', null), 'China');
      expect(formatCountryAndIsp(null, 'China Telecom'), 'China Telecom');
      expect(formatCountryAndIsp(null, null), '');
      expect(formatCountryAndIsp('  ', ''), '');
    });
  });

  group('URL validation', () {
    test('accepts complete HTTP URLs', () {
      expect(
        AppController.normalizeUrl(' https://example.com/test '),
        'https://example.com/test',
      );
    });

    test('rejects unsupported or incomplete URLs', () {
      expect(
        () => AppController.normalizeUrl('example.com'),
        throwsFormatException,
      );
      expect(
        () => AppController.normalizeUrl('ftp://example.com'),
        throwsFormatException,
      );
    });
  });

  test('history JSON preserves nested samples', () {
    final now = DateTime(2026, 8, 23, 12);
    final run = TestRun(
      id: '1',
      startedAt: now,
      completedAt: now.add(const Duration(seconds: 1)),
      repetitions: 1,
      warmUp: true,
      network: NetworkSnapshot(
        connectionType: 'Wi‑Fi',
        ip: '203.0.113.1',
        ipVersion: 'IPv4',
        country: 'United States',
        city: 'Los Angeles',
        isp: 'Example ISP',
        updatedAt: now,
      ),
      results: [
        TargetResult(
          target: builtInTargets.first,
          samples: const [
            RequestSample(
              index: 1,
              durationMs: 120,
              statusCode: 204,
              bytes: 0,
              error: null,
            ),
          ],
        ),
      ],
    );
    final decoded = TestRun.decode(run.encode());
    expect(decoded.network.ip, '203.0.113.1');
    expect(decoded.network.ipVersion, 'IPv4');
    expect(decoded.network.country, 'United States');
    expect(decoded.network.city, 'Los Angeles');
    expect(decoded.network.isp, 'Example ISP');
    expect(decoded.network.updatedAt, now);
    expect(decoded.results.single.samples.single.durationMs, 120);
  });
}
