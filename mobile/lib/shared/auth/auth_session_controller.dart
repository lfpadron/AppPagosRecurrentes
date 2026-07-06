import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';

class AuthProfile {
  const AuthProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.isPremium,
    required this.plan,
    this.premiumSource,
    this.currentPeriodEnd,
  });

  final String id;
  final String email;
  final String name;
  final bool isPremium;
  final String plan;
  final String? premiumSource;
  final DateTime? currentPeriodEnd;

  factory AuthProfile.fromJson(Map<String, dynamic> json) {
    final periodEnd = json['current_period_end'] as String?;
    return AuthProfile(
      id: json['id'].toString(),
      email: json['email'].toString(),
      name: json['name'].toString(),
      isPremium: json['is_premium'] == true,
      plan: json['plan'].toString(),
      premiumSource: json['premium_source'] as String?,
      currentPeriodEnd: periodEnd == null ? null : DateTime.parse(periodEnd),
    );
  }
}

class AuthSessionController extends ChangeNotifier {
  AuthSessionController._();

  static final instance = AuthSessionController._();

  StreamSubscription<AuthState>? _authSubscription;
  AuthProfile? _profile;
  bool _initialized = false;
  bool _loadingProfile = false;
  String? _profileError;

  bool get isConfigured => AppConfig.supabaseAuthEnabled;
  bool get initialized => _initialized;
  bool get loadingProfile => _loadingProfile;
  String? get profileError => _profileError;
  AuthProfile? get profile => _profile;

  bool get isSignedIn {
    if (!isConfigured || !_initialized) return false;
    return Supabase.instance.client.auth.currentSession != null;
  }

  String? get accessToken {
    if (!isConfigured || !_initialized) return null;
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  String? get userEmail {
    if (!isConfigured || !_initialized) return null;
    return Supabase.instance.client.auth.currentUser?.email;
  }

  Future<void> initialize() async {
    if (_initialized || !isConfigured) return;
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      _,
    ) {
      _profile = null;
      _profileError = null;
      notifyListeners();
    });
    _initialized = true;
    notifyListeners();
  }

  Future<void> sendOtp(String email) async {
    _requireConfigured();
    await Supabase.instance.client.auth.signInWithOtp(
      email: email.trim().toLowerCase(),
      emailRedirectTo: kIsWeb ? null : 'io.supabase.flutter://signin-callback/',
    );
  }

  Future<void> verifyOtp(String email, String token) async {
    _requireConfigured();
    await Supabase.instance.client.auth.verifyOTP(
      type: OtpType.email,
      email: email.trim().toLowerCase(),
      token: token.trim(),
    );
    await loadProfile(force: true);
  }

  Future<void> signOut() async {
    if (isConfigured && _initialized) {
      await Supabase.instance.client.auth.signOut();
    }
    _profile = null;
    _profileError = null;
    notifyListeners();
  }

  Future<void> loadProfile({bool force = false}) async {
    if (!isSignedIn) return;
    if (_profile != null && !force) return;
    if (_loadingProfile) return;

    final token = accessToken;
    if (token == null || token.isEmpty) return;

    _loadingProfile = true;
    _profileError = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = response.body.isEmpty
          ? null
          : jsonDecode(response.body) as Object?;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = body is Map<String, dynamic> ? body['detail'] : null;
        throw Exception(detail?.toString() ?? 'Error de autenticacion');
      }
      _profile = AuthProfile.fromJson(body as Map<String, dynamic>);
    } catch (error) {
      _profileError = error.toString().replaceFirst('Exception: ', '');
    } finally {
      _loadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> disposeController() async {
    await _authSubscription?.cancel();
  }

  void _requireConfigured() {
    if (!isConfigured || !_initialized) {
      throw StateError('Supabase Auth no esta configurado.');
    }
  }
}
