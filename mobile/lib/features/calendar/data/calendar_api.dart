import '../../../core/network/api_client.dart';
import '../../../core/storage/local_app_database.dart';
import '../../../shared/formatters.dart';
import '../../payments/data/payment_instance.dart';

class CalendarApi {
  const CalendarApi(this._apiClient) : _localDatabase = null;
  const CalendarApi.local(this._localDatabase) : _apiClient = null;

  final ApiClient? _apiClient;
  final LocalAppDatabase? _localDatabase;

  Future<CalendarResponse> getCalendar({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final localDatabase = _localDatabase;
    if (localDatabase != null) {
      final payments = await localDatabase.listPayments(
        startDate: startDate,
        endDate: endDate,
        includeCancelled: false,
        limit: 100000,
      );
      final days = <CalendarDayEntry>[];
      var day = DateTime(startDate.year, startDate.month, startDate.day);
      final last = DateTime(endDate.year, endDate.month, endDate.day);
      while (!day.isAfter(last)) {
        final dayPayments = payments
            .where((payment) => isoDate(payment.dueDate) == isoDate(day))
            .toList();
        days.add(
          CalendarDayEntry(
            date: day,
            totalEstimated: dayPayments.fold<double>(
              0,
              (sum, payment) => sum + (payment.estimatedAmount ?? 0),
            ),
            payments: dayPayments,
          ),
        );
        day = day.add(const Duration(days: 1));
      }
      return CalendarResponse(
        startDate: startDate,
        endDate: endDate,
        days: days,
      );
    }
    final query = {
      'start_date': isoDate(startDate),
      'end_date': isoDate(endDate),
    };
    final data =
        await _apiClient!.getJsonCached(
              '/calendar',
              query,
              cacheKey: _cacheKey('calendar', query),
              fallbackCacheKey: 'calendar:last',
            )
            as Map<String, dynamic>;
    return CalendarResponse.fromJson(data);
  }
}

String _cacheKey(String prefix, Map<String, Object?> query) {
  final entries =
      query.entries
          .where((entry) => entry.value != null)
          .map((entry) => '${entry.key}=${entry.value}')
          .toList()
        ..sort();
  return '$prefix:${entries.join('&')}';
}

class CalendarResponse {
  const CalendarResponse({
    required this.startDate,
    required this.endDate,
    required this.days,
  });

  final DateTime startDate;
  final DateTime endDate;
  final List<CalendarDayEntry> days;

  factory CalendarResponse.fromJson(Map<String, dynamic> json) {
    return CalendarResponse(
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      days: (json['days'] as List<dynamic>)
          .map(
            (item) => CalendarDayEntry.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class CalendarDayEntry {
  const CalendarDayEntry({
    required this.date,
    required this.totalEstimated,
    required this.payments,
  });

  final DateTime date;
  final double totalEstimated;
  final List<PaymentInstance> payments;

  factory CalendarDayEntry.fromJson(Map<String, dynamic> json) {
    final total = json['total_estimated'];
    return CalendarDayEntry(
      date: DateTime.parse(json['date'] as String),
      totalEstimated: total is num
          ? total.toDouble()
          : double.parse(total.toString()),
      payments: (json['payments'] as List<dynamic>)
          .map((item) => PaymentInstance.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
