import 'package:flutter_test/flutter_test.dart';
import 'package:pagos_recurrentes_mobile/shared/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('generation horizon remains in shared app preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = AppPreferences.instance;
    await prefs.load();

    prefs.setGenerationHorizonMonths(18);
    prefs.setDefaultCurrency('USD');

    expect(AppPreferences.instance.generationHorizonMonths, 18);
    expect(AppPreferences.instance.defaultCurrency, 'USD');

    prefs.setGenerationHorizonMonths(36);
    prefs.setDefaultCurrency('MXN');
  });

  test('local profile plan and pin preferences are persisted safely', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = AppPreferences.instance;
    await prefs.load();

    await prefs.setLocalUser(name: 'Luis', email: 'LUIS@example.com');
    prefs.setSubscriptionPlanForLocalTesting(SubscriptionPlan.premium);
    final savedPin = await prefs.setPin('1234');

    expect(savedPin, isTrue);
    expect(prefs.localUserName, 'Luis');
    expect(prefs.localUserEmail, 'luis@example.com');
    expect(prefs.isPremium, isTrue);
    expect(prefs.syncEnabled, isTrue);
    expect(prefs.hasPin, isTrue);
    expect(prefs.verifyPin('0000'), isFalse);
    expect(prefs.verifyPin('1234'), isTrue);

    await prefs.clearPin();
    prefs.setSubscriptionPlanForLocalTesting(SubscriptionPlan.economic);
  });
}
