import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/payments/data/payment_instance.dart';
import '../../features/services/data/service_account.dart';
import '../../shared/app_preferences.dart';
import 'local_json_cache.dart';

class LocalAppDatabase {
  LocalAppDatabase({required this.userId});

  static const _servicesKey = 'local_app_database:services';
  static const _paymentsKey = 'local_app_database:payments';
  static const _seededKey = 'local_app_database:seeded_v2';
  static const _schemaVersionKey = 'local_app_database:schema_version';
  static const _deviceIdKey = 'local_app_database:device_id';
  static const _currentSchemaVersion = 3;
  static final _random = Random();

  final String userId;

  static int get currentSchemaVersion => _currentSchemaVersion;

  String newId(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = [
      _random.nextInt(0x10000).toRadixString(16).padLeft(4, '0'),
      _random.nextInt(0x10000).toRadixString(16).padLeft(4, '0'),
    ].join();
    return '$prefix-$now-$random';
  }

  Future<List<ServiceAccount>> listServices({
    String? objectName,
    ServiceLifecycleStatus? status,
    int limit = 30,
    int offset = 0,
  }) async {
    await ensureInitialized();
    final objectFilter = objectName?.trim().toLowerCase();
    final services = (await _readServices())
      ..sort((a, b) => a.objectName.compareTo(b.objectName));
    final filtered = services.where((service) {
      final matchesObject =
          objectFilter == null ||
          objectFilter.isEmpty ||
          service.objectName.toLowerCase().contains(objectFilter);
      final matchesStatus = status == null || service.status == status;
      return matchesObject && matchesStatus;
    }).toList();
    return filtered.skip(offset).take(limit).toList();
  }

  Future<ServiceAccount> createService(ServiceAccount service) async {
    await ensureInitialized();
    final normalized = await _markServiceModified(service);
    final services = await _readServices();
    services.add(normalized);
    await _writeServices(services);
    await _appendGeneratedPayments(
      normalized,
      effectiveFrom: normalized.initialDueDate,
    );
    return normalized;
  }

  Future<ServiceAccount> updateService(
    ServiceAccount service,
    DateTime effectiveFrom,
  ) async {
    await ensureInitialized();
    final normalized = await _markServiceModified(service);
    final services = await _readServices();
    final index = services.indexWhere((item) => item.id == normalized.id);
    if (index == -1) {
      services.add(normalized);
    } else {
      services[index] = normalized;
    }
    await _writeServices(services);

    final payments = await _readPayments();
    final nextPayments = payments.map((payment) {
      final replaceable =
          payment.serviceAccountId == normalized.id &&
          payment.generatedBySystem &&
          payment.status != PaymentStatus.paid &&
          !payment.dueDate.isBefore(_dateOnly(effectiveFrom));
      if (!replaceable) return payment;
      return payment.copyWith(status: PaymentStatus.cancelledByRecalculation);
    }).toList();
    await _writePayments(nextPayments);

    if (normalized.status == ServiceLifecycleStatus.active &&
        normalized.active) {
      await _appendGeneratedPayments(normalized, effectiveFrom: effectiveFrom);
    }
    return normalized;
  }

  Future<List<PaymentInstance>> listPayments({
    DateTime? startDate,
    DateTime? endDate,
    PaymentStatus? status,
    PaymentType? paymentType,
    String? serviceAccountId,
    String? objectName,
    String? serviceName,
    String? providerName,
    String? currency,
    bool? isAutopay,
    bool includeCancelled = false,
    int limit = 90,
    int offset = 0,
  }) async {
    await ensureInitialized();
    final objectFilter = objectName?.trim().toLowerCase();
    final serviceFilter = serviceName?.trim().toLowerCase();
    final providerFilter = providerName?.trim().toLowerCase();
    final currencyFilter = currency?.trim().toUpperCase();
    final start = startDate == null ? null : _dateOnly(startDate);
    final end = endDate == null ? null : _dateOnly(endDate);
    final payments =
        (await _readPayments()).map(withCurrentStatus).where((payment) {
          if (!includeCancelled &&
              (payment.status == PaymentStatus.cancelled ||
                  payment.status == PaymentStatus.cancelledByRecalculation)) {
            return false;
          }
          if (start != null && payment.dueDate.isBefore(start)) return false;
          if (end != null && payment.dueDate.isAfter(end)) return false;
          if (status != null && payment.status != status) return false;
          if (paymentType != null && payment.paymentType != paymentType) {
            return false;
          }
          if (serviceAccountId != null &&
              payment.serviceAccountId != serviceAccountId) {
            return false;
          }
          if (objectFilter != null &&
              objectFilter.isNotEmpty &&
              !payment.objectName.toLowerCase().contains(objectFilter)) {
            return false;
          }
          if (serviceFilter != null &&
              serviceFilter.isNotEmpty &&
              !payment.serviceName.toLowerCase().contains(serviceFilter)) {
            return false;
          }
          if (providerFilter != null &&
              providerFilter.isNotEmpty &&
              !payment.providerName.toLowerCase().contains(providerFilter)) {
            return false;
          }
          if (currencyFilter != null &&
              currencyFilter.isNotEmpty &&
              payment.currency.toUpperCase() != currencyFilter) {
            return false;
          }
          if (isAutopay != null && payment.isAutopay != isAutopay) {
            return false;
          }
          return true;
        }).toList()..sort((a, b) {
          final due = a.dueDate.compareTo(b.dueDate);
          if (due != 0) return due;
          return a.serviceName.compareTo(b.serviceName);
        });
    return payments.skip(offset).take(limit).toList();
  }

  Future<PaymentInstance> createPayment(PaymentInstance payment) async {
    await ensureInitialized();
    final normalized = await _markPaymentModified(withCurrentStatus(payment));
    final payments = await _readPayments();
    payments.add(normalized);
    await _writePayments(payments);
    return normalized;
  }

  Future<PaymentInstance> getPayment(String id) async {
    await ensureInitialized();
    final payment = (await _readPayments()).firstWhere(
      (item) => item.id == id,
      orElse: () => throw StateError('Pago no encontrado'),
    );
    return withCurrentStatus(payment);
  }

  Future<PaymentInstance> updatePayment(PaymentInstance payment) async {
    await ensureInitialized();
    final normalized = await _markPaymentModified(withCurrentStatus(payment));
    final payments = await _readPayments();
    final index = payments.indexWhere((item) => item.id == payment.id);
    if (index == -1) {
      payments.add(normalized);
    } else {
      payments[index] = normalized;
    }
    await _writePayments(payments);
    return normalized;
  }

  PaymentInstance withCurrentStatus(PaymentInstance payment) {
    if (payment.status == PaymentStatus.paid ||
        payment.status == PaymentStatus.cancelled ||
        payment.status == PaymentStatus.cancelledByRecalculation ||
        payment.status == PaymentStatus.notApplicableException) {
      return payment;
    }
    final today = _dateOnly(DateTime.now());
    final due = _dateOnly(payment.dueDate);
    final days = due.difference(today).inDays;
    final status = payment.isAutopay
        ? days < 0
              ? PaymentStatus.autopayPendingConfirmation
              : days <= 7
              ? PaymentStatus.autopayDueSoon
              : PaymentStatus.autopayFuture
        : days < 0
        ? PaymentStatus.overdue
        : days <= 7
        ? PaymentStatus.dueSoon
        : days <= 14
        ? PaymentStatus.upcoming
        : PaymentStatus.future;
    return payment.copyWith(status: status);
  }

  Future<void> ensureInitialized() async {
    final preferences = await SharedPreferences.getInstance();
    final seeded = preferences.getBool(_seededKey) ?? false;
    final hasServices = preferences.getString(_servicesKey) != null;
    if (seeded || hasServices) {
      await _migrateIfNeeded(preferences);
      return;
    }

    final cachedServices = await LocalJsonCache.instance.read('services:last');
    if (cachedServices is List<dynamic> && cachedServices.isNotEmpty) {
      final services = cachedServices
          .map((item) => ServiceAccount.fromJson(item as Map<String, dynamic>))
          .toList();
      final cachedPayments = await LocalJsonCache.instance.read(
        'payments:last',
      );
      final payments = cachedPayments is List<dynamic>
          ? cachedPayments
                .map(
                  (item) => withCurrentStatus(
                    PaymentInstance.fromJson(item as Map<String, dynamic>),
                  ),
                )
                .toList()
          : services.expand(_generatePaymentsForService).toList();
      await _writeServices(services);
      await _writePayments(payments);
      await preferences.setBool(_seededKey, true);
      await preferences.setInt(_schemaVersionKey, _currentSchemaVersion);
      return;
    }

    final service = ServiceAccount(
      id: newId('service'),
      userId: userId,
      active: true,
      status: ServiceLifecycleStatus.active,
      iconKey: 'casa',
      objectName: 'casa',
      serviceName: 'ejemplo',
      providerName: 'proveedor',
      serviceNumber: 'ejemplo',
      isAutopay: false,
      initialDueDate: DateTime(2026, 1, 30),
      weekendAdjustment: WeekendAdjustment.none,
      frequency: Frequency.monthly,
      intervalCount: 1,
      estimatedAmount: 900,
      currency: 'MXN',
      version: 1,
    );
    await _writeServices([service]);
    await _writePayments(_generatePaymentsForService(service));
    await preferences.setBool(_seededKey, true);
    await preferences.setInt(_schemaVersionKey, _currentSchemaVersion);
  }

  Future<void> _migrateIfNeeded(SharedPreferences preferences) async {
    final version = preferences.getInt(_schemaVersionKey) ?? 1;
    if (version >= _currentSchemaVersion) return;
    final services = await _readServices();
    final payments = await _readPayments();
    await _writeServices(services);
    await _writePayments(payments);
    await preferences.setInt(_schemaVersionKey, _currentSchemaVersion);
  }

  Future<String> storedDeviceId() async {
    final preferences = await SharedPreferences.getInstance();
    return _ensureDeviceId(preferences);
  }

  Future<int> storedSchemaVersion() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_schemaVersionKey) ?? 1;
  }

  Future<ServiceAccount> _markServiceModified(ServiceAccount service) async {
    final preferences = await SharedPreferences.getInstance();
    return service.copyWith(
      lastModifiedAt: DateTime.now().toUtc(),
      lastModifiedPlatform: _platformName,
      lastModifiedDeviceId: await _ensureDeviceId(preferences),
    );
  }

  Future<PaymentInstance> _markPaymentModified(PaymentInstance payment) async {
    final preferences = await SharedPreferences.getInstance();
    return payment.copyWith(
      lastModifiedAt: DateTime.now().toUtc(),
      lastModifiedPlatform: _platformName,
      lastModifiedDeviceId: await _ensureDeviceId(preferences),
    );
  }

  Future<String> _ensureDeviceId(SharedPreferences preferences) async {
    final existing = preferences.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = newId('device');
    await preferences.setString(_deviceIdKey, id);
    return id;
  }

  Future<void> _appendGeneratedPayments(
    ServiceAccount service, {
    required DateTime effectiveFrom,
  }) async {
    final payments = await _readPayments();
    final existingKeys = payments
        .where(
          (payment) => payment.status != PaymentStatus.cancelledByRecalculation,
        )
        .map(
          (payment) =>
              '${payment.serviceAccountId}:${_isoDate(payment.dueDate)}',
        )
        .toSet();
    final generated = _generatePaymentsForService(service)
        .where((payment) => !payment.dueDate.isBefore(_dateOnly(effectiveFrom)))
        .where((payment) {
          final key =
              '${payment.serviceAccountId}:${_isoDate(payment.dueDate)}';
          return existingKeys.add(key);
        });
    payments.addAll(generated);
    await _writePayments(payments);
  }

  List<PaymentInstance> _generatePaymentsForService(ServiceAccount service) {
    if (!service.active || service.status != ServiceLifecycleStatus.active) {
      return const [];
    }
    final today = _dateOnly(DateTime.now());
    final horizonMonths = AppPreferences.instance.generationHorizonMonths;
    final horizonEnd = _lastDayOfMonth(
      DateTime(today.year, today.month + horizonMonths),
    );
    final recurrenceEnd = service.recurrenceEndDate == null
        ? horizonEnd
        : service.recurrenceEndDate!.isBefore(horizonEnd)
        ? service.recurrenceEndDate!
        : horizonEnd;
    final paymentCount = service.recurrencePaymentCount;
    final payments = <PaymentInstance>[];
    var index = 0;
    var dueDate = _dateOnly(service.initialDueDate);
    while (!dueDate.isAfter(recurrenceEnd) &&
        (paymentCount == null || index < paymentCount) &&
        index < 500) {
      final adjustedDueDate = _adjustWeekend(
        dueDate,
        service.weekendAdjustment,
      );
      final cutoffDate = service.initialCutoffDate == null
          ? null
          : _adjustWeekend(
              _occurrenceDate(service.initialCutoffDate!, service, index),
              service.weekendAdjustment,
            );
      payments.add(
        withCurrentStatus(
          PaymentInstance(
            id: newId('payment'),
            userId: userId,
            serviceAccountId: service.id,
            paymentType: PaymentType.recurring,
            status: service.isAutopay
                ? PaymentStatus.autopayFuture
                : PaymentStatus.future,
            objectName: service.objectName,
            serviceName: service.serviceName,
            providerName: service.providerName,
            serviceNumber: service.serviceNumber,
            serviceIconKey: service.iconKey,
            cutoffDate: cutoffDate,
            dueDate: adjustedDueDate,
            currency: service.currency,
            estimatedAmount: service.estimatedAmount,
            isAutopay: service.isAutopay,
            chargeAccount: service.chargeAccount,
            notes: service.notes,
            generatedBySystem: true,
          ),
        ),
      );
      index++;
      dueDate = _occurrenceDate(service.initialDueDate, service, index);
    }
    return payments;
  }

  DateTime _occurrenceDate(DateTime base, ServiceAccount service, int index) {
    return switch (service.frequency) {
      Frequency.weekly => _dateOnly(
        base.add(Duration(days: 7 * service.intervalCount * index)),
      ),
      Frequency.biweekly => _dateOnly(
        base.add(Duration(days: 14 * service.intervalCount * index)),
      ),
      Frequency.monthly => _addMonths(base, service.intervalCount * index),
      Frequency.yearly => _addMonths(base, 12 * service.intervalCount * index),
    };
  }

  Future<List<ServiceAccount>> _readServices() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_servicesKey);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((item) => ServiceAccount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeServices(List<ServiceAccount> services) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _servicesKey,
      jsonEncode(services.map((service) => service.toJson()).toList()),
    );
  }

  Future<List<PaymentInstance>> _readPayments() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_paymentsKey);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((item) => PaymentInstance.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writePayments(List<PaymentInstance> payments) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _paymentsKey,
      jsonEncode(payments.map((payment) => payment.toJson()).toList()),
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _lastDayOfMonth(DateTime value) =>
    DateTime(value.year, value.month + 1, 0);

DateTime _addMonths(DateTime value, int months) {
  final targetMonth = value.month + months;
  final target = DateTime(value.year, targetMonth);
  final lastDay = _lastDayOfMonth(target).day;
  return DateTime(target.year, target.month, min(value.day, lastDay));
}

DateTime _adjustWeekend(DateTime value, WeekendAdjustment adjustment) {
  return switch (adjustment) {
    WeekendAdjustment.none => value,
    WeekendAdjustment.nextMonday =>
      value.weekday == DateTime.saturday
          ? value.add(const Duration(days: 2))
          : value.weekday == DateTime.sunday
          ? value.add(const Duration(days: 1))
          : value,
    WeekendAdjustment.previousFriday =>
      value.weekday == DateTime.saturday
          ? value.subtract(const Duration(days: 1))
          : value.weekday == DateTime.sunday
          ? value.subtract(const Duration(days: 2))
          : value,
  };
}

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String get _platformName {
  if (kIsWeb) return 'web';
  if (defaultTargetPlatform == TargetPlatform.android) return 'android';
  return 'local';
}
