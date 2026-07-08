import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagos_recurrentes_mobile/core/network/api_client.dart';
import 'package:pagos_recurrentes_mobile/core/storage/local_app_database.dart';
import 'package:pagos_recurrentes_mobile/features/calendar/data/calendar_api.dart';
import 'package:pagos_recurrentes_mobile/features/payments/data/payments_api.dart';
import 'package:pagos_recurrentes_mobile/features/settings/presentation/settings_page.dart';
import 'package:pagos_recurrentes_mobile/features/reports/data/reports_api.dart';
import 'package:pagos_recurrentes_mobile/features/services/data/services_api.dart';
import 'package:pagos_recurrentes_mobile/features/sync/data/sync_api.dart';
import 'package:pagos_recurrentes_mobile/shared/dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('settings page smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    const userId = '00000000-0000-0000-0000-000000000001';
    final localDatabase = LocalAppDatabase(userId: userId);
    final apiClient = ApiClient(baseUrl: 'http://localhost:8000', userId: userId);
    await tester.pumpWidget(
      MaterialApp(
        home: DependenciesScope(
          dependencies: AppDependencies(
            servicesApi: ServicesApi.local(localDatabase),
            paymentsApi: PaymentsApi.local(localDatabase),
            calendarApi: CalendarApi.local(localDatabase),
            reportsApi: ReportsApi.local(localDatabase),
            syncApi: SyncApi(apiClient: apiClient, localDatabase: localDatabase),
          ),
          child: const SettingsPage(),
        ),
      ),
    );

    expect(find.text('Configuracion'), findsOneWidget);
    expect(find.text('Preferencias'), findsOneWidget);
    expect(find.text('Usuario local'), findsOneWidget);
  });
}
