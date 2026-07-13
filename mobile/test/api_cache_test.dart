import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pagos_recurrentes_mobile/core/network/api_client.dart';

void main() {
  test('cached GET data is returned when network is unavailable', () async {
    SharedPreferences.setMockInitialValues({});
    var offline = false;
    final apiClient = ApiClient(
      baseUrl: 'http://example.test',
      userId: 'user-1',
      httpClient: MockClient((request) async {
        if (offline) {
          throw http.ClientException('offline', request.url);
        }
        return http.Response(
          '[{"id":"payment-1","service_name":"Internet"}]',
          200,
        );
      }),
    );

    final onlineData =
        await apiClient.getJsonCached(
              '/payments',
              const {},
              cacheKey: 'payments:test',
              fallbackCacheKey: 'payments:last',
            )
            as List<dynamic>;
    offline = true;
    final cachedData =
        await apiClient.getJsonCached(
              '/payments',
              const {'start_date': '2026-05-18'},
              cacheKey: 'payments:other',
              fallbackCacheKey: 'payments:last',
            )
            as List<dynamic>;

    expect(onlineData.first['id'], 'payment-1');
    expect(cachedData.first['service_name'], 'Internet');
  });

  test('HTML API responses are reported as API configuration errors', () async {
    final apiClient = ApiClient(
      baseUrl: 'https://app.pagos-recurrentes.com',
      userId: 'user-1',
      httpClient: MockClient(
        (_) async => http.Response('<!DOCTYPE html><html></html>', 200),
      ),
    );

    expect(
      () => apiClient.getJson('/payments'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('API_BASE_URL=https://api.pagos-recurrentes.com'),
        ),
      ),
    );
  });
}
