import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagos_recurrentes_mobile/features/settings/presentation/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('settings page smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

    expect(find.text('Configuracion'), findsOneWidget);
    expect(find.text('Preferencias'), findsOneWidget);
    expect(find.text('Usuario local'), findsOneWidget);
  });
}
