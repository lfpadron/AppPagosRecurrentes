import 'package:intl/intl.dart';

final _moneyFormat = NumberFormat.currency(locale: 'es_MX', symbol: r'$');
final _dateFormat = DateFormat('yyyy-MM-dd');
final _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
final _shortDateFormat = DateFormat('dd MMM', 'es_MX');

String formatMoney(num? value) => _moneyFormat.format(value ?? 0);

String formatAmount(num? value) => (value ?? 0).toStringAsFixed(2);

String formatMoneyWithCurrency(num? value, String currency) =>
    '${formatMoney(value)} $currency';

String formatDate(DateTime? value) =>
    value == null ? '-' : _dateFormat.format(value);

String formatDateTime(DateTime? value) =>
    value == null ? '-' : _dateTimeFormat.format(value.toLocal());

String formatShortDate(DateTime value) => _shortDateFormat.format(value);

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String isoDate(DateTime value) => _dateFormat.format(value);
