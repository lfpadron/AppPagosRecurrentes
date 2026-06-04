import 'package:flutter/widgets.dart';

import '../features/calendar/data/calendar_api.dart';
import '../features/payments/data/payments_api.dart';
import '../features/reports/data/reports_api.dart';
import '../features/services/data/services_api.dart';

class AppDependencies {
  const AppDependencies({
    required this.servicesApi,
    required this.paymentsApi,
    required this.calendarApi,
    required this.reportsApi,
  });

  final ServicesApi servicesApi;
  final PaymentsApi paymentsApi;
  final CalendarApi calendarApi;
  final ReportsApi reportsApi;
}

class DependenciesScope extends InheritedWidget {
  const DependenciesScope({
    required this.dependencies,
    required super.child,
    super.key,
  });

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<DependenciesScope>();
    assert(scope != null, 'DependenciesScope not found');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(DependenciesScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}
