import '../../../core/network/api_client.dart';
import '../../../core/storage/local_app_database.dart';
import '../../../shared/formatters.dart';
import 'service_account.dart';

class ServicesApi {
  const ServicesApi(this._apiClient) : _localDatabase = null;
  const ServicesApi.local(this._localDatabase) : _apiClient = null;

  final ApiClient? _apiClient;
  final LocalAppDatabase? _localDatabase;

  Future<List<ServiceAccount>> listServices({
    String? objectName,
    ServiceLifecycleStatus? status,
    int limit = 30,
    int offset = 0,
  }) async {
    final localDatabase = _localDatabase;
    if (localDatabase != null) {
      return localDatabase.listServices(
        objectName: objectName,
        status: status,
        limit: limit,
        offset: offset,
      );
    }
    final query = {
      'object_name': objectName,
      'status': status?.value,
      'limit': limit,
      'offset': offset,
    };
    final data =
        await _apiClient!.getJsonCached(
              '/services',
              query,
              cacheKey: _cacheKey('services', query),
              fallbackCacheKey: 'services:last',
            )
            as List<dynamic>;
    return data
        .map((item) => ServiceAccount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ServiceAccount>> listAllServices({
    String? objectName,
    ServiceLifecycleStatus? status,
  }) async {
    const pageSize = 500;
    var offset = 0;
    final all = <ServiceAccount>[];
    while (true) {
      final page = await listServices(
        objectName: objectName,
        status: status,
        limit: pageSize,
        offset: offset,
      );
      all.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return all;
  }

  Future<ServiceAccount> createService(ServiceDraft draft) async {
    final localDatabase = _localDatabase;
    if (localDatabase != null) {
      return localDatabase.createService(
        _serviceFromDraft(
          draft,
          id: localDatabase.newId('service'),
          userId: localDatabase.userId,
          version: 1,
        ),
      );
    }
    final data =
        await _apiClient!.postJson('/services', draft.toJson())
            as Map<String, dynamic>;
    return ServiceAccount.fromJson(data);
  }

  Future<ServiceAccount> updateService(
    String id,
    ServiceDraft draft,
    DateTime effectiveFrom,
  ) async {
    final localDatabase = _localDatabase;
    if (localDatabase != null) {
      final current = (await localDatabase.listServices(
        limit: 100000,
      )).firstWhere((service) => service.id == id);
      return localDatabase.updateService(
        _serviceFromDraft(
          draft,
          id: id,
          userId: current.userId,
          version: current.version + 1,
        ),
        effectiveFrom,
      );
    }
    final body = draft.toJson()..['effective_from'] = isoDate(effectiveFrom);
    final data =
        await _apiClient!.patchJson('/services/$id', body)
            as Map<String, dynamic>;
    return ServiceAccount.fromJson(data);
  }
}

ServiceAccount _serviceFromDraft(
  ServiceDraft draft, {
  required String id,
  required String userId,
  required int version,
}) {
  final active = draft.active && draft.status == ServiceLifecycleStatus.active;
  return ServiceAccount(
    id: id,
    userId: userId,
    active: active,
    status: draft.status,
    pausedFrom: draft.pausedFrom,
    endedAt: draft.endedAt,
    endReason: draft.endReason,
    iconKey: draft.iconKey,
    objectName: draft.objectName,
    serviceName: draft.serviceName,
    providerName: draft.providerName,
    serviceNumber: draft.serviceNumber,
    providerUrl: draft.providerUrl,
    isAutopay: draft.isAutopay,
    chargeAccount: draft.chargeAccount,
    initialCutoffDate: draft.initialCutoffDate,
    initialDueDate: draft.initialDueDate,
    weekendAdjustment: draft.weekendAdjustment,
    frequency: draft.frequency,
    intervalCount: draft.intervalCount,
    estimatedAmount: draft.estimatedAmount,
    currency: draft.currency,
    recurrenceEndDate: draft.recurrenceEndDate,
    recurrencePaymentCount: draft.recurrencePaymentCount,
    notes: draft.notes,
    version: version,
  );
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

class ServiceDraft {
  const ServiceDraft({
    required this.objectName,
    required this.serviceName,
    required this.providerName,
    required this.serviceNumber,
    required this.initialDueDate,
    required this.frequency,
    required this.intervalCount,
    required this.isAutopay,
    this.active = true,
    this.status = ServiceLifecycleStatus.active,
    this.iconKey = 'service_default',
    this.pausedFrom,
    this.endedAt,
    this.endReason,
    this.weekendAdjustment = WeekendAdjustment.none,
    this.initialCutoffDate,
    this.estimatedAmount,
    this.recurrenceEndDate,
    this.recurrencePaymentCount,
    this.chargeAccount,
    this.providerUrl,
    this.notes,
    this.currency = 'MXN',
  });

  final bool active;
  final ServiceLifecycleStatus status;
  final DateTime? pausedFrom;
  final DateTime? endedAt;
  final String? endReason;
  final String iconKey;
  final WeekendAdjustment weekendAdjustment;
  final String objectName;
  final String serviceName;
  final String providerName;
  final String serviceNumber;
  final String? providerUrl;
  final bool isAutopay;
  final String? chargeAccount;
  final DateTime? initialCutoffDate;
  final DateTime initialDueDate;
  final Frequency frequency;
  final int intervalCount;
  final double? estimatedAmount;
  final DateTime? recurrenceEndDate;
  final int? recurrencePaymentCount;
  final String currency;
  final String? notes;

  Map<String, Object?> toJson() {
    return {
      'active': active,
      'status': status.value,
      'paused_from': pausedFrom == null ? null : isoDate(pausedFrom!),
      'ended_at': endedAt == null ? null : isoDate(endedAt!),
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
          : isoDate(initialCutoffDate!),
      'initial_due_date': isoDate(initialDueDate),
      'weekend_adjustment': weekendAdjustment.value,
      'frequency': frequency.value,
      'interval_count': intervalCount,
      'estimated_amount': estimatedAmount,
      'recurrence_end_date': recurrenceEndDate == null
          ? null
          : isoDate(recurrenceEndDate!),
      'recurrence_payment_count': recurrencePaymentCount,
      'currency': currency,
      'notes': notes,
    };
  }
}
