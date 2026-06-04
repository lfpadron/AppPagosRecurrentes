import '../../../core/network/api_client.dart';
import '../../../core/storage/local_app_database.dart';
import '../../../shared/formatters.dart';
import 'payment_instance.dart';

class PaymentsApi {
  const PaymentsApi(this._apiClient) : _localDatabase = null;
  const PaymentsApi.local(this._localDatabase) : _apiClient = null;

  final ApiClient? _apiClient;
  final LocalAppDatabase? _localDatabase;

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
    final localDatabase = _localDatabase;
    if (localDatabase != null) {
      return localDatabase.listPayments(
        startDate: startDate,
        endDate: endDate,
        status: status,
        paymentType: paymentType,
        serviceAccountId: serviceAccountId,
        objectName: objectName,
        serviceName: serviceName,
        providerName: providerName,
        currency: currency,
        isAutopay: isAutopay,
        includeCancelled: includeCancelled,
        limit: limit,
        offset: offset,
      );
    }
    final query = {
      'start_date': startDate == null ? null : isoDate(startDate),
      'end_date': endDate == null ? null : isoDate(endDate),
      'status': status?.value,
      'payment_type': paymentType?.value,
      'service_account_id': serviceAccountId,
      'object_name': objectName,
      'service_name': serviceName,
      'provider_name': providerName,
      'currency': currency,
      'is_autopay': isAutopay,
      'include_cancelled': includeCancelled,
      'limit': limit,
      'offset': offset,
    };
    final data =
        await _apiClient!.getJsonCached(
              '/payments',
              query,
              cacheKey: _cacheKey('payments', query),
              fallbackCacheKey: 'payments:last',
            )
            as List<dynamic>;
    return data
        .map((item) => PaymentInstance.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<PaymentInstance> createOneTime(OneTimePaymentDraft draft) async {
    final localDatabase = _localDatabase;
    if (localDatabase != null) {
      return localDatabase.createPayment(
        PaymentInstance(
          id: localDatabase.newId('payment'),
          userId: localDatabase.userId,
          serviceAccountId: draft.serviceAccountId,
          paymentType: PaymentType.oneTime,
          status: PaymentStatus.future,
          objectName: draft.objectName,
          serviceName: draft.serviceName,
          providerName: draft.providerName,
          serviceNumber: draft.serviceNumber ?? '',
          serviceIconKey: draft.iconKey,
          cutoffDate: draft.cutoffDate,
          dueDate: draft.dueDate,
          currency: draft.currency,
          estimatedAmount: draft.estimatedAmount,
          isAutopay: false,
          notes: draft.notes,
          generatedBySystem: false,
        ),
      );
    }
    final data =
        await _apiClient!.postJson('/payments/one-time', draft.toJson())
            as Map<String, dynamic>;
    return PaymentInstance.fromJson(data);
  }

  Future<PaymentInstance> markPaid(
    String id, {
    double? paidAmount,
    DateTime? paidAt,
    String? paymentMethod,
  }) async {
    final localDatabase = _localDatabase;
    if (localDatabase != null) {
      final payment = await localDatabase.getPayment(id);
      return localDatabase.updatePayment(
        payment.copyWith(
          status: PaymentStatus.paid,
          paidAmount: paidAmount ?? payment.estimatedAmount,
          paidAt: paidAt ?? DateTime.now(),
          paymentMethod: paymentMethod,
        ),
      );
    }
    final data =
        await _apiClient!.postJson('/payments/$id/mark-paid', {
              'paid_amount': paidAmount,
              'paid_at': paidAt == null ? null : isoDate(paidAt),
              'payment_method': paymentMethod,
            })
            as Map<String, dynamic>;
    return PaymentInstance.fromJson(data);
  }

  Future<PaymentInstance> cancel(String id, {String? reason}) async {
    final localDatabase = _localDatabase;
    if (localDatabase != null) {
      final payment = await localDatabase.getPayment(id);
      return localDatabase.updatePayment(
        payment.copyWith(
          status: PaymentStatus.cancelled,
          notes: reason == null || reason.trim().isEmpty
              ? payment.notes
              : reason.trim(),
        ),
      );
    }
    final data =
        await _apiClient!.postJson('/payments/$id/cancel', {'reason': reason})
            as Map<String, dynamic>;
    return PaymentInstance.fromJson(data);
  }

  Future<PaymentInstance> unmarkPaid(String id) async {
    final localDatabase = _localDatabase;
    if (localDatabase != null) {
      final payment = await localDatabase.getPayment(id);
      return localDatabase.updatePayment(
        localDatabase.withCurrentStatus(payment.copyWith(clearPaid: true)),
      );
    }
    final data =
        await _apiClient!.postJson('/payments/$id/unmark-paid', {})
            as Map<String, dynamic>;
    return PaymentInstance.fromJson(data);
  }
}

String _cacheKey(String prefix, Map<String, Object?> query) {
  final entries =
      query.entries
          .where((entry) => entry.value != null)
          .map((entry) => '${entry.key}=${entry.value}')
          .toList()
        ..sort();
  return '$prefix:${entries.join('&')}';
}

class OneTimePaymentDraft {
  const OneTimePaymentDraft({
    required this.objectName,
    required this.serviceName,
    required this.providerName,
    required this.dueDate,
    this.serviceAccountId,
    this.iconKey = 'service_default',
    String? currency,
    this.serviceNumber,
    this.cutoffDate,
    this.estimatedAmount,
    this.notes,
  }) : currency = currency ?? 'MXN';

  final String? serviceAccountId;
  final String iconKey;
  final String currency;
  final String objectName;
  final String serviceName;
  final String providerName;
  final String? serviceNumber;
  final DateTime? cutoffDate;
  final DateTime dueDate;
  final double? estimatedAmount;
  final String? notes;

  Map<String, Object?> toJson() {
    return {
      'service_account_id': serviceAccountId,
      'icon_key': iconKey,
      'object_name': objectName,
      'service_name': serviceName,
      'provider_name': providerName,
      'service_number': serviceNumber,
      'cutoff_date': cutoffDate == null ? null : isoDate(cutoffDate!),
      'due_date': isoDate(dueDate),
      'currency': currency,
      'estimated_amount': estimatedAmount,
      'notes': notes,
    };
  }
}
