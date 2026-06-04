import 'package:flutter_test/flutter_test.dart';
import 'package:pagos_recurrentes_mobile/features/services/data/service_account.dart';
import 'package:pagos_recurrentes_mobile/shared/service_currency_options.dart';

void main() {
  test('service currency options are unique normalized and sorted', () {
    final services = [
      _service(id: '1', currency: 'mxn'),
      _service(id: '2', currency: 'USD'),
      _service(id: '3', currency: ' mxn '),
      _service(id: '4', currency: 'eur'),
    ];

    expect(serviceCurrencyOptions(services), ['EUR', 'MXN', 'USD']);
  });
}

ServiceAccount _service({required String id, required String currency}) {
  return ServiceAccount(
    id: id,
    userId: 'user-1',
    active: true,
    status: ServiceLifecycleStatus.active,
    iconKey: 'service_default',
    objectName: 'Casa',
    serviceName: 'Servicio $id',
    providerName: 'Proveedor',
    serviceNumber: id,
    isAutopay: false,
    initialDueDate: DateTime(2026, 1, 30),
    weekendAdjustment: WeekendAdjustment.none,
    frequency: Frequency.monthly,
    intervalCount: 1,
    currency: currency,
    version: 1,
  );
}
