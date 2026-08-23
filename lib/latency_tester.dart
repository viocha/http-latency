import 'dart:async';
import 'dart:io';

import 'models.dart';

class TestCancelledException implements Exception {
  const TestCancelledException();
}

class ResponseTooLargeException implements Exception {
  const ResponseTooLargeException(this.limitBytes);

  final int limitBytes;
}

class LatencyTester {
  LatencyTester({
    required this.timeout,
    this.maxResponseBytes = 10 * 1024 * 1024,
  }) {
    _client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = timeout
      ..autoUncompress = true
      ..userAgent = 'HTTP-Latency/1.0 (Flutter)';
  }

  final Duration timeout;
  final int maxResponseBytes;
  late final HttpClient _client;
  bool _cancelled = false;
  void Function()? _abortCurrent;

  Future<RequestSample> measure(String url, int index) async {
    if (_cancelled) throw const TestCancelledException();
    final stopwatch = Stopwatch()..start();
    HttpClientRequest? request;
    StreamSubscription<List<int>>? subscription;
    Timer? timer;
    final completer = Completer<RequestSample>();
    var bytes = 0;
    int? statusCode;

    void completeError(Object error) {
      if (completer.isCompleted) return;
      stopwatch.stop();
      completer.complete(
        RequestSample(
          index: index,
          durationMs: null,
          statusCode: statusCode,
          bytes: bytes,
          error: _friendlyError(error),
        ),
      );
    }

    void abort({bool cancelled = false}) {
      request?.abort(
        cancelled ? const TestCancelledException() : TimeoutException('请求超时'),
      );
      subscription?.cancel();
      if (cancelled) {
        if (!completer.isCompleted) {
          completer.completeError(const TestCancelledException());
        }
      } else {
        completeError(TimeoutException('请求超过 ${timeout.inSeconds} 秒'));
      }
    }

    _abortCurrent = () => abort(cancelled: true);
    timer = Timer(timeout, abort);

    try {
      request = await _client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.acceptHeader, '*/*');
      final response = await request.close();
      statusCode = response.statusCode;
      subscription = response.listen(
        (chunk) {
          bytes += chunk.length;
          if (bytes > maxResponseBytes) {
            request?.abort(ResponseTooLargeException(maxResponseBytes));
            subscription?.cancel();
            completeError(ResponseTooLargeException(maxResponseBytes));
          }
        },
        onDone: () {
          if (completer.isCompleted) return;
          stopwatch.stop();
          completer.complete(
            RequestSample(
              index: index,
              durationMs: stopwatch.elapsedMilliseconds,
              statusCode: statusCode,
              bytes: bytes,
              error: null,
            ),
          );
        },
        onError: completeError,
        cancelOnError: true,
      );
    } on TestCancelledException {
      timer.cancel();
      _abortCurrent = null;
      rethrow;
    } catch (error) {
      completeError(error);
    }

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      _abortCurrent = null;
    }
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _abortCurrent?.call();
    _client.close(force: true);
  }

  void close() => _client.close(force: true);

  String _friendlyError(Object error) {
    if (error is TimeoutException) return '请求超时';
    if (error is ResponseTooLargeException) {
      final mb = error.limitBytes / (1024 * 1024);
      final limit = mb >= 1
          ? '${mb.toStringAsFixed(mb == mb.roundToDouble() ? 0 : 1)} MB'
          : '${error.limitBytes} B';
      return '响应体超过 $limit';
    }
    if (error is HandshakeException) return 'TLS 握手失败';
    if (error is SocketException) {
      return error.message.isEmpty ? '网络连接失败' : error.message;
    }
    if (error is HttpException) return error.message;
    if (error is FormatException) return 'URL 格式错误';
    return error.toString().replaceFirst('Exception: ', '');
  }
}
