import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalJsonCache {
  LocalJsonCache._();

  static final instance = LocalJsonCache._();
  static const _prefix = 'app_pagos_cache:';

  Future<void> write(String key, Object? data) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '$_prefix$key',
      jsonEncode({'cached_at': DateTime.now().toIso8601String(), 'data': data}),
    );
  }

  Future<dynamic> read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('$_prefix$key');
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
      return decoded['data'];
    }
    return decoded;
  }
}
