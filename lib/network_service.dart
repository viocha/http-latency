import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'models.dart';

class NetworkService {
  Future<NetworkSnapshot> load() async {
    final connectivity = await Connectivity().checkConnectivity();
    final connectionType = _connectionLabel(connectivity);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse('https://ipwho.is/'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'HTTP-Latency/1.0');
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('IP 服务返回 HTTP ${response.statusCode}');
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['success'] != true) {
        throw HttpException(json['message']?.toString() ?? 'IP 服务暂时不可用');
      }
      final ip = json['ip']?.toString();
      final connection = json['connection'] is Map
          ? Map<String, dynamic>.from(json['connection'] as Map)
          : const <String, dynamic>{};
      return NetworkSnapshot(
        connectionType: connectionType,
        ip: ip,
        ipVersion:
            json['type']?.toString() ??
            (ip?.contains(':') == true ? 'IPv6' : 'IPv4'),
        country: json['country']?.toString(),
        city: json['city']?.toString(),
        isp: connection['isp']?.toString() ?? connection['org']?.toString(),
        updatedAt: DateTime.now(),
      );
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
