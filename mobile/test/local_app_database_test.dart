import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pagos_recurrentes_mobile/core/storage/local_app_database.dart';
import 'package:pagos_recurrentes_mobile/features/payments/data/payment_instance.dart';
import 'package:pagos_recurrentes_mobile/features/payments/data/payments_api.dart';
import 'package:pagos_recurrentes_mobile/features/services/data/services_api.dart';

void main() {
  test(
    'local Android data source seeds, lists and mutates without server',
    () async {
      SharedPreferences.setMockInitialValues({});
      final database = LocalAppDatabase(userId: 'local-user');
      final servicesApi = ServicesApi.local(database);
      final paymentsApi = PaymentsApi.local(database);

      final services = await servicesApi.listServices(limit: 30);
      final payments = await paymentsApi.listPayments(limit: 90);

      expect(services, isNotEmpty);
      expect(services.first.objectName, 'casa');
      expect(services.first.serviceName, 'ejemplo');
      expect(
        await database.storedSchemaVersion(),
        LocalAppDatabase.currentSchemaVersion,
      );
      expect(await database.storedDeviceId(), startsWith('device-'));
      expect(payments, isNotEmpty);

      final paid = await paymentsApi.markPaid(
        payments.first.id,
        paidAmount: payments.first.estimatedAmount,
        paidAt: DateTime(2026, 5, 18),
      );

      expect(paid.status, PaymentStatus.paid);
      expect(paid.paidAt, DateTime(2026, 5, 18));
      expect(paid.lastModifiedAt, isNotNull);
      expect(paid.lastModifiedPlatform, isNotEmpty);
      expect(paid.lastModifiedDeviceId, startsWith('device-'));
    },
  );

  test('local sync id mappings preserve payment service references', () async {
    SharedPreferences.setMockInitialValues({});
    final database = LocalAppDatabase(userId: 'local-user');
    final servicesApi = ServicesApi.local(database);
    final paymentsApi = PaymentsApi.local(database);

    final service = (await servicesApi.listServices(limit: 1)).first;
    final payment = (await paymentsApi.listPayments(limit: 1)).first;

    await database.applyServerIdMappings(
      serviceIdMap: {service.id: '11111111-1111-4111-8111-111111111111'},
      paymentIdMap: {payment.id: '22222222-2222-4222-8222-222222222222'},
      serverUserId: '33333333-3333-4333-8333-333333333333',
    );

    final remappedService = (await servicesApi.listServices(limit: 1)).first;
    final remappedPayment = (await paymentsApi.listPayments(limit: 1)).first;

    expect(remappedService.id, '11111111-1111-4111-8111-111111111111');
    expect(remappedPayment.id, '22222222-2222-4222-8222-222222222222');
    expect(
      remappedPayment.serviceAccountId,
      '11111111-1111-4111-8111-111111111111',
    );
    expect(remappedService.userId, '33333333-3333-4333-8333-333333333333');
    expect(remappedPayment.userId, '33333333-3333-4333-8333-333333333333');
    expect(await database.storedLastBootstrapAt(), isNotNull);
  });

  test('server snapshot updates local records when server is newer', () async {
    SharedPreferences.setMockInitialValues({});
    final database = LocalAppDatabase(userId: 'local-user');
    final servicesApi = ServicesApi.local(database);
    final paymentsApi = PaymentsApi.local(database);

    final service = (await servicesApi.listServices(limit: 1)).first;
    final payment = (await paymentsApi.listPayments(limit: 1)).first;
    await database.applyServerIdMappings(
      serviceIdMap: const {},
      paymentIdMap: const {},
    );

    final remoteModifiedAt = DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 1))
        .toIso8601String();
    final remoteService = Map<String, dynamic>.from(service.toJson())
      ..['provider_name'] = 'proveedor web'
      ..['last_modified_at'] = remoteModifiedAt
      ..['last_modified_platform'] = 'server';
    final remotePayment = Map<String, dynamic>.from(payment.toJson())
      ..['status'] = 'paid'
      ..['paid_amount'] = 900.0
      ..['paid_at'] = '2026-02-28'
      ..['last_modified_at'] = remoteModifiedAt
      ..['last_modified_platform'] = 'server';

    final result = await database.applyServerSnapshot(
      services: [remoteService],
      payments: [remotePayment],
    );

    final updatedService = (await servicesApi.listServices(limit: 1)).first;
    final updatedPayment = await database.getPayment(payment.id);

    expect(result.updatedServices, 1);
    expect(result.updatedPayments, 1);
    expect(result.conflictCount, 0);
    expect(updatedService.providerName, 'proveedor web');
    expect(updatedPayment.status, PaymentStatus.paid);
    expect(updatedPayment.paidAt, DateTime(2026, 2, 28));
    expect(await database.storedLastPullAt(), isNotNull);
    expect(await database.storedLastSyncAt(), isNotNull);
  });

  test('server snapshot keeps local records when local is newer', () async {
    SharedPreferences.setMockInitialValues({});
    final database = LocalAppDatabase(userId: 'local-user');
    final paymentsApi = PaymentsApi.local(database);

    final payment = (await paymentsApi.listPayments(limit: 1)).first;
    await database.applyServerIdMappings(
      serviceIdMap: const {},
      paymentIdMap: const {},
    );
    final olderRemotePayment = Map<String, dynamic>.from(payment.toJson())
      ..['status'] = 'future'
      ..['last_modified_at'] = DateTime(2026, 1, 1).toUtc().toIso8601String()
      ..['last_modified_platform'] = 'server';

    final paid = await paymentsApi.markPaid(
      payment.id,
      paidAmount: 123,
      paidAt: DateTime(2026, 3, 1),
    );
    final result = await database.applyServerSnapshot(
      services: const [],
      payments: [olderRemotePayment],
    );
    final afterPull = await database.getPayment(payment.id);

    expect(paid.status, PaymentStatus.paid);
    expect(result.updatedPayments, 0);
    expect(result.keptLocalPayments, 1);
    expect(afterPull.status, PaymentStatus.paid);
    expect(afterPull.paidAmount, 123);
  });
}
