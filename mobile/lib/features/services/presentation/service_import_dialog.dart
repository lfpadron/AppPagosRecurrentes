import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

import '../../../shared/formatters.dart';
import '../data/service_account.dart';
import '../data/services_api.dart';

enum ServiceImportDecision { create, replace, ignore }

bool isSupportedServiceImportFileName(String fileName) {
  final lowerName = fileName.toLowerCase();
  return lowerName.endsWith('.xls') || lowerName.endsWith('.xlsx');
}

class ServiceImportRow {
  ServiceImportRow({
    required this.rowNumber,
    required this.draft,
    required this.existing,
    required this.decision,
  });

  final int rowNumber;
  final ServiceDraft draft;
  final ServiceAccount? existing;
  ServiceImportDecision? decision;

  bool get isDuplicate => existing != null;

  ServiceImportRow copy() {
    return ServiceImportRow(
      rowNumber: rowNumber,
      draft: draft,
      existing: existing,
      decision: decision,
    );
  }
}

List<ServiceImportRow> parseServiceImportFile({
  required String fileName,
  required List<int> bytes,
  required List<ServiceAccount> existingServices,
}) {
  final lowerName = fileName.toLowerCase();
  if (lowerName.endsWith('.xlsx')) {
    final decoder = SpreadsheetDecoder.decodeBytes(bytes);
    final table = decoder.tables.values.firstWhere(
      (table) => table.rows.any(_spreadsheetRowHasValues),
      orElse: () => throw const FormatException(
        'El archivo Excel no contiene filas para importar.',
      ),
    );
    return parseServiceImportContent(
      _spreadsheetRowsToTsv(table.rows),
      existingServices,
    );
  }
  return parseServiceImportContent(
    utf8.decode(bytes, allowMalformed: true),
    existingServices,
  );
}

List<ServiceImportRow> parseServiceImportContent(
  String content,
  List<ServiceAccount> existingServices,
) {
  final rawLines = const LineSplitter()
      .convert(content.replaceAll('\r\n', '\n'))
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (rawLines.length < 2) {
    throw const FormatException('El archivo no contiene filas para importar.');
  }

  final delimiter = rawLines.first.contains('\t') ? '\t' : ',';
  final headers = _splitDelimited(
    rawLines.first,
    delimiter,
  ).map(_normalizeHeader).toList();
  final existingByKey = {
    for (final service in existingServices)
      serviceImportKey(
        service.objectName,
        service.serviceName,
        service.providerName,
      ): service,
  };

  final rows = <ServiceImportRow>[];
  for (var i = 1; i < rawLines.length; i++) {
    final values = _splitDelimited(rawLines[i], delimiter);
    final row = <String, String>{};
    for (var column = 0; column < headers.length; column++) {
      row[headers[column]] = column < values.length
          ? values[column].trim()
          : '';
    }
    final draft = _draftFromRow(row, i + 1);
    final existing =
        existingByKey[serviceImportKey(
          draft.objectName,
          draft.serviceName,
          draft.providerName,
        )];
    rows.add(
      ServiceImportRow(
        rowNumber: i + 1,
        draft: draft,
        existing: existing,
        decision: existing == null ? ServiceImportDecision.create : null,
      ),
    );
  }
  return rows;
}

bool _spreadsheetRowHasValues(List row) {
  return row.any((cell) => cell != null && cell.toString().trim().isNotEmpty);
}

String _spreadsheetRowsToTsv(List<List> rows) {
  return rows
      .where(_spreadsheetRowHasValues)
      .map(
        (row) => row
            .map(_spreadsheetCellToText)
            .map((value) => value.replaceAll('\t', ' ').replaceAll('\n', ' '))
            .join('\t'),
      )
      .join('\n');
}

String _spreadsheetCellToText(Object? cell) {
  if (cell == null) return '';
  if (cell is num && cell == cell.roundToDouble()) {
    return cell.toInt().toString();
  }
  return cell.toString().trim();
}

String serviceImportKey(
  String objectName,
  String serviceName,
  String providerName,
) {
  return [
    objectName.trim().toLowerCase(),
    serviceName.trim().toLowerCase(),
    providerName.trim().toLowerCase(),
  ].join('|');
}

class ServiceImportReviewDialog extends StatefulWidget {
  const ServiceImportReviewDialog({super.key, required this.rows});

  final List<ServiceImportRow> rows;

  @override
  State<ServiceImportReviewDialog> createState() =>
      _ServiceImportReviewDialogState();
}

class _ServiceImportReviewDialogState extends State<ServiceImportReviewDialog> {
  late final List<ServiceImportRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.rows.map((row) => row.copy()).toList();
  }

  bool get _hasUndecidedDuplicates =>
      _rows.any((row) => row.isDuplicate && row.decision == null);

  int get _createCount =>
      _rows.where((row) => row.decision == ServiceImportDecision.create).length;

  int get _replaceCount => _rows
      .where((row) => row.decision == ServiceImportDecision.replace)
      .length;

  int get _ignoreCount =>
      _rows.where((row) => row.decision == ServiceImportDecision.ignore).length;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = math.min(screenSize.width - 32, 920.0);
    final dialogHeight = math.min(screenSize.height - 48, 680.0);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: math.max(320, dialogWidth),
        height: math.max(420, dialogHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Importar servicios',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: Icon(
                    Icons.science_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: const Text('Experimental'),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _importAllFileRows,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('Todos los del archivo se importan'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _ignoreAllFileRows,
                      icon: const Icon(Icons.block_outlined),
                      label: const Text('Todos los del archivo se ignoran'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    return _ImportRowCard(
                      row: row,
                      onDecisionChanged: (decision) =>
                          setState(() => row.decision = decision),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Crear: $_createCount  /  Reemplazar: $_replaceCount  /  Ignorar: $_ignoreCount',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _hasUndecidedDuplicates
                        ? null
                        : () => Navigator.of(context).pop(_rows),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Importar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _importAllFileRows() {
    setState(() {
      for (final row in _rows) {
        row.decision = row.isDuplicate
            ? ServiceImportDecision.replace
            : ServiceImportDecision.create;
      }
    });
  }

  void _ignoreAllFileRows() {
    setState(() {
      for (final row in _rows) {
        row.decision = ServiceImportDecision.ignore;
      }
    });
  }
}

class _ImportRowCard extends StatelessWidget {
  const _ImportRowCard({required this.row, required this.onDecisionChanged});

  final ServiceImportRow row;
  final ValueChanged<ServiceImportDecision?>? onDecisionChanged;

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(row);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.fill,
        border: Border.all(color: tone.border, width: 1.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.isDuplicate
                  ? 'Coincidencia por objeto, servicio y proveedor / fila ${row.rowNumber}'
                  : 'Nuevo servicio / fila ${row.rowNumber}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            if (row.existing != null)
              _DuplicateChoiceTable(
                row: row,
                onDecisionChanged: onDecisionChanged,
              )
            else
              _NewFileRow(
                row: row,
                onChanged: onDecisionChanged == null
                    ? null
                    : (importFile) => onDecisionChanged!(
                        importFile
                            ? ServiceImportDecision.create
                            : ServiceImportDecision.ignore,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DuplicateChoiceTable extends StatelessWidget {
  const _DuplicateChoiceTable({
    required this.row,
    required this.onDecisionChanged,
  });

  final ServiceImportRow row;
  final ValueChanged<ServiceImportDecision?>? onDecisionChanged;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(54),
        1: FixedColumnWidth(86),
        2: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _choiceRow(
          context,
          checked: row.decision == ServiceImportDecision.ignore,
          source: 'Actual',
          preview: _ServicePreview.fromExisting(row.existing!),
          onChanged: onDecisionChanged == null
              ? null
              : () => onDecisionChanged!(ServiceImportDecision.ignore),
        ),
        _choiceRow(
          context,
          checked: row.decision == ServiceImportDecision.replace,
          source: 'Archivo',
          preview: _ServicePreview.fromDraft(row.draft),
          onChanged: onDecisionChanged == null
              ? null
              : () => onDecisionChanged!(ServiceImportDecision.replace),
        ),
      ],
    );
  }

  TableRow _choiceRow(
    BuildContext context, {
    required bool checked,
    required String source,
    required Widget preview,
    required VoidCallback? onChanged,
  }) {
    return TableRow(
      children: [
        Checkbox(
          value: checked,
          onChanged: onChanged == null ? null : (_) => onChanged(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            source,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        preview,
      ],
    );
  }
}

class _NewFileRow extends StatelessWidget {
  const _NewFileRow({required this.row, required this.onChanged});

  final ServiceImportRow row;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(54),
        1: FixedColumnWidth(86),
        2: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            Checkbox(
              value: row.decision == ServiceImportDecision.create,
              onChanged: onChanged == null
                  ? null
                  : (value) => onChanged!(value ?? false),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Archivo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            _ServicePreview.fromDraft(row.draft),
          ],
        ),
      ],
    );
  }
}

class _ServicePreview extends StatelessWidget {
  const _ServicePreview({
    required this.objectName,
    required this.serviceName,
    required this.providerName,
    required this.initialDueDate,
    required this.frequency,
    required this.intervalCount,
    required this.amount,
    required this.currency,
  });

  factory _ServicePreview.fromExisting(ServiceAccount service) {
    return _ServicePreview(
      objectName: service.objectName,
      serviceName: service.serviceName,
      providerName: service.providerName,
      initialDueDate: service.initialDueDate,
      frequency: service.frequency,
      intervalCount: service.intervalCount,
      amount: service.estimatedAmount,
      currency: service.currency,
    );
  }

  factory _ServicePreview.fromDraft(ServiceDraft draft) {
    return _ServicePreview(
      objectName: draft.objectName,
      serviceName: draft.serviceName,
      providerName: draft.providerName,
      initialDueDate: draft.initialDueDate,
      frequency: draft.frequency,
      intervalCount: draft.intervalCount,
      amount: draft.estimatedAmount,
      currency: draft.currency,
    );
  }

  final String objectName;
  final String serviceName;
  final String providerName;
  final DateTime initialDueDate;
  final Frequency frequency;
  final int intervalCount;
  final double? amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          Text('$objectName - $serviceName'),
          Text(providerName),
          Text('Vence ${formatDate(initialDueDate)}'),
          Text('${frequency.label} x$intervalCount'),
          Text('${formatMoney(amount)} $currency'),
        ],
      ),
    );
  }
}

class _ImportTone {
  const _ImportTone({required this.fill, required this.border});

  final Color fill;
  final Color border;
}

_ImportTone _toneFor(ServiceImportRow row) {
  if (!row.isDuplicate) {
    return const _ImportTone(
      fill: Color(0xFFF8FAF8),
      border: Color(0xFFC8CCC8),
    );
  }
  return switch (row.decision) {
    null => const _ImportTone(
      fill: Color(0xFFEAF3FF),
      border: Color(0xFF5D9CEC),
    ),
    ServiceImportDecision.replace => const _ImportTone(
      fill: Color(0xFFFFECEB),
      border: Color(0xFFE86B65),
    ),
    ServiceImportDecision.ignore => const _ImportTone(
      fill: Color(0xFFEAF7EC),
      border: Color(0xFF66BB6A),
    ),
    ServiceImportDecision.create => const _ImportTone(
      fill: Color(0xFFF8FAF8),
      border: Color(0xFFC8CCC8),
    ),
  };
}

ServiceDraft _draftFromRow(Map<String, String> row, int rowNumber) {
  final objectName = _required(row, 'object_name', rowNumber);
  final serviceName = _required(row, 'service_name', rowNumber);
  final providerName = _required(row, 'provider_name', rowNumber);
  final initialDueDate = _requiredDate(row, 'initial_due_date', rowNumber);
  final status = _parseStatus(row['status']);
  return ServiceDraft(
    active:
        _parseOptionalBool(row['active']) ??
        status == ServiceLifecycleStatus.active,
    status: status,
    iconKey: _optional(row['icon_key']) ?? 'service_default',
    objectName: objectName,
    serviceName: serviceName,
    providerName: providerName,
    serviceNumber: _optional(row['service_number']) ?? '',
    providerUrl: _optional(row['provider_url']),
    isAutopay: _parseOptionalBool(row['is_autopay']) ?? false,
    chargeAccount: _optional(row['charge_account']),
    initialCutoffDate: _optionalDate(row['initial_cutoff_date']),
    initialDueDate: initialDueDate,
    weekendAdjustment: _parseWeekendAdjustment(row['weekend_adjustment']),
    frequency: _parseFrequency(row['frequency']),
    intervalCount: int.tryParse(row['interval_count'] ?? '') ?? 1,
    estimatedAmount: _optionalDouble(row['estimated_amount']),
    currency: _optional(row['currency']) ?? 'MXN',
    recurrenceEndDate: _optionalDate(row['recurrence_end_date']),
    recurrencePaymentCount: int.tryParse(row['recurrence_payment_count'] ?? ''),
    notes: _optional(row['notes']),
  );
}

List<String> _splitDelimited(String line, String delimiter) {
  if (delimiter == '\t') return line.split('\t');
  final values = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      final nextIsQuote = i + 1 < line.length && line[i + 1] == '"';
      if (quoted && nextIsQuote) {
        buffer.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (char == delimiter && !quoted) {
      values.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  values.add(buffer.toString());
  return values;
}

String _normalizeHeader(String value) {
  return value.replaceFirst('\ufeff', '').trim().toLowerCase();
}

String _required(Map<String, String> row, String key, int rowNumber) {
  final value = _optional(row[key]);
  if (value == null) {
    throw FormatException('Fila $rowNumber: falta $key.');
  }
  return value;
}

DateTime _requiredDate(Map<String, String> row, String key, int rowNumber) {
  final value = _required(row, key, rowNumber);
  return DateTime.parse(value);
}

String? _optional(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _optionalDate(String? value) {
  final text = _optional(value);
  return text == null ? null : DateTime.parse(text);
}

double? _optionalDouble(String? value) {
  final text = _optional(value);
  return text == null ? null : double.tryParse(text.replaceAll(',', ''));
}

bool? _parseOptionalBool(String? value) {
  final text = _optional(value)?.toLowerCase();
  if (text == null) return null;
  return text == 'true' || text == '1' || text == 'si' || text == 'sí';
}

Frequency _parseFrequency(String? value) {
  final text = _optional(value);
  return text == null ? Frequency.monthly : parseFrequency(text);
}

ServiceLifecycleStatus _parseStatus(String? value) {
  final text = _optional(value);
  return text == null
      ? ServiceLifecycleStatus.active
      : parseServiceLifecycleStatus(text);
}

WeekendAdjustment _parseWeekendAdjustment(String? value) {
  final text = _optional(value);
  return text == null ? WeekendAdjustment.none : parseWeekendAdjustment(text);
}
