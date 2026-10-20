import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'ip_lookup_provider.dart';
import 'models.dart';

class NetworkService {
  Future<NetworkSnapshot> load({
    IpLookupProvider provider = IpLookupProvider.ipwhoIs,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    var connectionType = '未知';
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = timeout;

    Future<NetworkSnapshot> query() async {
      final connectivity = await Connectivity().checkConnectivity();
      connectionType = _connectionLabel(connectivity);
      final request = await client.getUrl(Uri.parse(provider.url));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'HTTP-Latency/1.0');
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('IP 服务返回 HTTP ${response.statusCode}');
      }
      return provider.parseResponse(
        jsonDecode(body),
        connectionType: connectionType,
      );
    }

    try {
      return await query().timeout(timeout);
    } catch (error) {
      return NetworkSnapshot(
        connectionType: connectionType,
        updatedAt: DateTime.now(),
        error: _friendlyError(error),
      );
    } finally {
      client.close(force: true);
    }
  }

  String _connectionLabel(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return '未连接';
    }
    final labels = <String>[];
    if (results.contains(ConnectivityResult.vpn)) labels.add('VPN');
    if (results.contains(ConnectivityResult.wifi)) labels.add('Wi‑Fi');
    if (results.contains(ConnectivityResult.mobile)) labels.add('移动数据');
    if (results.contains(ConnectivityResult.ethernet)) labels.add('以太网');
    if (labels.isEmpty) labels.add('其他');
    return labels.join(' + ');
  }

  String _friendlyError(Object error) {
    if (error is TimeoutException) return '公网 IP 查询超时';
    if (error is SocketException) return '无法连接公网 IP 服务';
    if (error is FormatException) return '公网 IP 服务响应异常';
    if (error is HttpException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }
}
