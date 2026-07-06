import 'dart:convert';

import 'package:http/http.dart' as http;

import '../storage/local_json_cache.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.userId,
    this.accessTokenProvider,
    http.Client? httpClient,
  }) : baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final String userId;
  final Future<String?> Function()? accessTokenProvider;
  final http.Client _httpClient;

  Future<Map<String, String>> _headers() async {
    final headers = {
      'Content-Type': 'application/json',
      'X-User-Id': userId,
    };
    final token = await accessTokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, Object?> query = const {}]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final queryParameters = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null) continue;
      queryParameters[entry.key] = value.toString();
    }
    return Uri.parse('$baseUrl$normalizedPath').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }

  Future<dynamic> getJson(
    String path, [
    Map<String, Object?> query = const {},
  ]) async {
    final response = await _httpClient.get(
      _uri(path, query),
      headers: await _headers(),
    );
    return _decode(response);
  }

  Future<dynamic> getJsonCached(
    String path,
    Map<String, Object?> query, {
    required String cacheKey,
    String? fallbackCacheKey,
  }) async {
    try {
      final data = await getJson(path, query);
      await LocalJsonCache.instance.write(cacheKey, data);
      if (fallbackCacheKey != null) {
        await LocalJsonCache.instance.write(fallbackCacheKey, data);
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (_) {
      final exact = await LocalJsonCache.instance.read(cacheKey);
      if (exact != null) return exact;
      if (fallbackCacheKey != null) {
        final fallback = await LocalJsonCache.instance.read(fallbackCacheKey);
        if (fallback != null) return fallback;
      }
      throw ApiException(
        'Sin conexion al servidor y aun no hay datos locales guardados. '
        'Abre la app una vez con el servidor disponible para guardar una copia local.',
      );
    }
  }

  Future<dynamic> postJson(String path, Map<String, Object?> body) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> patchJson(String path, Map<String, Object?> body) async {
    final response = await _httpClient.patch(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    final statusCode = response.statusCode;
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (statusCode >= 200 && statusCode < 300) {
      return body;
    }

    final detail = body is Map<String, dynamic> ? body['detail'] : null;
    throw ApiException(
      detail?.toString() ?? 'Error de API ($statusCode)',
      statusCode: statusCode,
    );
  }
}
