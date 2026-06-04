import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/date_picker.dart';
import '../../../shared/dependencies.dart';
import '../../../shared/export/download_file.dart';
import '../../../shared/export/export_format.dart';
import '../../../shared/formatters.dart';
import '../../../shared/service_currency_options.dart';
import '../../../shared/widgets/api_error_view.dart';
import '../../reports/data/reports_api.dart';
import '../../services/data/service_account.dart';

enum _PaidPreset { thisMonth, lastMonth, custom }

enum _EstimatePreset { thisWeek, remainingMonth, thisMonth, nextMonth, custom }

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _loaded = false;
  _PaidPreset _paidPreset = _PaidPreset.thisMonth;
  _EstimatePreset _estimatePreset = _EstimatePreset.remainingMonth;
  String? _serviceId;
  String? _currencyFilter;
  bool _includeCancelledEstimate = false;
  final _objectNameController = TextEditingController();
  late DateTime _paidStart;
  late DateTime _paidEnd;
  late DateTime _estimateStart;
  late DateTime _estimateEnd;
  late Future<List<ServiceAccount>> _servicesFuture;
  late Future<ReportSummary> _paidFuture;
  late Future<ReportSummary> _estimateFuture;

  ReportsApi get _reportsApi => DependenciesScope.of(context).reportsApi;

  @override
  void dispose() {
    _objectNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final today = dateOnly(DateTime.now());
    _paidStart = DateTime(today.year, today.month);
    _paidEnd = DateTime(today.year, today.month + 1, 0);
    _estimateStart = DateTime(today.year, today.month);
    _estimateEnd = DateTime(today.year, today.month + 1, 0);
    _servicesFuture = Future.value(const []);
    _paidFuture = Future.value(
      ReportSummary(
        startDate: _paidStart,
        endDate: _paidEnd,
        paymentCount: 0,
        totalAmount: 0,
        currency: 'MXN',
        totalsByStatus: const {},
      ),
    );
    _estimateFuture = Future.value(
      ReportSummary(
        startDate: _estimateStart,
        endDate: _estimateEnd,
        paymentCount: 0,
        totalAmount: 0,
        currency: 'MXN',
        totalsByStatus: const {},
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _servicesFuture = DependenciesScope.of(
      context,
    ).servicesApi.listAllServices();
    _refreshSummaries();
  }

  void _refreshSummaries() {
    setState(() {
      _paidFuture = _reportsApi.paidSummary(
        startDate: _paidStart,
        endDate: _paidEnd,
        serviceAccountId: _serviceId,
        objectName: _objectNameController.text.trim().isEmpty
            ? null
            : _objectNameController.text.trim(),
        currency: _currencyFilter,
      );
      _estimateFuture = _reportsApi.estimatedSummary(
        startDate: _estimateStart,
        endDate: _estimateEnd,
        serviceAccountId: _serviceId,
        objectName: _objectNameController.text.trim().isEmpty
            ? null
            : _objectNameController.text.trim(),
        currency: _currencyFilter,
        includeCancelled: _includeCancelledEstimate,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<List<ServiceAccount>>(
            future: _servicesFuture,
            builder: (context, snapshot) {
              final services = snapshot.data ?? const <ServiceAccount>[];
              return DropdownButtonFormField<String>(
                initialValue: _serviceId ?? '',
                decoration: const InputDecoration(
                  labelText: 'Servicio',
                  prefixIcon: Icon(Icons.home_repair_service_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Todos')),
                  ...services.map(
                    (service) => DropdownMenuItem(
                      value: service.id,
                      child: Text(
                        '${service.objectName} - ${service.serviceName}',
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  _serviceId = value == null || value.isEmpty ? null : value;
                  _refreshSummaries();
                },
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _objectNameController,
            decoration: const InputDecoration(
              labelText: 'Predio/objeto',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
            onSubmitted: (_) => _refreshSummaries(),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<ServiceAccount>>(
            future: _servicesFuture,
            builder: (context, snapshot) {
              final currencies = serviceCurrencyOptions(
                snapshot.data ?? const <ServiceAccount>[],
              );
              final selectedCurrencyValue =
                  _currencyFilter != null &&
                      currencies.contains(_currencyFilter)
                  ? _currencyFilter!
                  : '';
              return DropdownButtonFormField<String>(
                initialValue: selectedCurrencyValue,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Moneda',
                  prefixIcon: Icon(Icons.currency_exchange_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Todas')),
                  ...currencies.map(
                    (currency) => DropdownMenuItem(
                      value: currency,
                      child: Text(currency),
                    ),
                  ),
                ],
                onChanged: (value) {
                  _currencyFilter = value == null || value.isEmpty
                      ? null
                      : value;
                  _refreshSummaries();
                },
              );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _refreshSummaries,
              icon: const Icon(Icons.search),
              label: const Text('Aplicar filtros'),
            ),
          ),
          const SizedBox(height: 16),
          _ReportSection(
            title: 'Cuanto he pagado',
            icon: Icons.payments_outlined,
            child: Column(
              children: [
                DropdownButtonFormField<_PaidPreset>(
                  initialValue: _paidPreset,
                  decoration: const InputDecoration(labelText: 'Atajo'),
                  items: const [
                    DropdownMenuItem(
                      value: _PaidPreset.thisMonth,
                      child: Text('Este mes'),
                    ),
                    DropdownMenuItem(
                      value: _PaidPreset.lastMonth,
                      child: Text('Mes pasado'),
                    ),
                    DropdownMenuItem(
                      value: _PaidPreset.custom,
                      child: Text('Rango personalizado'),
                    ),
                  ],
                  onChanged: (value) {
                    _paidPreset = value ?? _PaidPreset.thisMonth;
                    _applyPaidPreset();
                  },
                ),
                if (_paidPreset == _PaidPreset.custom)
                  _RangePicker(
                    start: _paidStart,
                    end: _paidEnd,
                    onChanged: (start, end) {
                      _paidStart = start;
                      _paidEnd = end;
                      _refreshSummaries();
                    },
                  ),
                const SizedBox(height: 12),
                FutureBuilder<ReportSummary>(
                  future: _paidFuture,
                  builder: (context, snapshot) => _SummaryResult(
                    title: 'pagado',
                    snapshot: snapshot,
                    onRetry: _refreshSummaries,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ReportSection(
            title: 'Cuanto estimo pagar',
            icon: Icons.event_available_outlined,
            child: Column(
              children: [
                DropdownButtonFormField<_EstimatePreset>(
                  initialValue: _estimatePreset,
                  decoration: const InputDecoration(labelText: 'Atajo'),
                  items: const [
                    DropdownMenuItem(
                      value: _EstimatePreset.thisWeek,
                      child: Text('Esta semana'),
                    ),
                    DropdownMenuItem(
                      value: _EstimatePreset.remainingMonth,
                      child: Text('Lo que falta del mes'),
                    ),
                    DropdownMenuItem(
                      value: _EstimatePreset.thisMonth,
                      child: Text('Este mes'),
                    ),
                    DropdownMenuItem(
                      value: _EstimatePreset.nextMonth,
                      child: Text('Mes siguiente'),
                    ),
                    DropdownMenuItem(
                      value: _EstimatePreset.custom,
                      child: Text('Rango personalizado'),
                    ),
                  ],
                  onChanged: (value) {
                    _estimatePreset = value ?? _EstimatePreset.remainingMonth;
                    _applyEstimatePreset();
                  },
                ),
                if (_estimatePreset == _EstimatePreset.custom)
                  _RangePicker(
                    start: _estimateStart,
                    end: _estimateEnd,
                    onChanged: (start, end) {
                      _estimateStart = start;
                      _estimateEnd = end;
                      _refreshSummaries();
                    },
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _includeCancelledEstimate,
                  title: const Text('Incluir pagos cancelados'),
                  onChanged: (value) {
                    _includeCancelledEstimate = value;
                    _refreshSummaries();
                  },
                ),
                const SizedBox(height: 12),
                FutureBuilder<ReportSummary>(
                  future: _estimateFuture,
                  builder: (context, snapshot) => _SummaryResult(
                    title: 'estimado',
                    snapshot: snapshot,
                    onRetry: _refreshSummaries,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _applyPaidPreset() {
    final today = dateOnly(DateTime.now());
    if (_paidPreset == _PaidPreset.thisMonth) {
      _paidStart = DateTime(today.year, today.month);
      _paidEnd = DateTime(today.year, today.month + 1, 0);
    } else if (_paidPreset == _PaidPreset.lastMonth) {
      _paidStart = DateTime(today.year, today.month - 1);
      _paidEnd = DateTime(today.year, today.month, 0);
    }
    _refreshSummaries();
  }

  void _applyEstimatePreset() {
    final today = dateOnly(DateTime.now());
    if (_estimatePreset == _EstimatePreset.thisWeek) {
      _estimateStart = today;
      _estimateEnd = today.add(const Duration(days: 6));
    } else if (_estimatePreset == _EstimatePreset.remainingMonth) {
      _estimateStart = DateTime(today.year, today.month);
      _estimateEnd = DateTime(today.year, today.month + 1, 0);
    } else if (_estimatePreset == _EstimatePreset.thisMonth) {
      _estimateStart = DateTime(today.year, today.month);
      _estimateEnd = DateTime(today.year, today.month + 1, 0);
    } else if (_estimatePreset == _EstimatePreset.nextMonth) {
      _estimateStart = DateTime(today.year, today.month + 1);
      _estimateEnd = DateTime(today.year, today.month + 2, 0);
    }
    _refreshSummaries();
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SummaryResult extends StatelessWidget {
  const _SummaryResult({
    required this.title,
    required this.snapshot,
    required this.onRetry,
  });

  final String title;
  final AsyncSnapshot<ReportSummary> snapshot;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (snapshot.hasError) {
      final error = snapshot.error;
      return ApiErrorView(
        message: error is ApiException ? error.message : error.toString(),
        onRetry: onRetry,
      );
    }
    final summary = snapshot.data!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            formatMoneyWithCurrency(summary.totalAmount, summary.currency),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          subtitle: Text(
            '${summary.paymentCount} pagos / ${formatDate(summary.startDate)} a ${formatDate(summary.endDate)}',
          ),
          trailing: const Icon(Icons.summarize_outlined),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _showExport(
                context,
                title: title,
                format: _ReportExportFormat.excel,
                summary: summary,
              ),
              icon: const Icon(Icons.table_view_outlined),
              label: const Text('Excel'),
            ),
            OutlinedButton.icon(
              onPressed: () => _showExport(
                context,
                title: title,
                format: _ReportExportFormat.csv,
                summary: summary,
              ),
              icon: const Icon(Icons.text_snippet_outlined),
              label: const Text('CSV'),
            ),
            OutlinedButton.icon(
              onPressed: () => _showExport(
                context,
                title: title,
                format: _ReportExportFormat.json,
                summary: summary,
              ),
              icon: const Icon(Icons.data_object_outlined),
              label: const Text('JSON'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showExport(
    BuildContext context, {
    required String title,
    required _ReportExportFormat format,
    required ReportSummary summary,
  }) async {
    final rawContent = switch (format) {
      _ReportExportFormat.json => const JsonEncoder.withIndent(
        '  ',
      ).convert(summary.toJson()),
      _ReportExportFormat.csv => _summaryCsv(summary),
      _ReportExportFormat.excel => _summaryTsv(summary),
    };
    final label = switch (format) {
      _ReportExportFormat.json => 'JSON',
      _ReportExportFormat.csv => 'CSV',
      _ReportExportFormat.excel => 'Excel',
    };
    final extension = switch (format) {
      _ReportExportFormat.json => 'json',
      _ReportExportFormat.csv => 'csv',
      _ReportExportFormat.excel => 'xls',
    };
    final mimeType = switch (format) {
      _ReportExportFormat.json => utf8Mime('application/json'),
      _ReportExportFormat.csv => utf8Mime('text/csv'),
      _ReportExportFormat.excel => utf8Mime('application/vnd.ms-excel'),
    };
    final content = format == _ReportExportFormat.json
        ? rawContent
        : withUtf8Bom(rawContent);
    final downloaded = await downloadTextFile(
      fileName: exportFileName(
        'reporte_${title}_${isoDate(summary.startDate)}_${isoDate(summary.endDate)}',
        extension,
      ),
      content: content,
      mimeType: mimeType,
    );
    if (!context.mounted || downloaded) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export $label - $title'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 520),
          child: SingleChildScrollView(child: SelectableText(content)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

enum _ReportExportFormat { excel, csv, json }

String _summaryCsv(ReportSummary summary) {
  final rows = [
    'start_date,end_date,payment_count,total_amount,currency',
    '${isoDate(summary.startDate)},${isoDate(summary.endDate)},${summary.paymentCount},${formatAmount(summary.totalAmount)},${summary.currency}',
    '',
    'status,total_amount',
    ...summary.totalsByStatus.entries.map(
      (entry) => '${entry.key},${formatAmount(entry.value)}',
    ),
  ];
  return rows.join('\n');
}

String _summaryTsv(ReportSummary summary) {
  final rows = [
    'start_date\tend_date\tpayment_count\ttotal_amount\tcurrency',
    '${isoDate(summary.startDate)}\t${isoDate(summary.endDate)}\t${summary.paymentCount}\t${formatAmount(summary.totalAmount)}\t${summary.currency}',
    '',
    'status\ttotal_amount',
    ...summary.totalsByStatus.entries.map(
      (entry) => '${entry.key}\t${formatAmount(entry.value)}',
    ),
  ];
  return rows.join('\n');
}

class _RangePicker extends StatelessWidget {
  const _RangePicker({
    required this.start,
    required this.end,
    required this.onChanged,
  });

  final DateTime start;
  final DateTime end;
  final void Function(DateTime start, DateTime end) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(context, true),
              icon: const Icon(Icons.event_outlined),
              label: Text(formatDate(start)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(context, false),
              icon: const Icon(Icons.event_available_outlined),
              label: Text(formatDate(end)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, bool isStart) async {
    final picked = await pickAppDate(
      context,
      initialDate: isStart ? start : end,
    );
    if (picked == null) return;
    final normalized = dateOnly(picked);
    if (isStart) {
      onChanged(normalized, normalized.isAfter(end) ? normalized : end);
    } else {
      onChanged(normalized.isBefore(start) ? normalized : start, normalized);
    }
  }
}
