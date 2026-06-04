import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/dependencies.dart';
import '../../../shared/date_picker.dart';
import '../../../shared/export/download_file.dart';
import '../../../shared/export/export_format.dart';
import '../../../shared/export/simple_xlsx.dart';
import '../../../shared/formatters.dart';
import '../../../shared/import/pick_text_file.dart';
import '../../../shared/icons/service_icon_catalog.dart';
import '../../../shared/platform/app_platform.dart';
import '../../../shared/widgets/api_error_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../payments/data/payment_instance.dart';
import '../../payments/data/payments_api.dart';
import '../data/service_account.dart';
import '../data/services_api.dart';
import 'service_form_dialog.dart';
import 'service_import_dialog.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  late Future<List<ServiceAccount>> _future;
  final _objectNameController = TextEditingController();
  final Set<String> _selectedServiceIds = {};
  ServiceLifecycleStatus? _statusFilter;

  ServicesApi get _api => DependenciesScope.of(context).servicesApi;
  PaymentsApi get _paymentsApi => DependenciesScope.of(context).paymentsApi;

  @override
  void initState() {
    super.initState();
    _future = Future.value(const []);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void dispose() {
    _objectNameController.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _selectedServiceIds.clear();
      _future = _api.listServices(
        objectName: _objectNameController.text.trim().isEmpty
            ? null
            : _objectNameController.text.trim(),
        status: _statusFilter,
        limit: 30,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Servicios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Servicio'),
      ),
      body: FutureBuilder<List<ServiceAccount>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ApiErrorView(
              message: snapshot.error.toString(),
              onRetry: _load,
            );
          }
          final services = snapshot.data ?? const <ServiceAccount>[];
          final selectedServices = services
              .where((service) => _selectedServiceIds.contains(service.id))
              .toList();
          final selectedPausedServices = selectedServices
              .where(
                (service) => service.status == ServiceLifecycleStatus.paused,
              )
              .toList();
          final filters = _ServiceFilters(
            objectNameController: _objectNameController,
            status: _statusFilter,
            selectedCount: selectedServices.length,
            onStatusChanged: (value) {
              _statusFilter = value;
              _load();
            },
            onApply: _load,
            onClear: () {
              _objectNameController.clear();
              _statusFilter = null;
              _load();
            },
            onPauseSelected: selectedServices.isEmpty
                ? null
                : () => _pauseServices(selectedServices),
            onReactivateSelected: selectedPausedServices.isEmpty
                ? null
                : () => _bulkSetStatus(
                    selectedPausedServices,
                    ServiceLifecycleStatus.active,
                  ),
            onEndSelected: selectedServices.isEmpty
                ? null
                : () => _bulkSetStatus(
                    selectedServices,
                    ServiceLifecycleStatus.ended,
                  ),
            onExport: (format) => _exportServices(
              selectedServices.isEmpty ? null : selectedServices,
              format,
            ),
            onImport: _importServices,
          );
          if (isAndroidApp) {
            return RefreshIndicator(
              onRefresh: () async => _load(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  filters,
                  if (services.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 48, 16, 16),
                      child: EmptyState(
                        icon: Icons.home_repair_service_outlined,
                        title: 'Sin servicios',
                        message:
                            'Crea tu primer servicio recurrente para generar pagos.',
                      ),
                    )
                  else
                    ...services.map(
                      (service) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: _ServiceListCard(
                          service: service,
                          selected: _selectedServiceIds.contains(service.id),
                          onSelectionChanged: (selected) =>
                              _toggleSelection(service, selected),
                          onOpen: () => _openForm(initial: service),
                        ),
                      ),
                    ),
                  const SizedBox(height: 88),
                ],
              ),
            );
          }

          return Column(
            children: [
              filters,
              Expanded(
                child: services.isEmpty
                    ? const EmptyState(
                        icon: Icons.home_repair_service_outlined,
                        title: 'Sin servicios',
                        message:
                            'Crea tu primer servicio recurrente para generar pagos.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _load(),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 820) {
                              return _ServicesTable(
                                services: services,
                                selectedServiceIds: _selectedServiceIds,
                                onSelectionChanged: _toggleSelection,
                                onOpen: (service) =>
                                    _openForm(initial: service),
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: services.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final service = services[index];
                                final selected = _selectedServiceIds.contains(
                                  service.id,
                                );
                                return _ServiceListCard(
                                  service: service,
                                  selected: selected,
                                  onSelectionChanged: (selected) =>
                                      _toggleSelection(service, selected),
                                  onOpen: () => _openForm(initial: service),
                                );
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggleSelection(ServiceAccount service, bool selected) {
    setState(() {
      if (selected) {
        _selectedServiceIds.add(service.id);
      } else {
        _selectedServiceIds.remove(service.id);
      }
    });
  }

  Future<void> _openForm({ServiceAccount? initial}) async {
    final draft = await showDialog<ServiceDraft>(
      context: context,
      builder: (_) => ServiceFormDialog(initial: initial),
    );
    if (draft == null) return;

    try {
      if (initial == null) {
        await _api.createService(draft);
      } else {
        var effectiveFrom = dateOnly(DateTime.now());
        if (initial.status != ServiceLifecycleStatus.ended &&
            draft.status == ServiceLifecycleStatus.ended) {
          final decision = await _confirmEndServices([initial]);
          if (decision == null) return;
          effectiveFrom = decision.effectiveFrom;
          await _applyOverdueDecision([initial], decision);
        }
        await _api.updateService(initial.id, draft, effectiveFrom);
      }
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              initial == null ? 'Servicio creado' : 'Servicio actualizado',
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _bulkSetStatus(
    List<ServiceAccount> services,
    ServiceLifecycleStatus status,
  ) async {
    try {
      var effectiveFrom = dateOnly(DateTime.now());
      _EndServiceDecision? decision;
      if (status == ServiceLifecycleStatus.ended) {
        decision = await _confirmEndServices(services);
        if (decision == null) return;
        effectiveFrom = decision.effectiveFrom;
        await _applyOverdueDecision(services, decision);
      }

      for (final service in services) {
        await _api.updateService(
          service.id,
          _draftFromService(service, status: status),
          effectiveFrom,
        );
      }
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${services.length} servicios actualizados')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _pauseServices(List<ServiceAccount> services) async {
    final decision = await showDialog<_PauseServiceDecision>(
      context: context,
      builder: (context) => _PauseServiceDialog(serviceCount: services.length),
    );
    if (decision == null) return;
    try {
      for (final service in services) {
        await _api.updateService(
          service.id,
          _draftFromService(
            service,
            status: ServiceLifecycleStatus.paused,
            pausedFrom: decision.from,
            pauseUntil: decision.until,
          ),
          decision.from,
        );
      }
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${services.length} servicios pausados')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<_EndServiceDecision?> _confirmEndServices(
    List<ServiceAccount> services,
  ) async {
    final overdue = await _overduePaymentsForServices(services);
    if (!mounted) return null;
    return showDialog<_EndServiceDecision>(
      context: context,
      builder: (context) => _EndServiceDialog(
        serviceCount: services.length,
        overdueCount: overdue.length,
      ),
    );
  }

  Future<List<PaymentInstance>> _overduePaymentsForServices(
    List<ServiceAccount> services,
  ) async {
    final today = dateOnly(DateTime.now());
    final overdue = <PaymentInstance>[];
    for (final service in services) {
      var offset = 0;
      while (true) {
        final payments = await _paymentsApi.listPayments(
          serviceAccountId: service.id,
          endDate: today.subtract(const Duration(days: 1)),
          includeCancelled: false,
          limit: 90,
          offset: offset,
        );
        overdue.addAll(
          payments.where(
            (payment) =>
                payment.status != PaymentStatus.paid &&
                payment.status != PaymentStatus.cancelled &&
                payment.status != PaymentStatus.cancelledByRecalculation &&
                payment.status != PaymentStatus.notApplicableException,
          ),
        );
        if (payments.length < 90) break;
        offset += 90;
      }
    }
    return overdue;
  }

  Future<void> _applyOverdueDecision(
    List<ServiceAccount> services,
    _EndServiceDecision decision,
  ) async {
    if (decision.overdueAction == _OverdueAction.none) return;
    final overdue = await _overduePaymentsForServices(services);
    for (final payment in overdue) {
      if (decision.overdueAction == _OverdueAction.complete) {
        await _paymentsApi.markPaid(
          payment.id,
          paidAmount: payment.estimatedAmount,
          paidAt: decision.paidAt,
        );
      } else {
        await _paymentsApi.cancel(
          payment.id,
          reason: 'Cancelado al terminar servicio',
        );
      }
    }
  }

  Future<void> _exportServices(
    List<ServiceAccount>? selected,
    _ServiceExportFormat format,
  ) async {
    final services =
        selected ??
        await _listAllServices(
          objectName: _objectNameController.text.trim().isEmpty
              ? null
              : _objectNameController.text.trim(),
          status: _statusFilter,
        );
    final title = switch (format) {
      _ServiceExportFormat.json => 'Export JSON',
      _ServiceExportFormat.csv => 'Export CSV',
      _ServiceExportFormat.excel => 'Export Excel',
    };
    final extension = switch (format) {
      _ServiceExportFormat.json => 'json',
      _ServiceExportFormat.csv => 'csv',
      _ServiceExportFormat.excel => 'xlsx',
    };
    final mimeType = switch (format) {
      _ServiceExportFormat.json => utf8Mime('application/json'),
      _ServiceExportFormat.csv => utf8Mime('text/csv'),
      _ServiceExportFormat.excel =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    };
    if (!mounted) return;
    if (format == _ServiceExportFormat.excel) {
      final downloaded = await downloadBytesFile(
        fileName: exportFileName('servicios', extension),
        bytes: buildServicesXlsx(services),
        mimeType: mimeType,
      );
      if (!mounted) return;
      if (downloaded) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$title generado')));
      }
      return;
    }
    final rawContent = switch (format) {
      _ServiceExportFormat.json => const JsonEncoder.withIndent(
        '  ',
      ).convert(services.map(_serviceToJson).toList()),
      _ServiceExportFormat.csv => _servicesCsv(services),
      _ServiceExportFormat.excel => '',
    };
    final content = format == _ServiceExportFormat.json
        ? rawContent
        : withUtf8Bom(rawContent);
    final downloaded = await downloadTextFile(
      fileName: exportFileName('servicios', extension),
      content: content,
      mimeType: mimeType,
    );
    if (!mounted) return;
    if (downloaded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$title generado')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
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

  Future<void> _importServices() async {
    try {
      final proceed = await _showExperimentalImportDialog();
      if (proceed != true || !mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      final picked = await pickTextFile(accept: '.xls,.xlsx');
      if (!mounted || picked == null) return;
      if (!isSupportedServiceImportFileName(picked.name)) {
        await _showUnsupportedImportTypeDialog();
        return;
      }
      final existing = await _listAllServices();
      final rows = parseServiceImportFile(
        fileName: picked.name,
        bytes: picked.bytes,
        existingServices: existing,
      );
      if (!mounted) return;
      final reviewed = await showDialog<List<ServiceImportRow>>(
        context: context,
        builder: (context) => ServiceImportReviewDialog(rows: rows),
      );
      if (reviewed == null) return;

      var created = 0;
      var replaced = 0;
      var ignored = 0;
      final today = dateOnly(DateTime.now());
      for (final row in reviewed) {
        switch (row.decision) {
          case ServiceImportDecision.create:
            await _api.createService(row.draft);
            created++;
          case ServiceImportDecision.replace:
            if (row.existing == null) {
              await _api.createService(row.draft);
              created++;
            } else {
              await _api.updateService(row.existing!.id, row.draft, today);
              replaced++;
            }
          case ServiceImportDecision.ignore:
            ignored++;
          case null:
            ignored++;
        }
      }
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Importacion lista: $created creados, $replaced reemplazados, $ignored ignorados',
            ),
          ),
        );
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo importar: $error')));
      }
    }
  }

  Future<bool?> _showExperimentalImportDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importar servicios'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(
              avatar: Icon(
                Icons.science_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: const Text('Experimental'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Selecciona un archivo Excel con el mismo formato de exportacion de servicios.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Seleccionar Excel'),
          ),
        ],
      ),
    );
  }

  Future<void> _showUnsupportedImportTypeDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importar servicios'),
        content: const Text(
          'Tipo de archivo no compatible. Archivos aceptados: Excel',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<List<ServiceAccount>> _listAllServices({
    String? objectName,
    ServiceLifecycleStatus? status,
  }) async {
    const pageSize = 500;
    var offset = 0;
    final services = <ServiceAccount>[];
    while (true) {
      final page = await _api.listServices(
        objectName: objectName,
        status: status,
        limit: pageSize,
        offset: offset,
      );
      services.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return services;
  }
}

class _ServiceFilters extends StatelessWidget {
  const _ServiceFilters({
    required this.objectNameController,
    required this.status,
    required this.selectedCount,
    required this.onStatusChanged,
    required this.onApply,
    required this.onClear,
    required this.onPauseSelected,
    required this.onReactivateSelected,
    required this.onEndSelected,
    required this.onExport,
    required this.onImport,
  });

  final TextEditingController objectNameController;
  final ServiceLifecycleStatus? status;
  final int selectedCount;
  final ValueChanged<ServiceLifecycleStatus?> onStatusChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final VoidCallback? onPauseSelected;
  final VoidCallback? onReactivateSelected;
  final VoidCallback? onEndSelected;
  final ValueChanged<_ServiceExportFormat> onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: objectNameController,
                decoration: const InputDecoration(
                  labelText: 'Predio/objeto',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                onSubmitted: (_) => onApply(),
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<String>(
                initialValue: status?.value ?? '',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  prefixIcon: Icon(Icons.toggle_on_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Todos')),
                  ...ServiceLifecycleStatus.values.map(
                    (item) => DropdownMenuItem(
                      value: item.value,
                      child: Text(item.label),
                    ),
                  ),
                ],
                onChanged: (value) => onStatusChanged(
                  value == null || value.isEmpty
                      ? null
                      : parseServiceLifecycleStatus(value),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.search),
              label: const Text('Aplicar'),
            ),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear),
              label: const Text('Limpiar'),
            ),
            OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Importar Excel'),
            ),
            OutlinedButton.icon(
              onPressed: () => onExport(_ServiceExportFormat.excel),
              icon: const Icon(Icons.table_view_outlined),
              label: const Text('Excel'),
            ),
            OutlinedButton.icon(
              onPressed: () => onExport(_ServiceExportFormat.csv),
              icon: const Icon(Icons.text_snippet_outlined),
              label: const Text('CSV'),
            ),
            OutlinedButton.icon(
              onPressed: () => onExport(_ServiceExportFormat.json),
              icon: const Icon(Icons.data_object_outlined),
              label: const Text('JSON'),
            ),
            Text(
              selectedCount == 0 ? 'Limite visible: 30' : '$selectedCount sel.',
            ),
            FilledButton.tonalIcon(
              onPressed: onPauseSelected,
              icon: const Icon(Icons.pause_circle_outline),
              label: const Text('Pausar'),
            ),
            FilledButton.tonalIcon(
              onPressed: onReactivateSelected,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Reactivar'),
            ),
            FilledButton.tonalIcon(
              onPressed: onEndSelected,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Terminar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServicesTable extends StatelessWidget {
  const _ServicesTable({
    required this.services,
    required this.selectedServiceIds,
    required this.onSelectionChanged,
    required this.onOpen,
  });

  final List<ServiceAccount> services;
  final Set<String> selectedServiceIds;
  final void Function(ServiceAccount service, bool selected) onSelectionChanged;
  final ValueChanged<ServiceAccount> onOpen;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: true,
          columns: const [
            DataColumn(label: Text('Icono')),
            DataColumn(label: Text('Predio/objeto')),
            DataColumn(label: Text('Servicio')),
            DataColumn(label: Text('Proveedor')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Vence')),
            DataColumn(label: Text('Estimado')),
          ],
          rows: services.map((service) {
            return DataRow(
              selected: selectedServiceIds.contains(service.id),
              onSelectChanged: (selected) =>
                  onSelectionChanged(service, selected ?? false),
              cells: [
                DataCell(
                  ServiceIconBadge(iconKey: service.iconKey, size: 34),
                  onTap: () => onOpen(service),
                ),
                DataCell(
                  Text(service.objectName),
                  onTap: () => onOpen(service),
                ),
                DataCell(
                  Text(service.serviceName),
                  onTap: () => onOpen(service),
                ),
                DataCell(
                  Text(service.providerName),
                  onTap: () => onOpen(service),
                ),
                DataCell(
                  Text(service.status.label),
                  onTap: () => onOpen(service),
                ),
                DataCell(
                  Text(formatDate(service.initialDueDate)),
                  onTap: () => onOpen(service),
                ),
                DataCell(
                  Text(formatMoney(service.estimatedAmount)),
                  onTap: () => onOpen(service),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

enum _OverdueAction { none, cancel, complete }

enum _ServiceExportFormat { excel, csv, json }

class _ServiceListCard extends StatelessWidget {
  const _ServiceListCard({
    required this.service,
    required this.selected,
    required this.onSelectionChanged,
    required this.onOpen,
  });

  final ServiceAccount service;
  final bool selected;
  final ValueChanged<bool> onSelectionChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: selected,
          onChanged: (value) => onSelectionChanged(value ?? false),
        ),
        title: Row(
          children: [
            ServiceIconBadge(iconKey: service.iconKey, size: 34),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${service.objectName} - ${service.serviceName}'),
            ),
          ],
        ),
        subtitle: Text(
          '${service.providerName} / vence ${formatDate(service.initialDueDate)} / ${service.frequency.label}',
        ),
        trailing: Text(formatMoney(service.estimatedAmount)),
        onTap: onOpen,
      ),
    );
  }
}

class _EndServiceDecision {
  const _EndServiceDecision({
    required this.effectiveFrom,
    required this.overdueAction,
    required this.paidAt,
  });

  final DateTime effectiveFrom;
  final _OverdueAction overdueAction;
  final DateTime paidAt;
}

class _PauseServiceDecision {
  const _PauseServiceDecision({required this.from, this.until});

  final DateTime from;
  final DateTime? until;
}

class _PauseServiceDialog extends StatefulWidget {
  const _PauseServiceDialog({required this.serviceCount});

  final int serviceCount;

  @override
  State<_PauseServiceDialog> createState() => _PauseServiceDialogState();
}

class _PauseServiceDialogState extends State<_PauseServiceDialog> {
  DateTime? _from;
  DateTime? _until;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final effectiveFrom = _from ?? dateOnly(DateTime.now());
    return AlertDialog(
      title: Text(
        widget.serviceCount == 1 ? 'Pausar servicio' : 'Pausar servicios',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Las fechas son opcionales. Si no eliges "desde", se usa hoy.',
            ),
            const SizedBox(height: 12),
            _NullableDialogDateButton(
              label: 'Desde',
              value: _from,
              fallbackLabel: 'Hoy',
              onChanged: (value) => setState(() {
                _from = value;
                _error = null;
              }),
            ),
            const SizedBox(height: 8),
            _NullableDialogDateButton(
              label: 'Hasta',
              value: _until,
              fallbackLabel: 'Sin fecha',
              onChanged: (value) => setState(() {
                _until = value;
                _error = null;
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          onPressed: () {
            if (_until != null && _until!.isBefore(effectiveFrom)) {
              setState(() => _error = 'Hasta debe ser mayor o igual a desde.');
              return;
            }
            Navigator.of(
              context,
            ).pop(_PauseServiceDecision(from: effectiveFrom, until: _until));
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

class _EndServiceDialog extends StatefulWidget {
  const _EndServiceDialog({
    required this.serviceCount,
    required this.overdueCount,
  });

  final int serviceCount;
  final int overdueCount;

  @override
  State<_EndServiceDialog> createState() => _EndServiceDialogState();
}

class _EndServiceDialogState extends State<_EndServiceDialog> {
  late DateTime _effectiveFrom;
  late DateTime _paidAt;
  _OverdueAction _overdueAction = _OverdueAction.cancel;

  @override
  void initState() {
    super.initState();
    _effectiveFrom = dateOnly(DateTime.now());
    _paidAt = dateOnly(DateTime.now());
    if (widget.overdueCount == 0) {
      _overdueAction = _OverdueAction.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.serviceCount == 1 ? 'Terminar servicio' : 'Terminar servicios',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pagos vencidos encontrados: ${widget.overdueCount}.',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (widget.overdueCount > 0)
              SegmentedButton<_OverdueAction>(
                segments: const [
                  ButtonSegment(
                    value: _OverdueAction.cancel,
                    label: Text('Cancelarlos'),
                    icon: Icon(Icons.cancel_outlined),
                  ),
                  ButtonSegment(
                    value: _OverdueAction.complete,
                    label: Text('Completarlos'),
                    icon: Icon(Icons.check_circle_outline),
                  ),
                ],
                selected: {_overdueAction},
                onSelectionChanged: (value) =>
                    setState(() => _overdueAction = value.first),
              ),
            if (_overdueAction == _OverdueAction.complete) ...[
              const SizedBox(height: 12),
              _DialogDateButton(
                label: 'Fecha de pago',
                value: _paidAt,
                onChanged: (value) => setState(() => _paidAt = value),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Cancelar pagos vigentes a partir de:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _DialogDateButton(
              label: 'Fecha',
              value: _effectiveFrom,
              onChanged: (value) => setState(() => _effectiveFrom = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _EndServiceDecision(
              effectiveFrom: _effectiveFrom,
              overdueAction: _overdueAction,
              paidAt: _paidAt,
            ),
          ),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

class _DialogDateButton extends StatelessWidget {
  const _DialogDateButton({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await pickAppDate(context, initialDate: value);
        if (picked != null) onChanged(dateOnly(picked));
      },
      icon: const Icon(Icons.event_outlined),
      label: Text('$label: ${formatDate(value)}'),
    );
  }
}

class _NullableDialogDateButton extends StatelessWidget {
  const _NullableDialogDateButton({
    required this.label,
    required this.value,
    required this.fallbackLabel,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final String fallbackLabel;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await pickAppDate(context, initialDate: value);
            if (picked != null) onChanged(dateOnly(picked));
          },
          icon: const Icon(Icons.event_outlined),
          label: Text(
            '$label: ${value == null ? fallbackLabel : formatDate(value)}',
          ),
        ),
        TextButton(
          onPressed: () => onChanged(null),
          child: const Text('Limpiar'),
        ),
      ],
    );
  }
}

ServiceDraft _draftFromService(
  ServiceAccount service, {
  ServiceLifecycleStatus? status,
  DateTime? pausedFrom,
  DateTime? pauseUntil,
}) {
  final nextStatus = status ?? service.status;
  return ServiceDraft(
    active: nextStatus == ServiceLifecycleStatus.active,
    status: nextStatus,
    pausedFrom: nextStatus == ServiceLifecycleStatus.paused
        ? pausedFrom ?? dateOnly(DateTime.now())
        : nextStatus == ServiceLifecycleStatus.active
        ? null
        : service.pausedFrom,
    endedAt: nextStatus == ServiceLifecycleStatus.ended
        ? dateOnly(DateTime.now())
        : nextStatus == ServiceLifecycleStatus.active
        ? null
        : service.endedAt,
    endReason: nextStatus == ServiceLifecycleStatus.ended
        ? 'Terminado desde seleccion masiva'
        : nextStatus == ServiceLifecycleStatus.active
        ? null
        : service.endReason,
    iconKey: service.iconKey,
    objectName: service.objectName,
    serviceName: service.serviceName,
    providerName: service.providerName,
    serviceNumber: service.serviceNumber,
    providerUrl: service.providerUrl,
    isAutopay: service.isAutopay,
    chargeAccount: service.chargeAccount,
    initialCutoffDate: service.initialCutoffDate,
    initialDueDate: service.initialDueDate,
    weekendAdjustment: service.weekendAdjustment,
    frequency: service.frequency,
    intervalCount: service.intervalCount,
    estimatedAmount: service.estimatedAmount,
    currency: service.currency,
    recurrenceEndDate: service.recurrenceEndDate,
    recurrencePaymentCount: service.recurrencePaymentCount,
    notes: _notesWithPauseUntil(service.notes, pauseUntil),
  );
}

String? _notesWithPauseUntil(String? notes, DateTime? pauseUntil) {
  if (pauseUntil == null) return notes;
  final line = 'Pausa hasta ${isoDate(pauseUntil)}';
  if (notes == null || notes.trim().isEmpty) return line;
  if (notes.contains(line)) return notes;
  return '${notes.trim()}\n$line';
}

Map<String, Object?> _serviceToJson(ServiceAccount service) {
  return {
    'id': service.id,
    'active': service.active,
    'status': service.status.value,
    'icon_key': service.iconKey,
    'object_name': service.objectName,
    'service_name': service.serviceName,
    'provider_name': service.providerName,
    'service_number': service.serviceNumber,
    'provider_url': service.providerUrl,
    'is_autopay': service.isAutopay,
    'charge_account': service.chargeAccount,
    'initial_cutoff_date': service.initialCutoffDate == null
        ? null
        : isoDate(service.initialCutoffDate!),
    'initial_due_date': isoDate(service.initialDueDate),
    'weekend_adjustment': service.weekendAdjustment.value,
    'frequency': service.frequency.value,
    'interval_count': service.intervalCount,
    'estimated_amount': service.estimatedAmount,
    'currency': service.currency,
    'recurrence_end_date': service.recurrenceEndDate == null
        ? null
        : isoDate(service.recurrenceEndDate!),
    'recurrence_payment_count': service.recurrencePaymentCount,
    'notes': service.notes,
  };
}

List<int> buildServicesXlsx(List<ServiceAccount> services) {
  return buildSimpleXlsx(
    sheetName: 'Servicios',
    rows: _serviceExportRows(services),
  );
}

List<List<String>> _serviceExportRows(List<ServiceAccount> services) {
  const headers = [
    'id',
    'active',
    'status',
    'icon_key',
    'object_name',
    'service_name',
    'provider_name',
    'service_number',
    'provider_url',
    'is_autopay',
    'charge_account',
    'initial_cutoff_date',
    'initial_due_date',
    'weekend_adjustment',
    'frequency',
    'interval_count',
    'estimated_amount',
    'currency',
    'recurrence_end_date',
    'recurrence_payment_count',
    'notes',
    'last_modified_at',
    'last_modified_platform',
    'last_modified_device_id',
  ];
  return [headers, ...services.map(_serviceExportValues)];
}

String _servicesCsv(List<ServiceAccount> services) {
  final rows = [
    ..._serviceExportRows(
      services,
    ).map((values) => values.map(_csvCell).join(',')),
  ];
  return rows.join('\n');
}

List<String> _serviceExportValues(ServiceAccount service) {
  return [
    service.id,
    service.active.toString(),
    service.status.value,
    service.iconKey,
    service.objectName,
    service.serviceName,
    service.providerName,
    service.serviceNumber,
    service.providerUrl ?? '',
    service.isAutopay.toString(),
    service.chargeAccount ?? '',
    service.initialCutoffDate == null
        ? ''
        : isoDate(service.initialCutoffDate!),
    isoDate(service.initialDueDate),
    service.weekendAdjustment.value,
    service.frequency.value,
    service.intervalCount.toString(),
    service.estimatedAmount == null
        ? ''
        : formatAmount(service.estimatedAmount),
    service.currency,
    service.recurrenceEndDate == null
        ? ''
        : isoDate(service.recurrenceEndDate!),
    service.recurrencePaymentCount?.toString() ?? '',
    service.notes ?? '',
    service.lastModifiedAt?.toIso8601String() ?? '',
    service.lastModifiedPlatform ?? '',
    service.lastModifiedDeviceId ?? '',
  ];
}

String _csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
