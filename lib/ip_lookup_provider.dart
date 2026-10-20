import 'dart:io';

import 'models.dart';

enum IpLookupProvider {
  ipwhoIs('ipwho_is', 'ipwho.is', 'https://ipwho.is/'),
  ipSb('ip_sb', 'IP.SB', 'https://api.ip.sb/geoip'),
  freeIpApi(
    'free_ip_api',
    'FreeIPAPI',
    'https://free.freeipapi.com/api/v1/json',
  );

  const IpLookupProvider(this.id, this.label, this.url);

  final String id;
  final String label;
  final String url;

  static IpLookupProvider fromId(String? id) =>
      values.firstWhere((provider) => provider.id == id, orElse: () => ipwhoIs);

  NetworkSnapshot parseResponse(
    Object? data, {
    required String connectionType,
  }) {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('公网 IP 服务响应异常');
    }
    if (this == ipwhoIs && data['success'] != true) {
      throw HttpException(data['message']?.toString() ?? 'IP 服务暂时不可用');
    }

    String? text(Object? value) {
      if (value is! String || value.trim().isEmpty) return null;
      return value.trim();
    }

    final ip = text(data[this == freeIpApi ? 'ipAddress' : 'ip']);
    if (ip == null || InternetAddress.tryParse(ip) == null) {
      throw const FormatException('公网 IP 服务响应缺少有效 IP');
    }
    final connection = data['connection'] is Map
        ? data['connection'] as Map
        : const {};
    final isp = switch (this) {
      ipwhoIs => text(connection['isp']) ?? text(connection['org']),
      ipSb =>
        text(data['isp']) ??
            text(data['organization']) ??
            text(data['asn_organization']),
      freeIpApi => text(data['asnOrganization']),
    };
    return NetworkSnapshot(
      connectionType: connectionType,
      ip: ip,
      ipVersion: ip.contains(':') ? 'IPv6' : 'IPv4',
      country: text(data[this == freeIpApi ? 'countryName' : 'country']),
      city: text(data[this == freeIpApi ? 'cityName' : 'city']),
      isp: isp,
      updatedAt: DateTime.now(),
    );
  }
}
