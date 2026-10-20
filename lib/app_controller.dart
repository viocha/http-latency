import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_database.dart';
import 'ip_lookup_provider.dart';
import 'latency_tester.dart';
import 'models.dart';
import 'network_service.dart';

class AppController extends ChangeNotifier {
  AppController({AppDatabase? database, NetworkService? networkService})
    : _database = database ?? AppDatabase(),
      _networkService = networkService ?? NetworkService();

  final AppDatabase _database;
  final NetworkService _networkService;

  bool initialized = false;
  bool isRunning = false;
  bool isCancelling = false;
  bool isLoadingNetwork = false;
  int repetitions = 3;
  int warmUpCount = 1;
  int timeoutSeconds = 10;
  int resultRepetitions = 3;
  IpLookupProvider ipLookupProvider = IpLookupProvider.ipwhoIs;
  int ipLookupTimeoutSeconds = 3;
  int completedOperations = 0;
  int totalOperations = 0;
  String currentStatus = '';
  String? message;
  NetworkSnapshot network = const NetworkSnapshot(connectionType: '检测中');
  List<TestTarget> targets = List.of(builtInTargets);
  List<TargetResult> currentResults = [];
  List<TestRun> history = [];
  LatencyTester? _tester;
  Future<NetworkSnapshot>? _networkRefresh;

  double get progress =>
      totalOperations == 0 ? 0 : completedOperations / totalOperations;
  int get selectedCount => targets.where((target) => target.selected).length;

  Future<void> initialize() async {
    try {
      final configuration = await _database.loadConfiguration();
      targets = configuration.targets;
      repetitions = configuration.repetitions;
      warmUpCount = configuration.warmUpCount;
      timeoutSeconds = configuration.timeoutSeconds;
      ipLookupProvider = configuration.ipLookupProvider;
      ipLookupTimeoutSeconds = configuration.ipLookupTimeoutSeconds;
      history = await _database.loadHistory();
    } catch (error) {
      message = '读取本地数据失败：$error';
    }
    initialized = true;
    notifyListeners();
    unawaited(refreshNetwork());
  }

  Future<NetworkSnapshot> refreshNetwork() {
    if (_networkRefresh case final pending?) return pending;
    final pending = _loadNetwork();
    _networkRefresh = pending;
    return pending;
  }

  Future<NetworkSnapshot> _loadNetwork() async {
    final provider = ipLookupProvider;
    final timeout = Duration(seconds: ipLookupTimeoutSeconds);
    isLoadingNetwork = true;
    notifyListeners();
    try {
      network = await _networkService.load(
        provider: provider,
        timeout: timeout,
      );
      return network;
    } finally {
      isLoadingNetwork = false;
      _networkRefresh = null;
      notifyListeners();
    }
  }

  void setTargetSelected(String id, bool selected) {
    targets = targets
        .map(
          (target) =>
              target.id == id ? target.copyWith(selected: selected) : target,
        )
        .toList();
    _persistConfiguration();
    notifyListeners();
  }

  void selectAll(bool selected) {
    targets = targets
        .map((target) => target.copyWith(selected: selected))
        .toList();
    _persistConfiguration();
    notifyListeners();
  }

  void setRepetitions(int value) {
    if (value < 1 || value > 5) return;
    repetitions = value;
    _persistConfiguration();
    notifyListeners();
  }

  void setWarmUpCount(int value) {
    if (value < 0 || value > 5) return;
    warmUpCount = value;
    _persistConfiguration();
    notifyListeners();
  }

  void setTimeoutSeconds(int value) {
    if (!supportedTimeoutSeconds.contains(value)) return;
    timeoutSeconds = value;
    _persistConfiguration();
    notifyListeners();
  }

  void setIpLookupProvider(IpLookupProvider value) {
    if (value == ipLookupProvider) return;
    ipLookupProvider = value;
    _persistConfiguration();
    notifyListeners();
  }

  void setIpLookupTimeoutSeconds(int value) {
    if (!supportedTimeoutSeconds.contains(value) ||
        value == ipLookupTimeoutSeconds) {
      return;
    }
    ipLookupTimeoutSeconds = value;
    _persistConfiguration();
    notifyListeners();
  }

  void addCustomTarget(String name, String url) {
    final normalized = normalizeUrl(url);
    targets = [
      ...targets,
      TestTarget(
        id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        url: normalized,
        isBuiltIn: false,
        selected: false,
      ),
    ];
    _persistConfiguration();
    notifyListeners();
  }

  void updateCustomTarget(String id, String name, String url) {
    final normalized = normalizeUrl(url);
    targets = targets
        .map(
          (target) => target.id == id && !target.isBuiltIn
              ? target.copyWith(name: name.trim(), url: normalized)
              : target,
        )
        .toList();
    _persistConfiguration();
    notifyListeners();
  }

  void deleteCustomTarget(String id) {
    targets = targets
        .where((target) => target.isBuiltIn || target.id != id)
        .toList();
    _persistConfiguration();
    notifyListeners();
  }

  void reorderCustomTargets(int oldIndex, int newIndex) {
    final custom = targets.where((target) => !target.isBuiltIn).toList();
    if (oldIndex == newIndex) return;
    final target = custom.removeAt(oldIndex);
    custom.insert(newIndex, target);
    targets = [...targets.where((target) => target.isBuiltIn), ...custom];
    _persistConfiguration();
    notifyListeners();
  }

  void restoreDefaults() {
    final custom = targets
        .where((target) => !target.isBuiltIn)
        .map((target) => target.copyWith(selected: false));
    targets = [...builtInTargets, ...custom];
    repetitions = 3;
    warmUpCount = 1;
    timeoutSeconds = 10;
    _persistConfiguration();
    notifyListeners();
  }

  Future<void> runTest() async {
    if (isRunning) return;
    final selected = targets
        .where((target) => target.selected)
        .toList(growable: false);
    if (selected.isEmpty) {
      message = '请至少选择一个测试目标';
      notifyListeners();
      return;
    }

    final runRepetitions = repetitions;
    final runWarmUpCount = warmUpCount;
    final runTimeout = Duration(seconds: timeoutSeconds);

    message = null;
    isRunning = true;
    isCancelling = false;
    completedOperations = 0;
    totalOperations = selected.length * (runRepetitions + runWarmUpCount);
    resultRepetitions = runRepetitions;
    currentResults = [];
    currentStatus = '正在刷新 IP 信息';
    final tester = LatencyTester(timeout: runTimeout);
    _tester = tester;
    var cancelled = false;
    var hasValidResults = false;
    late NetworkSnapshot runNetwork;
    late DateTime startedAt;
    notifyListeners();

    try {
      runNetwork = await refreshNetwork();
      if (isCancelling) throw const TestCancelledException();
      startedAt = DateTime.now();
      for (final target in selected) {
        for (var index = 1; index <= runWarmUpCount; index++) {
          currentStatus = '${target.name} · 预热 $index/$runWarmUpCount';
          notifyListeners();
          await tester.measure(target.url, 0);
          completedOperations++;
          notifyListeners();
        }

        final samples = <RequestSample>[];
        currentResults = [
          ...currentResults,
          TargetResult(target: target, samples: samples),
        ];
        for (var index = 1; index <= runRepetitions; index++) {
          currentStatus = '${target.name} · 第 $index/$runRepetitions 次';
          notifyListeners();
          final sample = await tester.measure(target.url, index);
          samples.add(sample);
          currentResults = [
            for (final result in currentResults)
              if (result.target.id == target.id)
                TargetResult(target: target, samples: List.of(samples))
              else
                result,
          ];
          completedOperations++;
          notifyListeners();
        }
      }
    } on TestCancelledException {
      cancelled = true;
    } finally {
      tester.close();
      _tester = null;
      isRunning = false;
      isCancelling = false;
      hasValidResults = currentResults.any(
        (result) => result.samples.any((sample) => sample.succeeded),
      );
      currentStatus = cancelled
          ? '测试已取消'
          : hasValidResults
          ? '测试完成'
          : '测试完成，无有效结果';
      notifyListeners();
    }

    if (!cancelled && hasValidResults) {
      final run = TestRun(
        id: startedAt.microsecondsSinceEpoch.toString(),
        startedAt: startedAt,
        completedAt: DateTime.now(),
        repetitions: runRepetitions,
        warmUpCount: runWarmUpCount,
        network: runNetwork,
        results: List.of(currentResults),
      );
      await _database.saveRun(run);
      history = [run, ...history].take(20).toList();
      notifyListeners();
    }
  }

  void cancelTest() {
    if (!isRunning || isCancelling) return;
    isCancelling = true;
    currentStatus = '正在取消…';
    notifyListeners();
    _tester?.cancel();
  }

  Future<void> deleteHistory(String id) async {
    await _database.deleteRun(id);
    history = history.where((run) => run.id != id).toList();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _database.clearHistory();
    history = [];
    notifyListeners();
  }

  String? takeMessage() {
    final value = message;
    message = null;
    return value;
  }

  Future<void> _persistConfiguration() => _database.saveConfiguration(
    SavedConfiguration(
      targets: targets,
      repetitions: repetitions,
      warmUpCount: warmUpCount,
      timeoutSeconds: timeoutSeconds,
      ipLookupProvider: ipLookupProvider,
      ipLookupTimeoutSeconds: ipLookupTimeoutSeconds,
    ),
  );

  static String normalizeUrl(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('请输入完整的 http:// 或 https:// URL');
    }
    return uri.toString();
  }

  @override
  void dispose() {
    _tester?.cancel();
    super.dispose();
  }
}
