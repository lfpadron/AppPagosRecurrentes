enum PaymentStatus {
  future,
  upcoming,
  dueSoon,
  pending,
  active,
  autopayDueSoon,
  autopayFuture,
  autopayPendingConfirmation,
  overdue,
  autopayOverdueConfirmation,
  paid,
  notApplicableException,
  cancelled,
  cancelledByRecalculation,
}

enum PaymentType { recurring, oneTime }

extension PaymentStatusX on PaymentStatus {
  String get value => switch (this) {
    PaymentStatus.future => 'future',
    PaymentStatus.upcoming => 'upcoming',
    PaymentStatus.dueSoon => 'due_soon',
    PaymentStatus.pending => 'pending',
    PaymentStatus.active => 'active',
    PaymentStatus.autopayDueSoon => 'autopay_due_soon',
    PaymentStatus.autopayFuture => 'autopay_future',
    PaymentStatus.autopayPendingConfirmation => 'autopay_pending_confirmation',
    PaymentStatus.overdue => 'overdue',
    PaymentStatus.autopayOverdueConfirmation => 'autopay_overdue_confirmation',
    PaymentStatus.paid => 'paid',
    PaymentStatus.notApplicableException => 'not_applicable_exception',
    PaymentStatus.cancelled => 'cancelled',
    PaymentStatus.cancelledByRecalculation => 'cancelled_by_recalculation',
  };

  String get label => switch (this) {
    PaymentStatus.future => 'Manual: futuro',
    PaymentStatus.upcoming => 'Manual: proximo',
    PaymentStatus.dueSoon => 'Manual: atencion',
    PaymentStatus.pending => 'Pendiente',
    PaymentStatus.active => 'Activo',
    PaymentStatus.autopayDueSoon => 'Automatico: pronto pago',
    PaymentStatus.autopayFuture => 'Automatico: futuro',
    PaymentStatus.autopayPendingConfirmation => 'Automatico: por confirmar',
    PaymentStatus.overdue => 'Manual: vencido',
    PaymentStatus.autopayOverdueConfirmation => 'Automatico: por confirmar',
    PaymentStatus.paid => 'Pagado',
    PaymentStatus.notApplicableException => 'Excepcion',
    PaymentStatus.cancelled => 'Cancelado',
    PaymentStatus.cancelledByRecalculation => 'Recalculado',
  };
}

const quickPaymentStatuses = [
  PaymentStatus.overdue,
  PaymentStatus.dueSoon,
  PaymentStatus.upcoming,
  PaymentStatus.future,
  PaymentStatus.paid,
  PaymentStatus.autopayPendingConfirmation,
  PaymentStatus.autopayDueSoon,
  PaymentStatus.autopayFuture,
];

extension PaymentTypeX on PaymentType {
  String get value => switch (this) {
    PaymentType.recurring => 'recurring',
    PaymentType.oneTime => 'one_time',
  };
}

PaymentStatus parsePaymentStatus(String value) {
  return PaymentStatus.values.firstWhere((status) => status.value == value);
}

PaymentType parsePaymentType(String value) {
  return PaymentType.values.firstWhere((type) => type.value == value);
}

class PaymentInstance {
  const PaymentInstance({
    required this.id,
    required this.userId,
    required this.paymentType,
    required this.status,
    required this.objectName,
    required this.serviceName,
    required this.providerName,
    required this.serviceNumber,
    required this.serviceIconKey,
    required this.dueDate,
    required this.isAutopay,
    required this.generatedBySystem,
    this.currency = 'MXN',
    this.serviceAccountId,
    this.cutoffDate,
    this.estimatedAmount,
    this.paidAmount,
    this.paidAt,
    this.chargeAccount,
    this.paymentMethod,
    this.receiptFileId,
    this.notes,
    this.lastModifiedAt,
    this.lastModifiedPlatform,
    this.lastModifiedDeviceId,
  });

  final String id;
  final String userId;
  final String? serviceAccountId;
  final PaymentType paymentType;
  final PaymentStatus status;
  final String objectName;
  final String serviceName;
  final String providerName;
  final String serviceNumber;
  final String serviceIconKey;
  final DateTime? cutoffDate;
  final DateTime dueDate;
  final String currency;
  final double? estimatedAmount;
  final double? paidAmount;
  final DateTime? paidAt;
  final bool isAutopay;
  final String? chargeAccount;
  final String? paymentMethod;
  final String? receiptFileId;
  final String? notes;
  final bool generatedBySystem;
  final DateTime? lastModifiedAt;
  final String? lastModifiedPlatform;
  final String? lastModifiedDeviceId;

  factory PaymentInstance.fromJson(Map<String, dynamic> json) {
    return PaymentInstance(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      serviceAccountId: json['service_account_id'] as String?,
      paymentType: parsePaymentType(json['payment_type'] as String),
      status: parsePaymentStatus(json['status'] as String),
      objectName: json['object_name_snapshot'] as String,
      serviceName: json['service_name_snapshot'] as String,
      providerName: json['provider_name_snapshot'] as String,
      serviceNumber: json['service_number_snapshot'] as String,
      serviceIconKey:
          json['service_icon_key_snapshot'] as String? ?? 'service_default',
      cutoffDate: _dateOrNull(json['cutoff_date']),
      dueDate: DateTime.parse(json['due_date'] as String),
      currency: json['currency'] as String? ?? 'MXN',
      estimatedAmount: _doubleOrNull(json['estimated_amount']),
      paidAmount: _doubleOrNull(json['paid_amount']),
      paidAt: _dateOrNull(json['paid_at']),
      isAutopay: json['is_autopay_snapshot'] as bool,
      chargeAccount: json['charge_account_snapshot'] as String?,
      paymentMethod: json['payment_method'] as String?,
      receiptFileId: json['receipt_file_id'] as String?,
      notes: json['notes'] as String?,
      generatedBySystem: json['generated_by_system'] as bool,
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
      'service_account_id': serviceAccountId,
      'payment_type': paymentType.value,
      'status': status.value,
      'object_name_snapshot': objectName,
      'service_name_snapshot': serviceName,
      'provider_name_snapshot': providerName,
      'service_number_snapshot': serviceNumber,
      'service_icon_key_snapshot': serviceIconKey,
      'cutoff_date': cutoffDate == null ? null : _isoDate(cutoffDate!),
      'due_date': _isoDate(dueDate),
      'currency': currency,
      'estimated_amount': estimatedAmount,
      'paid_amount': paidAmount,
      'paid_at': paidAt == null ? null : _isoDate(paidAt!),
      'is_autopay_snapshot': isAutopay,
      'charge_account_snapshot': chargeAccount,
      'payment_method': paymentMethod,
      'receipt_file_id': receiptFileId,
      'notes': notes,
      'generated_by_system': generatedBySystem,
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_platform': lastModifiedPlatform,
      'last_modified_device_id': lastModifiedDeviceId,
    };
  }

  PaymentInstance copyWith({
    PaymentStatus? status,
    double? paidAmount,
    DateTime? paidAt,
    String? paymentMethod,
    String? receiptFileId,
    String? notes,
    DateTime? lastModifiedAt,
    String? lastModifiedPlatform,
    String? lastModifiedDeviceId,
    bool clearPaid = false,
  }) {
    return PaymentInstance(
      id: id,
      userId: userId,
      serviceAccountId: serviceAccountId,
      paymentType: paymentType,
      status: status ?? this.status,
      objectName: objectName,
      serviceName: serviceName,
      providerName: providerName,
      serviceNumber: serviceNumber,
      serviceIconKey: serviceIconKey,
      cutoffDate: cutoffDate,
      dueDate: dueDate,
      currency: currency,
      estimatedAmount: estimatedAmount,
      paidAmount: clearPaid ? null : paidAmount ?? this.paidAmount,
      paidAt: clearPaid ? null : paidAt ?? this.paidAt,
      isAutopay: isAutopay,
      chargeAccount: chargeAccount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptFileId: receiptFileId ?? this.receiptFileId,
      notes: notes ?? this.notes,
      generatedBySystem: generatedBySystem,
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
