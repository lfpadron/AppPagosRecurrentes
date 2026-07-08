import '../../../core/network/api_client.dart';
import '../../../core/storage/local_app_database.dart';
import '../../../shared/auth/auth_session_controller.dart';

class SyncApi {
  const SyncApi({
    required ApiClient apiClient,
    required LocalAppDatabase localDatabase,
  }) : _apiClient = apiClient,
       _localDatabase = localDatabase;

  final ApiClient _apiClient;
  final LocalAppDatabase _localDatabase;

  Future<SyncStatus> status() async {
    final data = await _apiClient.getJson('/sync/status') as Map<String, dynamic>;
    return SyncStatus.fromJson(data);
  }

  Future<SyncBootstrapResult> bootstrapLocal() async {
    final snapshot = await _localDatabase.exportSyncSnapshot();
    final data =
        await _apiClient.postJson('/sync/bootstrap', {
              'device_id': snapshot.deviceId,
              'platform': 'android',
              'app_schema_version': snapshot.schemaVersion,
              'services': snapshot.services,
              'payments': snapshot.payments,
            })
            as Map<String, dynamic>;
    final result = SyncBootstrapResult.fromJson(data);
    await _localDatabase.applyServerIdMappings(
      serviceIdMap: result.serviceIdMap,
      paymentIdMap: result.paymentIdMap,
      serverUserId: AuthSessionController.instance.profile?.id,
    );
    return result;
  }
}

class SyncStatus {
  const SyncStatus({
    required this.userId,
    required this.isPremium,
    required this.serverTime,
    required this.serviceCount,
    required this.paymentCount,
    required this.deviceCount,
  });

  final String userId;
  final bool isPremium;
  final DateTime serverTime;
  final int serviceCount;
  final int paymentCount;
  final int deviceCount;

  factory SyncStatus.fromJson(Map<String, dynamic> json) {
    return SyncStatus(
      userId: json['user_id'].toString(),
      isPremium: json['is_premium'] == true,
      serverTime: DateTime.parse(json['server_time'] as String),
      serviceCount: json['service_count'] as int,
      paymentCount: json['payment_count'] as int,
      deviceCount: json['device_count'] as int,
    );
  }
}

class SyncBootstrapResult {
  const SyncBootstrapResult({
    required this.importedServices,
    required this.updatedServices,
    required this.importedPayments,
    required this.updatedPayments,
    required this.skippedPayments,
    required this.conflictCount,
    required this.serviceIdMap,
    required this.paymentIdMap,
  });

  final int importedServices;
  final int updatedServices;
  final int importedPayments;
  final int updatedPayments;
  final int skippedPayments;
  final int conflictCount;
  final Map<String, String> serviceIdMap;
  final Map<String, String> paymentIdMap;

  factory SyncBootstrapResult.fromJson(Map<String, dynamic> json) {
    return SyncBootstrapResult(
      importedServices: json['imported_services'] as int,
      updatedServices: json['updated_services'] as int,
      importedPayments: json['imported_payments'] as int,
      updatedPayments: json['updated_payments'] as int,
      skippedPayments: json['skipped_payments'] as int,
      conflictCount: (json['conflicts'] as List<dynamic>).length,
      serviceIdMap: _stringMap(json['service_id_map']),
      paymentIdMap: _stringMap(json['payment_id_map']),
    );
  }
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map<String, dynamic>) return const {};
  return value.map((key, item) => MapEntry(key, item.toString()));
}
