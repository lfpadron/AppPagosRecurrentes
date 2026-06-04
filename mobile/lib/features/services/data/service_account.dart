enum Frequency { weekly, biweekly, monthly, yearly }

enum ServiceLifecycleStatus { active, paused, ended }

enum WeekendAdjustment { none, nextMonday, previousFriday }

extension WeekendAdjustmentX on WeekendAdjustment {
  String get value => switch (this) {
    WeekendAdjustment.none => 'none',
    WeekendAdjustment.nextMonday => 'next_monday',
    WeekendAdjustment.previousFriday => 'previous_friday',
  };

  String get label => switch (this) {
    WeekendAdjustment.none => 'No hacer nada',
    WeekendAdjustment.nextMonday => 'Mover al lunes siguiente',
    WeekendAdjustment.previousFriday => 'Mover al viernes anterior',
  };
}

extension ServiceLifecycleStatusX on ServiceLifecycleStatus {
  String get value => switch (this) {
    ServiceLifecycleStatus.active => 'active',
    ServiceLifecycleStatus.paused => 'paused',
    ServiceLifecycleStatus.ended => 'ended',
  };

  String get label => switch (this) {
    ServiceLifecycleStatus.active => 'Activo',
    ServiceLifecycleStatus.paused => 'Pausado',
    ServiceLifecycleStatus.ended => 'Terminado',
  };
}

extension FrequencyX on Frequency {
  String get value => switch (this) {
    Frequency.weekly => 'weekly',
    Frequency.biweekly => 'biweekly',
    Frequency.monthly => 'monthly',
    Frequency.yearly => 'yearly',
  };

  String get label => switch (this) {
    Frequency.weekly => 'Semanal',
    Frequency.biweekly => 'Quincenal',
    Frequency.monthly => 'Mensual',
    Frequency.yearly => 'Anual',
  };
}

Frequency parseFrequency(String value) {
  return Frequency.values.firstWhere((frequency) => frequency.value == value);
}

ServiceLifecycleStatus parseServiceLifecycleStatus(String value) {
  return ServiceLifecycleStatus.values.firstWhere(
    (status) => status.value == value,
  );
}

WeekendAdjustment parseWeekendAdjustment(String value) {
  return WeekendAdjustment.values.firstWhere(
    (policy) => policy.value == value,
    orElse: () => WeekendAdjustment.none,
  );
}

class ServiceAccount {
  const ServiceAccount({
    required this.id,
    required this.userId,
    required this.active,
    required this.status,
    required this.iconKey,
    required this.objectName,
    required this.serviceName,
    required this.providerName,
    required this.serviceNumber,
    required this.isAutopay,
    required this.initialDueDate,
    required this.weekendAdjustment,
    required this.frequency,
    required this.intervalCount,
    required this.currency,
    required this.version,
    this.lastModifiedAt,
    this.lastModifiedPlatform,
    this.lastModifiedDeviceId,
    this.recurrenceEndDate,
    this.recurrencePaymentCount,
    this.providerUrl,
    this.pausedFrom,
    this.endedAt,
    this.endReason,
    this.chargeAccount,
    this.initialCutoffDate,
    this.estimatedAmount,
    this.notes,
  });

  final String id;
  final String userId;
  final bool active;
  final ServiceLifecycleStatus status;
  final DateTime? pausedFrom;
  final DateTime? endedAt;
  final String? endReason;
  final String iconKey;
  final String objectName;
  final String serviceName;
  final String providerName;
  final String serviceNumber;
  final String? providerUrl;
  final bool isAutopay;
  final String? chargeAccount;
  final DateTime? initialCutoffDate;
  final DateTime initialDueDate;
  final WeekendAdjustment weekendAdjustment;
  final Frequency frequency;
  final int intervalCount;
  final double? estimatedAmount;
  final String currency;
  final DateTime? recurrenceEndDate;
  final int? recurrencePaymentCount;
  final String? notes;
  final int version;
  final DateTime? lastModifiedAt;
  final String? lastModifiedPlatform;
  final String? lastModifiedDeviceId;

  factory ServiceAccount.fromJson(Map<String, dynamic> json) {
    return ServiceAccount(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      active: json['active'] as bool,
      status: parseServiceLifecycleStatus(
        json['status'] as String? ?? 'active',
      ),
      pausedFrom: _dateOrNull(json['paused_from']),
      endedAt: _dateOrNull(json['ended_at']),
      endReason: json['end_reason'] as String?,
      iconKey: json['icon_key'] as String? ?? 'service_default',
      objectName: json['object_name'] as String,
      serviceName: json['service_name'] as String,
      providerName: json['provider_name'] as String,
      serviceNumber: json['service_number'] as String,
      providerUrl: json['provider_url'] as String?,
      isAutopay: json['is_autopay'] as bool,
      chargeAccount: json['charge_account'] as String?,
      initialCutoffDate: _dateOrNull(json['initial_cutoff_date']),
      initialDueDate: DateTime.parse(json['initial_due_date'] as String),
      weekendAdjustment: parseWeekendAdjustment(
        json['weekend_adjustment'] as String? ?? 'none',
      ),
      frequency: parseFrequency(json['frequency'] as String),
      intervalCount: json['interval_count'] as int,
      estimatedAmount: _doubleOrNull(json['estimated_amount']),
      currency: json['currency'] as String,
      recurrenceEndDate: _dateOrNull(json['recurrence_end_date']),
      recurrencePaymentCount: json['recurrence_payment_count'] as int?,
      notes: json['notes'] as String?,
      version: json['version'] as int,
      lastModifiedAt: _dateTimeOrNull(
        json['last_modified_at'] ?? json['updated_at'],
      ),
      lastModifiedPlatform: json['last_modified_platform'] as String?,
      lastModifiedDeviceId: json['last_modified_device_id'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'active': active,
      'status': status.value,
      'paused_from': pausedFrom == null ? null : _isoDate(pausedFrom!),
      'ended_at': endedAt == null ? null : _isoDate(endedAt!),
      'end_reason': endReason,
      'icon_key': iconKey,
      'object_name': objectName,
      'service_name': serviceName,
      'provider_name': providerName,
      'service_number': serviceNumber,
      'provider_url': providerUrl,
      'is_autopay': isAutopay,
      'charge_account': chargeAccount,
      'initial_cutoff_date': initialCutoffDate == null
          ? null
          : _isoDate(initialCutoffDate!),
      'initial_due_date': _isoDate(initialDueDate),
      'weekend_adjustment': weekendAdjustment.value,
      'frequency': frequency.value,
      'interval_count': intervalCount,
      'estimated_amount': estimatedAmount,
      'currency': currency,
      'recurrence_end_date': recurrenceEndDate == null
          ? null
          : _isoDate(recurrenceEndDate!),
      'recurrence_payment_count': recurrencePaymentCount,
      'notes': notes,
      'version': version,
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_platform': lastModifiedPlatform,
      'last_modified_device_id': lastModifiedDeviceId,
    };
  }

  ServiceAccount copyWith({
    int? version,
    DateTime? lastModifiedAt,
    String? lastModifiedPlatform,
    String? lastModifiedDeviceId,
  }) {
    return ServiceAccount(
      id: id,
      userId: userId,
      active: active,
      status: status,
      pausedFrom: pausedFrom,
      endedAt: endedAt,
      endReason: endReason,
      iconKey: iconKey,
      objectName: objectName,
      serviceName: serviceName,
      providerName: providerName,
      serviceNumber: serviceNumber,
      providerUrl: providerUrl,
      isAutopay: isAutopay,
      chargeAccount: chargeAccount,
      initialCutoffDate: initialCutoffDate,
      initialDueDate: initialDueDate,
      weekendAdjustment: weekendAdjustment,
      frequency: frequency,
      intervalCount: intervalCount,
      estimatedAmount: estimatedAmount,
      currency: currency,
      recurrenceEndDate: recurrenceEndDate,
      recurrencePaymentCount: recurrencePaymentCount,
      notes: notes,
      version: version ?? this.version,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedPlatform: lastModifiedPlatform ?? this.lastModifiedPlatform,
      lastModifiedDeviceId: lastModifiedDeviceId ?? this.lastModifiedDeviceId,
    );
  }
}

DateTime? _dateOrNull(Object? value) =>
    value is String ? DateTime.parse(value) : null;

DateTime? _dateTimeOrNull(Object? value) =>
    value is String ? DateTime.parse(value) : null;

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

double? _doubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.parse(value.toString());
}
