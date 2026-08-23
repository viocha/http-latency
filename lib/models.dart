import 'dart:convert';

const builtInTargets = <TestTarget>[
  TestTarget(
    id: 'google',
    name: 'Google',
    url: 'https://www.google.com/',
    isBuiltIn: true,
    selected: true,
  ),
  TestTarget(
    id: 'youtube',
    name: 'YouTube',
    url: 'https://www.youtube.com/',
    isBuiltIn: true,
    selected: true,
  ),
  TestTarget(
    id: 'github',
    name: 'GitHub',
    url: 'https://github.com/',
    isBuiltIn: true,
    selected: true,
  ),
  TestTarget(
    id: 'chatgpt',
    name: 'ChatGPT',
    url: 'https://chatgpt.com/',
    isBuiltIn: true,
    selected: true,
  ),
  TestTarget(
    id: 'x',
    name: 'X',
    url: 'https://x.com/',
    isBuiltIn: true,
    selected: false,
  ),
  TestTarget(
    id: 'facebook',
    name: 'Facebook',
    url: 'https://www.facebook.com/',
    isBuiltIn: true,
    selected: false,
  ),
  TestTarget(
    id: 'instagram',
    name: 'Instagram',
    url: 'https://www.instagram.com/',
    isBuiltIn: true,
    selected: false,
  ),
  TestTarget(
    id: 'wikipedia',
    name: 'Wikipedia',
    url: 'https://www.wikipedia.org/',
    isBuiltIn: true,
    selected: false,
  ),
];

class TestTarget {
  const TestTarget({
    required this.id,
    required this.name,
    required this.url,
    required this.isBuiltIn,
    required this.selected,
  });

  final String id;
  final String name;
  final String url;
  final bool isBuiltIn;
  final bool selected;

  TestTarget copyWith({String? name, String? url, bool? selected}) =>
      TestTarget(
        id: id,
        name: name ?? this.name,
        url: url ?? this.url,
        isBuiltIn: isBuiltIn,
        selected: selected ?? this.selected,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'isBuiltIn': isBuiltIn,
    'selected': selected,
  };

  factory TestTarget.fromJson(Map<String, Object?> json) => TestTarget(
    id: json['id']! as String,
    name: json['name']! as String,
    url: json['url']! as String,
    isBuiltIn: json['isBuiltIn']! as bool,
    selected: json['selected']! as bool,
  );
}

class RequestSample {
  const RequestSample({
    required this.index,
    required this.durationMs,
    required this.statusCode,
    required this.bytes,
    required this.error,
  });

  final int index;
  final int? durationMs;
  final int? statusCode;
  final int bytes;
  final String? error;

  bool get succeeded => error == null && durationMs != null;

  Map<String, Object?> toJson() => {
    'index': index,
    'durationMs': durationMs,
    'statusCode': statusCode,
    'bytes': bytes,
    'error': error,
  };

  factory RequestSample.fromJson(Map<String, Object?> json) => RequestSample(
    index: json['index']! as int,
    durationMs: json['durationMs'] as int?,
    statusCode: json['statusCode'] as int?,
    bytes: json['bytes']! as int,
    error: json['error'] as String?,
  );
}

class TargetResult {
  const TargetResult({required this.target, required this.samples});

  final TestTarget target;
  final List<RequestSample> samples;

  List<int> get successfulDurations => samples
      .where((sample) => sample.succeeded)
      .map((sample) => sample.durationMs!)
      .toList(growable: false);

  int? get minimumMs {
    final values = successfulDurations;
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a < b ? a : b);
  }

  int? get maximumMs {
    final values = successfulDurations;
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b);
  }

  double? get averageMs {
    final values = successfulDurations;
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Map<String, Object?> toJson() => {
    'target': target.toJson(),
    'samples': samples.map((sample) => sample.toJson()).toList(),
  };

  factory TargetResult.fromJson(Map<String, Object?> json) => TargetResult(
    target: TestTarget.fromJson(
      Map<String, Object?>.from(json['target']! as Map),
    ),
    samples: (json['samples']! as List)
        .map(
          (item) =>
              RequestSample.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList(),
  );
}

class NetworkSnapshot {
  const NetworkSnapshot({
    required this.connectionType,
    this.ip,
    this.ipVersion,
    this.country,
    this.city,
    this.isp,
    this.updatedAt,
    this.error,
  });

  final String connectionType;
  final String? ip;
  final String? ipVersion;
  final String? country;
  final String? city;
  final String? isp;
  final DateTime? updatedAt;
  final String? error;

  Map<String, Object?> toJson() => {
    'connectionType': connectionType,
    'ip': ip,
    'ipVersion': ipVersion,
    'country': country,
    'city': city,
    'isp': isp,
    'updatedAt': updatedAt?.toIso8601String(),
    'error': error,
  };

  factory NetworkSnapshot.fromJson(Map<String, Object?> json) =>
      NetworkSnapshot(
        connectionType: json['connectionType']! as String,
        ip: json['ip'] as String?,
        ipVersion: json['ipVersion'] as String?,
        country: json['country'] as String?,
        city: json['city'] as String?,
        isp: json['isp'] as String?,
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt']! as String),
        error: json['error'] as String?,
      );
}

class TestRun {
  const TestRun({
    required this.id,
    required this.startedAt,
    required this.completedAt,
    required this.repetitions,
    required this.warmUp,
    required this.network,
    required this.results,
  });

  final String id;
  final DateTime startedAt;
  final DateTime completedAt;
  final int repetitions;
  final bool warmUp;
  final NetworkSnapshot network;
  final List<TargetResult> results;

  String encode() => jsonEncode({
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
    'repetitions': repetitions,
    'warmUp': warmUp,
    'network': network.toJson(),
    'results': results.map((result) => result.toJson()).toList(),
  });

  factory TestRun.decode(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return TestRun(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: DateTime.parse(json['completedAt'] as String),
      repetitions: json['repetitions'] as int,
      warmUp: json['warmUp'] as bool,
      network: NetworkSnapshot.fromJson(
        Map<String, Object?>.from(json['network'] as Map),
      ),
      results: (json['results'] as List)
          .map(
            (item) =>
                TargetResult.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList(),
    );
  }
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String formatDuration(int? milliseconds) =>
    milliseconds == null ? '—' : '$milliseconds ms';

String formatCountryAndCity(String? country, String? city) {
  final parts = <String>[];
  for (final value in [country, city]) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      continue;
    }
    if (parts.any((part) => part.toLowerCase() == normalized.toLowerCase())) {
      continue;
    }
    parts.add(normalized);
  }
  return parts.join(' · ');
}
