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
}
