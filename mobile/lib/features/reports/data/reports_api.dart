import '../../../core/network/api_client.dart';
import '../../../core/storage/local_app_database.dart';
import '../../../shared/formatters.dart';
import '../../payments/data/payment_instance.dart';

class ReportsApi {
  const ReportsApi(this._apiClient) : _localDatabase = null;
  const ReportsApi.local(this._localDatabase) : _apiClient = null;

  final ApiClient? _apiClient;
  final LocalAppDatabase? _localDatabase;

  Future<ReportSummary> paidSummary({
    required DateTime startDate,
    required DateTime endDate,
    String? serviceAccountId,
    String? objectName,
    String? currency,
  }) async {
    final localDatabase = _localDatabase;
    if (localDatabase != null) {
      final payments = await localDatabase.listPayments(
        startDate: startDate,
        endDate: endDate,
        serviceAccountId: serviceAccountId,
        objectName: objectName,
        currency: currency,
        status: PaymentStatus.paid,
        includeCancelled: false,
        limit: 100000,
      );
      return _summaryFromPayments(
        payments,
        startDate: startDate,
        endDate: endDate,
        serviceAccountId: serviceAccountId,
        currency: currency,
        amountFor: (payment) => payment.paidAmount ?? payment.estimatedAmount,
      );
    }
    final data =
        await _apiClient!.getJson('/reports/paid-summary', {
              'start_date': isoDate(startDate),
              'end_date': isoDate(endDate),
              'service_account_id': serviceAccountId,
              'object_name': objectName,
              'currency': currency,
            })
            as Map<String, dynamic>;
    return ReportSummary.fromJson(data);
  }

  Future<ReportSummary> estimatedSummary({
    required DateTime startDate,
    required DateTime endDate,
    String? serviceAccountId,
    String? objectName,
    String? currency,
    bool includeCancelled = false,
  }) async {
    final localDatabase = _localDatabase;
    if (localDatabase != null) {
      final payments = await localDatabase.listPayments(
        startDate: startDate,
        endDate: endDate,
        serviceAccountId: serviceAccountId,
        objectName: objectName,
        currency: currency,
        includeCancelled: includeCancelled,
        limit: 100000,
      );
      final pendingPayments = payments
          .where((payment) => payment.status != PaymentStatus.paid)
          .toList();
      return _summaryFromPayments(
        pendingPayments,
        startDate: startDate,
        endDate: endDate,
        serviceAccountId: serviceAccountId,
        currency: currency,
        amountFor: (payment) => payment.estimatedAmount,
      );
    }
    final data =
        await _apiClient!.getJson('/reports/estimated-summary', {
              'start_date': isoDate(startDate),
              'end_date': isoDate(endDate),
              'service_account_id': serviceAccountId,
              'object_name': objectName,
              'currency': currency,
              'include_cancelled': includeCancelled,
            })
            as Map<String, dynamic>;
    return ReportSummary.fromJson(data);
  }
}

ReportSummary _summaryFromPayments(
  List<PaymentInstance> payments, {
  required DateTime startDate,
  required DateTime endDate,
  required String? serviceAccountId,
  required String? currency,
  required double? Function(PaymentInstance payment) amountFor,
}) {
  final totalsByStatus = <String, double>{};
  var total = 0.0;
  final currencies = <String>{};
  for (final payment in payments) {
    final amount = amountFor(payment) ?? 0;
    total += amount;
    currencies.add(payment.currency);
    totalsByStatus[payment.status.value] =
        (totalsByStatus[payment.status.value] ?? 0) + amount;
  }
  return ReportSummary(
    startDate: startDate,
    endDate: endDate,
    serviceAccountId: serviceAccountId,
    paymentCount: payments.length,
    totalAmount: total,
    currency:
        currency ?? (currencies.length == 1 ? currencies.first : 'VARIAS'),
    totalsByStatus: totalsByStatus,
  );
}

class ReportSummary {
  const ReportSummary({
    required this.startDate,
    required this.endDate,
    required this.paymentCount,
    required this.totalAmount,
    required this.currency,
    required this.totalsByStatus,
    this.serviceAccountId,
  });

  final DateTime startDate;
  final DateTime endDate;
  final String? serviceAccountId;
  final int paymentCount;
  final double totalAmount;
  final String currency;
  final Map<String, double> totalsByStatus;

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      serviceAccountId: json['service_account_id'] as String?,
      paymentCount: json['payment_count'] as int,
      totalAmount: _double(json['total_amount']),
      currency: json['currency'] as String,
      totalsByStatus: (json['totals_by_status'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, _double(value)),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'start_date': isoDate(startDate),
      'end_date': isoDate(endDate),
      'service_account_id': serviceAccountId,
      'payment_count': paymentCount,
      'total_amount': totalAmount,
      'currency': currency,
      'totals_by_status': totalsByStatus,
    };
  }
}

double _double(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.parse(value.toString());
}
