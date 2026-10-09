import 'dart:async';

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'models.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.controller, super.key});
  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  bool _showInitialLoading = false;
  Timer? _initialLoadingTimer;

  @override
  void initState() {
    super.initState();
    _initialLoadingTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || widget.controller.initialized) return;
      setState(() => _showInitialLoading = true);
    });
  }

  @override
  void dispose() {
    _initialLoadingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      if (!c.initialized) {
        return Scaffold(
          body: _showInitialLoading
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.expand(),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(['HTTP 延迟测试', '最近 20 次', '设置'][index]),
          actions: [
            if (index == 1)
              IconButton(
                onPressed: c.history.isEmpty
                    ? null
                    : () => HistoryPage.confirmClear(context, c),
                tooltip: '清空历史',
                icon: const Icon(Icons.delete_sweep),
              ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth > 760
                ? (constraints.maxWidth - 760) / 2
                : 0.0;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              child: IndexedStack(
                index: index,
                children: [TestPage(c), HistoryPage(c), SettingsPage(c)],
              ),
            );
          },
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.speed), label: '测试'),
            NavigationDestination(icon: Icon(Icons.history), label: '历史'),
            NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
          ],
        ),
      );
    },
  );
}

class TestPage extends StatelessWidget {
  const TestPage(this.c, {super.key});
  final AppController c;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          children: [
            NetworkCard(c),
            const SizedBox(height: 10),
            Semantics(
              container: true,
              enabled: !c.isRunning,
              child: IgnorePointer(
                ignoring: c.isRunning,
                child: AnimatedOpacity(
                  opacity: c.isRunning ? 0.55 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      onTap: () => _showTargetPicker(context),
                      title: const Text('测试目标'),
                      subtitle: Text(
                        '已选择 ${c.selectedCount}/${c.targets.length}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              container: true,
              enabled: !c.isRunning,
              child: IgnorePointer(
                ignoring: c.isRunning,
                child: AnimatedOpacity(
                  opacity: c.isRunning ? 0.55 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Text('次数'),
                          const SizedBox(width: 12),
                          DropdownButton<int>(
                            value: c.repetitions,
                            items: [
                              for (var n = 1; n <= 5; n++)
                                DropdownMenuItem(value: n, child: Text('$n 次')),
                            ],
                            onChanged: (n) {
                              if (n != null) c.setRepetitions(n);
                            },
                          ),
                          const Spacer(),
                          const Text('预热'),
                          const SizedBox(width: 12),
                          DropdownButton<int>(
                            value: c.warmUpCount,
                            items: [
                              for (var n = 0; n <= 5; n++)
                                DropdownMenuItem(value: n, child: Text('$n 次')),
                            ],
                            onChanged: (n) {
                              if (n != null) c.setWarmUpCount(n);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        child: Row(
          children: [
            Text('本次结果', style: Theme.of(context).textTheme.titleMedium),
            if (!c.isRunning && c.currentResults.isNotEmpty) ...[
              const SizedBox(width: 12),
              Builder(
                builder: (context) {
                  final average = TestRun.calculateOverallAverageMs(
                    c.currentResults,
                  );
                  return Text(
                    average == null ? '无有效结果' : '整体延迟 ${average.round()} ms',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: average == null
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
            ],
            const Spacer(),
            if (c.currentResults.isNotEmpty)
              Text(
                '${c.currentResults.length} 个目标',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
      Expanded(
        child: c.currentResults.isEmpty
            ? c.isRunning
                  ? const SizedBox.shrink()
                  : Center(
                      child: Text(
                        '选择目标并开始测试',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                itemCount: c.currentResults.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => ResultCard(
                  c.currentResults[index],
                  testing:
                      c.isRunning &&
                      c.currentResults[index].samples.length < c.repetitions,
                  expectedSamples: c.repetitions,
                ),
              ),
      ),
      TestActionBar(c),
    ],
  );

  Future<void> _showTargetPicker(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => FractionallySizedBox(
          heightFactor: 0.86,
          child: AnimatedBuilder(
            animation: c,
            builder: (context, _) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '选择测试目标',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            c.selectAll(c.selectedCount != c.targets.length),
                        child: Text(
                          c.selectedCount == c.targets.length ? '取消全选' : '全选',
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: c.targets.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 56),
                    itemBuilder: (context, index) {
                      final target = c.targets[index];
                      return CheckboxListTile(
                        value: target.selected,
                        onChanged: (value) =>
                            c.setTargetSelected(target.id, value ?? false),
                        title: Text(target.name),
                        subtitle: Text(
                          target.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        secondary: Icon(
                          target.isBuiltIn ? Icons.lock_outline : Icons.link,
                          size: 20,
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text('完成 · 已选择 ${c.selectedCount} 个'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class TestActionBar extends StatelessWidget {
  const TestActionBar(this.c, {super.key});
  final AppController c;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 8,
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (c.isRunning || c.completedOperations > 0) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.currentStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('${c.completedOperations}/${c.totalOperations}'),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: c.isRunning ? c.progress : 1),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              onPressed: c.isRunning ? c.cancelTest : c.runTest,
              icon: Icon(
                c.isRunning ? Icons.stop_circle_outlined : Icons.play_arrow,
              ),
              label: Text(
                c.isRunning ? (c.isCancelling ? '正在取消…' : '取消测试') : '开始测试',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class NetworkCard extends StatelessWidget {
  const NetworkCard(this.c, {super.key});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    final n = c.network;
    final isInitialDetection = n.connectionType == '检测中';
    final place = formatCountryAndCity(n.country, n.city);
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isInitialDetection ? '检测中' : n.connectionType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: '刷新',
                  onPressed: c.isLoadingNetwork ? null : c.refreshNetwork,
                  icon: c.isLoadingNetwork
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            if (!isInitialDetection)
              Text(
                n.ip ?? '公网 IP 未知',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (place.isNotEmpty)
              Text(place, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (n.isp?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  n.isp!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (n.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  n.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ResultCard extends StatelessWidget {
  const ResultCard(
    this.result, {
    this.testing = false,
    this.expectedSamples,
    super.key,
  });
  final TargetResult result;
  final bool testing;
  final int? expectedSamples;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(result.target.name),
      subtitle: Text(
        testing
            ? '测试中 ${result.samples.length}/${expectedSamples ?? '—'}'
            : result.averageMs == null
            ? '无有效结果'
            : '平均 ${result.averageMs!.toStringAsFixed(1)} ms',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Row(
          children: [
            Expanded(child: Metric('最小值', formatDuration(result.minimumMs))),
            Expanded(child: Metric('最大值', formatDuration(result.maximumMs))),
            Expanded(
              child: Metric(
                '平均值',
                result.averageMs == null
                    ? '—'
                    : '${result.averageMs!.toStringAsFixed(1)} ms',
              ),
            ),
          ],
        ),
        const Divider(height: 24),
        for (final s in result.samples)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(radius: 15, child: Text('${s.index}')),
            title: Text(
              s.succeeded ? formatDuration(s.durationMs) : s.error ?? '失败',
            ),
            subtitle: Text(
              'HTTP ${s.statusCode ?? '—'} · ${formatBytes(s.bytes)}',
            ),
            trailing: Icon(
              s.succeeded ? Icons.check_circle : Icons.error,
              color: s.succeeded
                  ? Colors.green
                  : Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    ),
  );
}

class HistoryPage extends StatelessWidget {
  const HistoryPage(this.c, {super.key});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    if (c.history.isEmpty) return const Center(child: Text('还没有测试历史'));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        for (final run in c.history) ...[
          Builder(
            builder: (context) {
              final networkInfo = formatCountryAndIsp(
                run.network.country,
                run.network.isp,
              );
              final ip = run.network.ip ?? '公网 IP 未知';
              final average = run.overallAverageMs;
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => HistoryDetail(run),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatDateTime(run.startedAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        average == null ? '无有效结果' : '${average.round()} ms',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: average == null
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => c.deleteHistory(run.id),
                        tooltip: '删除记录',
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${run.network.connectionType}\n$ip${networkInfo.isEmpty ? '' : '\n$networkInfo'}',
                    maxLines: networkInfo.isEmpty ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  static Future<void> confirmClear(
    BuildContext context,
    AppController controller,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空全部历史？'),
        content: const Text('最近 20 次记录将从本机永久删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.clearHistory();
  }
}

class HistoryDetail extends StatelessWidget {
  const HistoryDetail(this.run, {super.key});
  final TestRun run;

  @override
  Widget build(BuildContext context) {
    final network = run.network;
    final location = formatCountryAndCity(network.country, network.city);
    final content = Scaffold(
      appBar: AppBar(
        title: const Text('历史详情'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  InfoRow('时间', formatDateTime(run.startedAt)),
                  InfoRow('网络', network.connectionType),
                  InfoRow('公网 IP', network.ip ?? '—'),
                  InfoRow('国家/城市', location.isEmpty ? '—' : location),
                  InfoRow('运营商', network.isp ?? '—'),
                  InfoRow(
                    '查询时间',
                    network.updatedAt == null
                        ? '—'
                        : formatDateTime(network.updatedAt!),
                  ),
                  InfoRow(
                    '设置',
                    '${run.repetitions} 次 · 预热 ${run.warmUpCount} 次',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final result in run.results) ...[
            ResultCard(result),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
    final size = MediaQuery.sizeOf(context);
    if (size.width < 800) return Dialog.fullscreen(child: content);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 720,
        height: (size.height - 64).clamp(480, 760),
        child: content,
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage(this.c, {super.key});
  final AppController c;

  @override
  Widget build(BuildContext context) {
    final custom = c.targets.where((t) => !t.isBuiltIn).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        SectionTitle(
          '自定义 URL',
          trailing: FilledButton.tonalIcon(
            onPressed: c.isRunning ? null : () => editTarget(context),
            icon: const Icon(Icons.add),
            label: const Text('添加'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: custom.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('还没有自定义 URL'),
                )
              : ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderItem: c.reorderCustomTargets,
                  children: [
                    for (var i = 0; i < custom.length; i++)
                      Column(
                        key: ValueKey(custom[i].id),
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            minLeadingWidth: 24,
                            horizontalTitleGap: 8,
                            leading: ReorderableDragStartListener(
                              index: i,
                              enabled: !c.isRunning,
                              child: Tooltip(
                                message: '拖动排序',
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Icon(
                                    Icons.drag_handle,
                                    color: c.isRunning
                                        ? Theme.of(context).disabledColor
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(custom[i].name),
                            subtitle: Text(
                              custom[i].url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  tooltip: '编辑',
                                  constraints: const BoxConstraints.tightFor(
                                    width: 36,
                                    height: 40,
                                  ),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      editTarget(context, custom[i]),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: '删除',
                                  constraints: const BoxConstraints.tightFor(
                                    width: 36,
                                    height: 40,
                                  ),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      confirmDeleteTarget(context, custom[i]),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                          if (i < custom.length - 1) const Divider(height: 1),
                        ],
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        const SectionTitle('请求限制'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('单次请求总超时'),
                trailing: DropdownButton<int>(
                  value: c.timeoutSeconds,
                  items: const [3, 5, 10, 15]
                      .map(
                        (n) => DropdownMenuItem(value: n, child: Text('$n 秒')),
                      )
                      .toList(),
                  onChanged: c.isRunning
                      ? null
                      : (n) {
                          if (n != null) c.setTimeoutSeconds(n);
                        },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('最大响应体'),
                trailing: Text(
                  '10 MB',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> editTarget(BuildContext context, [TestTarget? target]) =>
      showDialog<void>(
        context: context,
        builder: (context) =>
            _TargetEditorDialog(controller: c, target: target),
      );

  Future<void> confirmDeleteTarget(
    BuildContext context,
    TestTarget target,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除自定义 URL？'),
        content: Text(target.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) c.deleteCustomTarget(target.id);
  }
}

class _TargetEditorDialog extends StatefulWidget {
  const _TargetEditorDialog({required this.controller, this.target});

  final AppController controller;
  final TestTarget? target;

  @override
  State<_TargetEditorDialog> createState() => _TargetEditorDialogState();
}

class _TargetEditorDialogState extends State<_TargetEditorDialog> {
  late final TextEditingController name;
  late final TextEditingController url;
  String? error;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.target?.name ?? '');
    url = TextEditingController(text: widget.target?.url ?? 'https://');
  }

  @override
  void dispose() {
    name.dispose();
    url.dispose();
    super.dispose();
  }

  void save() {
    if (name.text.trim().isEmpty) {
      setState(() => error = '请输入名称');
      return;
    }
    try {
      final target = widget.target;
      if (target == null) {
        widget.controller.addCustomTarget(name.text, url.text);
      } else {
        widget.controller.updateCustomTarget(target.id, name.text, url.text);
      }
      Navigator.pop(context);
    } on FormatException catch (exception) {
      setState(() => error = exception.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.target == null ? '添加自定义 URL' : '编辑自定义 URL'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: '名称'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(labelText: 'URL', errorText: error),
            onSubmitted: (_) => save(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: save, child: const Text('保存')),
    ],
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.subtitle, this.trailing, super.key});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null)
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}

class Metric extends StatelessWidget {
  const Metric(this.label, this.value, {super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );
}

String formatDateTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}
