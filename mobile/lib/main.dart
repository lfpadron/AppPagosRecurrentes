import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/storage/local_app_database.dart';
import 'core/theme/app_theme.dart';
import 'features/calendar/data/calendar_api.dart';
import 'features/payments/data/payments_api.dart';
import 'features/reports/data/reports_api.dart';
import 'features/services/data/services_api.dart';
import 'shared/app_preferences.dart';
import 'shared/app_access_gate.dart';
import 'shared/app_shell.dart';
import 'shared/auth/auth_session_controller.dart';
import 'shared/dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPreferences.instance.load();
  await AuthSessionController.instance.initialize();
  final apiClient = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    userId: AppConfig.userId,
    accessTokenProvider: () async => AuthSessionController.instance.accessToken,
  );
  final localDatabase = LocalAppDatabase(userId: AppConfig.userId);
  final useLocalData =
      AppConfig.forceLocalData ||
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  runApp(
    DependenciesScope(
      dependencies: useLocalData
          ? AppDependencies(
              servicesApi: ServicesApi.local(localDatabase),
              paymentsApi: PaymentsApi.local(localDatabase),
              calendarApi: CalendarApi.local(localDatabase),
              reportsApi: ReportsApi.local(localDatabase),
            )
          : AppDependencies(
              servicesApi: ServicesApi(apiClient),
              paymentsApi: PaymentsApi(apiClient),
              calendarApi: CalendarApi(apiClient),
              reportsApi: ReportsApi(apiClient),
            ),
      child: const PagosApp(),
    ),
  );
}

class PagosApp extends StatelessWidget {
  const PagosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pagos Recurrentes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [
        Locale('es', 'MX'),
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      home: const AppAccessGate(child: AppShell()),
    );
  }
}
