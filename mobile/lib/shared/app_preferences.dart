import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WeekStart { sunday, monday }

enum MonthLabelFormat { numeric, spanish }

enum PaymentListViewMode { cards, table }

enum SubscriptionPlan { economic, premium }

class AppPreferences extends ChangeNotifier {
  AppPreferences._();

  static final instance = AppPreferences._();
  static const _weekStartKey = 'app_preferences:week_start';
  static const _monthLabelFormatKey = 'app_preferences:month_label_format';
  static const _generationHorizonKey =
      'app_preferences:generation_horizon_months';
  static const _paymentListViewModeKey =
      'app_preferences:payment_list_view_mode';
  static const _defaultCurrencyKey = 'app_preferences:default_currency';
  static const _localUserNameKey = 'app_preferences:local_user_name';
  static const _localUserEmailKey = 'app_preferences:local_user_email';
  static const _sessionClosedKey = 'app_preferences:session_closed';
  static const _subscriptionPlanKey = 'app_preferences:subscription_plan';
  static const _pinSaltKey = 'app_preferences:pin_salt';
  static const _pinHashKey = 'app_preferences:pin_hash';

  WeekStart weekStart = WeekStart.sunday;
  MonthLabelFormat monthLabelFormat = MonthLabelFormat.numeric;
  PaymentListViewMode paymentListViewMode = PaymentListViewMode.cards;
  SubscriptionPlan subscriptionPlan = SubscriptionPlan.economic;
  int generationHorizonMonths = 36;
  String defaultCurrency = 'MXN';
  String? localUserName;
  String? localUserEmail;
  bool sessionClosed = false;
  bool isPinUnlocked = false;
  String? _pinSalt;
  String? _pinHash;

  bool get hasLocalUser =>
      (localUserName?.trim().isNotEmpty ?? false) ||
      (localUserEmail?.trim().isNotEmpty ?? false);

  bool get isPremium => subscriptionPlan == SubscriptionPlan.premium;

  bool get syncEnabled => isPremium;

  bool get webEditingEnabled => isPremium;

  bool get serverBackupEnabled => isPremium;

  bool get hasPin => _pinSalt != null && _pinHash != null;

  bool get requiresPinUnlock => hasPin && !isPinUnlocked;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    weekStart = _enumByName(
      WeekStart.values,
      preferences.getString(_weekStartKey),
      WeekStart.sunday,
    );
    monthLabelFormat = _enumByName(
      MonthLabelFormat.values,
      preferences.getString(_monthLabelFormatKey),
      MonthLabelFormat.numeric,
    );
    paymentListViewMode = _enumByName(
      PaymentListViewMode.values,
      preferences.getString(_paymentListViewModeKey),
      PaymentListViewMode.cards,
    );
    subscriptionPlan = _enumByName(
      SubscriptionPlan.values,
      preferences.getString(_subscriptionPlanKey),
      SubscriptionPlan.economic,
    );
    generationHorizonMonths =
        preferences.getInt(_generationHorizonKey) ?? generationHorizonMonths;
    defaultCurrency =
        preferences.getString(_defaultCurrencyKey) ?? defaultCurrency;
    localUserName = preferences.getString(_localUserNameKey);
    localUserEmail = preferences.getString(_localUserEmailKey);
    sessionClosed = preferences.getBool(_sessionClosedKey) ?? false;
    _pinSalt = preferences.getString(_pinSaltKey);
    _pinHash = preferences.getString(_pinHashKey);
    isPinUnlocked = !hasPin;
    notifyListeners();
  }

  void setWeekStart(WeekStart value) {
    if (weekStart == value) return;
    weekStart = value;
    _saveString(_weekStartKey, value.name);
    notifyListeners();
  }

  void setMonthLabelFormat(MonthLabelFormat value) {
    if (monthLabelFormat == value) return;
    monthLabelFormat = value;
    _saveString(_monthLabelFormatKey, value.name);
    notifyListeners();
  }

  void setGenerationHorizonMonths(int value) {
    final months = value.clamp(6, 60).toInt();
    if (generationHorizonMonths == months) return;
    generationHorizonMonths = months;
    _saveInt(_generationHorizonKey, months);
    notifyListeners();
  }

  void setPaymentListViewMode(PaymentListViewMode value) {
    if (paymentListViewMode == value) return;
    paymentListViewMode = value;
    _saveString(_paymentListViewModeKey, value.name);
    notifyListeners();
  }

  void setDefaultCurrency(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.length != 3) return;
    if (normalized.isEmpty || defaultCurrency == normalized) return;
    defaultCurrency = normalized;
    _saveString(_defaultCurrencyKey, normalized);
    notifyListeners();
  }

  Future<void> setLocalUser({
    required String name,
    required String email,
  }) async {
    localUserName = name.trim();
    localUserEmail = email.trim().toLowerCase();
    sessionClosed = false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_localUserNameKey, localUserName ?? '');
    await preferences.setString(_localUserEmailKey, localUserEmail ?? '');
    await preferences.setBool(_sessionClosedKey, false);
    notifyListeners();
  }

  Future<void> closeSession() async {
    sessionClosed = true;
    isPinUnlocked = !hasPin;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_sessionClosedKey, true);
    notifyListeners();
  }

  Future<void> reopenSession() async {
    sessionClosed = false;
    isPinUnlocked = !hasPin;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_sessionClosedKey, false);
    notifyListeners();
  }

  void setSubscriptionPlanForLocalTesting(SubscriptionPlan value) {
    if (subscriptionPlan == value) return;
    subscriptionPlan = value;
    _saveString(_subscriptionPlanKey, value.name);
    notifyListeners();
  }

  Future<bool> setPin(String pin) async {
    if (!_isValidPin(pin)) return false;
    final salt = _newSalt();
    _pinSalt = salt;
    _pinHash = _hashPin(pin, salt);
    isPinUnlocked = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pinSaltKey, _pinSalt!);
    await preferences.setString(_pinHashKey, _pinHash!);
    notifyListeners();
    return true;
  }

  Future<void> clearPin() async {
    _pinSalt = null;
    _pinHash = null;
    isPinUnlocked = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pinSaltKey);
    await preferences.remove(_pinHashKey);
    notifyListeners();
  }

  bool verifyPin(String pin) {
    if (!hasPin) {
      isPinUnlocked = true;
      notifyListeners();
      return true;
    }
    if (!_isValidPin(pin)) return false;
    final matches = _hashPin(pin, _pinSalt!) == _pinHash;
    if (matches) {
      isPinUnlocked = true;
      notifyListeners();
    }
    return matches;
  }

  List<String> get weekdayLabels => weekStart == WeekStart.monday
      ? const ['L', 'M', 'M', 'J', 'V', 'S', 'D']
      : const ['D', 'L', 'M', 'M', 'J', 'V', 'S'];

  int monthGridOffset(DateTime firstDayOfMonth) {
    if (weekStart == WeekStart.monday) {
      return firstDayOfMonth.weekday - 1;
    }
    return firstDayOfMonth.weekday % 7;
  }

  Locale get datePickerLocale => weekStart == WeekStart.monday
      ? const Locale('es', 'ES')
      : const Locale('es', 'MX');

  String monthLabel(DateTime month) {
    if (monthLabelFormat == MonthLabelFormat.numeric) {
      return '${month.year}-${month.month.toString().padLeft(2, '0')}';
    }
    return '${_mexicanMonthNames[month.month - 1]} ${month.year}';
  }
}

bool _isValidPin(String value) => RegExp(r'^\d{4}$').hasMatch(value);

String _newSalt() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64UrlEncode(bytes);
}

String _hashPin(String pin, String salt) {
  return sha256.convert(utf8.encode('$salt:$pin')).toString();
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

Future<void> _saveString(String key, String value) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(key, value);
}

Future<void> _saveInt(String key, int value) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setInt(key, value);
}

const _mexicanMonthNames = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];
