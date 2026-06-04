import '../features/services/data/service_account.dart';

List<String> serviceCurrencyOptions(Iterable<ServiceAccount> services) {
  final currencies =
      services
          .map((service) => service.currency.trim().toUpperCase())
          .where((currency) => currency.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return currencies;
}
