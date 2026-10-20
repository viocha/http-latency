import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http_latency/ip_lookup_provider.dart';

void main() {
  final responses = {
    IpLookupProvider.ipwhoIs: {
      'success': true,
      'ip': '198.51.100.2',
      'country': 'China',
      'city': 'Shanghai',
      'connection': {'isp': 'Example ISP'},
    },
    IpLookupProvider.ipSb: {
      'ip': '198.51.100.2',
      'country': 'China',
      'city': 'Shanghai',
      'isp': 'Example ISP',
    },
    IpLookupProvider.freeIpApi: {
      'ipAddress': '198.51.100.2',
      'ipVersion': 4,
      'countryName': 'China',
      'cityName': 'Shanghai',
      'asnOrganization': 'Example ISP',
    },
  };

  for (final entry in responses.entries) {
    test('${entry.key.label} 的响应转换为统一网络信息', () {
      final snapshot = entry.key.parseResponse(
        entry.value,
        connectionType: 'Wi‑Fi',
      );
      expect(snapshot.connectionType, 'Wi‑Fi');
      expect(snapshot.ip, '198.51.100.2');
      expect(snapshot.ipVersion, 'IPv4');
      expect(snapshot.country, 'China');
      expect(snapshot.city, 'Shanghai');
      expect(snapshot.isp, 'Example ISP');
      expect(snapshot.updatedAt, isNotNull);
      expect(snapshot.error, isNull);
    });
  }

  test('IPv6 与缺失的地理信息可以正常解析', () {
    final snapshot = IpLookupProvider.ipSb.parseResponse({
      'ip': '2001:db8::1',
      'country': ' ',
      'asn_organization': 'Example ASN',
    }, connectionType: '移动数据');
    expect(snapshot.ipVersion, 'IPv6');
    expect(snapshot.country, isNull);
    expect(snapshot.city, isNull);
    expect(snapshot.isp, 'Example ASN');
  });

  test('拒绝服务错误和无效 IP，保留接口的错误信息', () {
    expect(
      () => IpLookupProvider.ipwhoIs.parseResponse({
        'success': false,
        'message': 'Rate limit exceeded',
      }, connectionType: 'Wi‑Fi'),
      throwsA(
        isA<HttpException>().having(
          (error) => error.message,
          'message',
          'Rate limit exceeded',
        ),
      ),
    );
    for (final provider in IpLookupProvider.values) {
      expect(
        () => provider.parseResponse({
          'success': true,
          'ip': 'invalid',
          'ipAddress': 'invalid',
        }, connectionType: 'Wi‑Fi'),
        throwsFormatException,
      );
      expect(
        () => provider.parseResponse([], connectionType: 'Wi‑Fi'),
        throwsFormatException,
      );
    }
  });
}
