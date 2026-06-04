import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/app_preferences.dart';
import '../../../shared/dependencies.dart';
import '../../../shared/date_picker.dart';
import '../../../shared/formatters.dart';
import '../../../shared/icons/payment_status_icon_catalog.dart';
import '../../../shared/platform/app_platform.dart';
import '../../../shared/service_currency_options.dart';
import '../../../shared/widgets/api_error_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/payment_actions_table.dart';
import '../../../shared/widgets/payment_list_view_mode_toggle.dart';
import '../data/payment_instance.dart';
import '../data/payments_api.dart';
import '../../services/data/service_account.dart';
import 'one_time_payment_dialog.dart';
import 'payment_card.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  late Future<List<PaymentInstance>> _future;
  late Future<List<ServiceAccount>> _servicesFuture;
  PaymentStatus? _statusFilter;
  String? _serviceAccountIdFilter;
  DateTime? _startDateFilter;
  DateTime? _endDateFilter;
  String? _currencyFilter;
  int _pageOffset = 0;
  static const _pageSize = 90;
  final _objectNameController = TextEditingController();
  final Set<String> _selectedPaymentIds = {};

  PaymentsApi get _api => DependenciesScope.of(context).paymentsApi;

  @override
  void initState() {
    super.initState();
    _future = Future.value(const []);
    _servicesFuture = Future.value(const []);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _servicesFuture = DependenciesScope.of(
      context,
    ).servicesApi.listAllServices();
    _load();
  }

  @override
  void dispose() {
    _objectNameController.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _future = _api.listPayments(
        status: _statusFilter,
        serviceAccountId: _serviceAccountIdFilter,
        objectName: _objectNameController.text.trim().isEmpty
            ? null
            : _objectNameController.text.trim(),
        currency: _currencyFilter,
        startDate: _startDateFilter,
        endDate: _endDateFilter,
        limit: _pageSize,
        offset: _pageOffset,
      );
    });
  }

  void _reloadFromStart() {
    _pageOffset = 0;
    _selectedPaymentIds.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagos'),
        actions: [
          PopupMenuButton<PaymentStatus?>(
            icon: const Icon(Icons.filter_list),
            initialValue: _statusFilter,
            onSelected: (value) {
              _statusFilter = value;
              _load();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('Todos')),
              ...quickPaymentStatuses.map(
                (status) =>
                    PopupMenuItem(value: status, child: Text(status.label)),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openOneTimeDialog,
        icon: const Icon(Icons.add_card_outlined),
        label: const Text('Pago unico'),
      ),
      body: FutureBuilder<List<PaymentInstance>>(
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
          final payments = snapshot.data ?? const [];
          final filters = _PaymentFilters(
            servicesFuture: _servicesFuture,
            selectedServiceId: _serviceAccountIdFilter,
            selectedStatus: _statusFilter,
            objectNameController: _objectNameController,
            selectedCurrency: _currencyFilter,
            startDate: _startDateFilter,
            endDate: _endDateFilter,
            onServiceChanged: (value) {
              _serviceAccountIdFilter = value;
              _reloadFromStart();
            },
            onStatusChanged: (value) {
              _statusFilter = value;
              _reloadFromStart();
            },
            onStartDateChanged: (value) {
              _startDateFilter = value;
              _reloadFromStart();
            },
            onEndDateChanged: (value) {
              _endDateFilter = value;
              _reloadFromStart();
            },
            onCurrencyChanged: (value) {
              _currencyFilter = value;
              _reloadFromStart();
            },
            onApply: _reloadFromStart,
            onClear: () {
              _serviceAccountIdFilter = null;
              _statusFilter = null;
              _startDateFilter = null;
              _endDateFilter = null;
              _currencyFilter = null;
              _objectNameController.clear();
              _reloadFromStart();
            },
          );
          final bulkBar = _PaymentBulkBar(
            selectedCount: payments
                .where((payment) => _selectedPaymentIds.contains(payment.id))
                .length,
            pageOffset: _pageOffset,
            pageSize: _pageSize,
            pageCount: payments.length,
            onPrevious: _pageOffset == 0
                ? null
                : () {
                    _pageOffset = (_pageOffset - _pageSize)
                        .clamp(0, 1 << 31)
                        .toInt();
                    _selectedPaymentIds.clear();
                    _load();
                  },
            onNext: payments.length < _pageSize
                ? null
                : () {
                    _pageOffset += _pageSize;
                    _selectedPaymentIds.clear();
                    _load();
                  },
            onMarkPaid: _selectedPaymentIds.isEmpty
                ? null
                : () => _markSelectedPaid(payments),
            onUnmarkPaid: _selectedPaymentIds.isEmpty
                ? null
                : () => _unmarkSelectedPaid(payments),
          );
          if (isAndroidApp) {
            return AnimatedBuilder(
              animation: AppPreferences.instance,
              builder: (context, _) {
                final useTable =
                    AppPreferences.instance.paymentListViewMode ==
                    PaymentListViewMode.table;
                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      filters,
                      bulkBar,
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PaymentListViewModeToggle(),
                        ),
                      ),
                      if (payments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 48, 16, 16),
                          child: EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Sin pagos',
                            message:
                                'No hay pagos para los filtros seleccionados.',
                          ),
                        )
                      else if (useTable)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Card(
                            child: PaymentActionsTable(
                              payments: payments,
                              selectedPaymentIds: _selectedPaymentIds,
                              padding: EdgeInsets.zero,
                              onSelectionChanged: (payment, selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedPaymentIds.add(payment.id);
                                  } else {
                                    _selectedPaymentIds.remove(payment.id);
                                  }
                                });
                              },
                              onOpenDetails: _openDetails,
                              onMarkPaid: _markPaid,
                              onUnmarkPaid: _unmarkPaid,
                              onCancel: _cancel,
                            ),
                          ),
                        )
                      else
                        ...payments.map(
                          (payment) => Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: PaymentCard(
                              payment: payment,
                              selected: _selectedPaymentIds.contains(
                                payment.id,
                              ),
                              onSelectionChanged: (selected) => setState(() {
                                if (selected) {
                                  _selectedPaymentIds.add(payment.id);
                                } else {
                                  _selectedPaymentIds.remove(payment.id);
                                }
                              }),
                              onOpenDetails: () => _openDetails(payment),
                              onMarkPaid: () => _markPaid(payment),
                              onUnmarkPaid: () => _unmarkPaid(payment),
                              onCancel: () => _cancel(payment),
                            ),
                          ),
                        ),
                      const SizedBox(height: 88),
                    ],
                  ),
                );
              },
            );
          }
          return Column(
            children: [
              filters,
              bulkBar,
              Expanded(
                child: payments.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Sin pagos',
                        message: 'No hay pagos para los filtros seleccionados.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _load(),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 780) {
                              return _PaymentsTable(
                                payments: payments,
                                selectedPaymentIds: _selectedPaymentIds,
                                onSelectionChanged: (payment, selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedPaymentIds.add(payment.id);
                                    } else {
                                      _selectedPaymentIds.remove(payment.id);
                                    }
                                  });
                                },
                                onOpenDetails: _openDetails,
                                onMarkPaid: _markPaid,
                                onUnmarkPaid: _unmarkPaid,
                                onCancel: _cancel,
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: payments.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final payment = payments[index];
                                return PaymentCard(
                                  payment: payment,
                                  selected: _selectedPaymentIds.contains(
                                    payment.id,
                                  ),
                                  onSelectionChanged: (selected) => setState(
                                    () {
                                      if (selected) {
                                        _selectedPaymentIds.add(payment.id);
                                      } else {
                                        _selectedPaymentIds.remove(payment.id);
                                      }
                                    },
                                  ),
                                  onOpenDetails: () => _openDetails(payment),
                                  onMarkPaid: () => _markPaid(payment),
                                  onUnmarkPaid: () => _unmarkPaid(payment),
                                  onCancel: () => _cancel(payment),
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

  Future<void> _openOneTimeDialog() async {
    final draft = await showDialog<OneTimePaymentDraft>(
      context: context,
      builder: (_) => const OneTimePaymentDialog(),
    );
    if (draft == null) return;
    try {
      await _api.createOneTime(draft);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pago unico creado')));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _openDetails(PaymentInstance payment) async {
    await showDialog<void>(
      context: context,
      builder: (_) => PaymentDetailDialog(payment: payment),
    );
  }

  Future<void> _markPaid(PaymentInstance payment) async {
    final result = await _showMarkPaidDialog(
      initialAmount: payment.estimatedAmount,
    );
    if (result == null) return;
    try {
      await _api.markPaid(
        payment.id,
        paidAmount: result.amount,
        paidAt: result.paidAt,
        paymentMethod: result.paymentMethod,
      );
      _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<_MarkPaidResult?> _showMarkPaidDialog({double? initialAmount}) async {
    final controller = TextEditingController(
      text: initialAmount?.toString() ?? '',
    );
    final result = await showDialog<_MarkPaidResult>(
      context: context,
      builder: (context) => _MarkPaidDialog(controller: controller),
    );
    controller.dispose();
    return result;
  }

  Future<void> _markSelectedPaid(List<PaymentInstance> payments) async {
    final selected = payments
        .where((payment) => _selectedPaymentIds.contains(payment.id))
        .where((payment) => _canMarkPaid(payment))
        .toList();
    if (selected.isEmpty) return;
    final paidAt = await _showDateOnlyDialog(
      title: 'Marcar seleccionados',
      label: 'Fecha de pago',
    );
    if (paidAt == null) return;
    try {
      for (final payment in selected) {
        await _api.markPaid(
          payment.id,
          paidAmount: payment.estimatedAmount,
          paidAt: paidAt,
        );
      }
      _selectedPaymentIds.clear();
      _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _unmarkPaid(PaymentInstance payment) async {
    try {
      await _api.unmarkPaid(payment.id);
      _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _unmarkSelectedPaid(List<PaymentInstance> payments) async {
    final selected = payments
        .where((payment) => _selectedPaymentIds.contains(payment.id))
        .where((payment) => payment.status == PaymentStatus.paid)
        .toList();
    if (selected.isEmpty) return;
    try {
      for (final payment in selected) {
        await _api.unmarkPaid(payment.id);
      }
      _selectedPaymentIds.clear();
      _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<DateTime?> _showDateOnlyDialog({
    required String title,
    required String label,
  }) async {
    var value = dateOnly(DateTime.now());
    return showDialog<DateTime>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: OutlinedButton.icon(
            onPressed: () async {
              final picked = await pickAppDate(context, initialDate: value);
              if (picked != null) {
                setDialogState(() => value = dateOnly(picked));
              }
            },
            icon: const Icon(Icons.event_outlined),
            label: Text('$label: ${formatDate(value)}'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(value),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  bool _canMarkPaid(PaymentInstance payment) {
    return payment.status != PaymentStatus.paid &&
        payment.status != PaymentStatus.cancelled &&
        payment.status != PaymentStatus.cancelledByRecalculation &&
        payment.status != PaymentStatus.notApplicableException;
  }

  Future<void> _cancel(PaymentInstance payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar pago'),
        content: Text('Cancelar ${payment.serviceName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Si'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.cancel(payment.id, reason: 'Cancelado desde Flutter');
      _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _MarkPaidResult {
  const _MarkPaidResult({
    required this.paidAt,
    this.amount,
    this.paymentMethod,
  });

  final DateTime paidAt;
  final double? amount;
  final String? paymentMethod;
}

class _MarkPaidDialog extends StatefulWidget {
  const _MarkPaidDialog({required this.controller});

  final TextEditingController controller;

  @override
  State<_MarkPaidDialog> createState() => _MarkPaidDialogState();
}

class _MarkPaidDialogState extends State<_MarkPaidDialog> {
  late DateTime _paidAt;
  late final TextEditingController _methodController;

  @override
  void initState() {
    super.initState();
    _paidAt = dateOnly(DateTime.now());
    _methodController = TextEditingController();
  }

  @override
  void dispose() {
    _methodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Marcar pagado'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Monto pagado'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _methodController,
            maxLength: 50,
            decoration: const InputDecoration(
              labelText: 'Metodo de pago',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await pickAppDate(context, initialDate: _paidAt);
              if (picked != null) {
                setState(() => _paidAt = dateOnly(picked));
              }
            },
            icon: const Icon(Icons.event_outlined),
            label: Text('Fecha: ${formatDate(_paidAt)}'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _MarkPaidResult(
              paidAt: _paidAt,
              amount: double.tryParse(widget.controller.text.trim()),
              paymentMethod: _methodController.text.trim().isEmpty
                  ? null
                  : _methodController.text.trim(),
            ),
          ),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

class _PaymentBulkBar extends StatelessWidget {
  const _PaymentBulkBar({
    required this.selectedCount,
    required this.pageOffset,
    required this.pageSize,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
    required this.onMarkPaid,
    required this.onUnmarkPaid,
  });

  final int selectedCount;
  final int pageOffset;
  final int pageSize;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onUnmarkPaid;

  @override
  Widget build(BuildContext context) {
    final start = pageCount == 0 ? 0 : pageOffset + 1;
    final end = pageOffset + pageCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Mostrando $start-$end / pagina de $pageSize'),
          if (selectedCount > 0) Text('$selectedCount seleccionados'),
          FilledButton.tonalIcon(
            onPressed: onMarkPaid,
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Marcar pagados'),
          ),
          OutlinedButton.icon(
            onPressed: onUnmarkPaid,
            icon: const Icon(Icons.undo_outlined),
            label: const Text('Desmarcar'),
          ),
          IconButton(
            tooltip: 'Pagina anterior',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Pagina siguiente',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _PaymentFilters extends StatelessWidget {
  const _PaymentFilters({
    required this.servicesFuture,
    required this.selectedServiceId,
    required this.selectedStatus,
    required this.objectNameController,
    required this.selectedCurrency,
    required this.startDate,
    required this.endDate,
    required this.onServiceChanged,
    required this.onStatusChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onCurrencyChanged,
    required this.onApply,
    required this.onClear,
  });

  final Future<List<ServiceAccount>> servicesFuture;
  final String? selectedServiceId;
  final PaymentStatus? selectedStatus;
  final TextEditingController objectNameController;
  final String? selectedCurrency;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<String?> onServiceChanged;
  final ValueChanged<PaymentStatus?> onStatusChanged;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<String?> onCurrencyChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

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
              width: 230,
              child: FutureBuilder<List<ServiceAccount>>(
                future: servicesFuture,
                builder: (context, snapshot) {
                  final services = snapshot.data ?? const <ServiceAccount>[];
                  final selectedServiceValue =
                      selectedServiceId != null &&
                          services.any(
                            (service) => service.id == selectedServiceId,
                          )
                      ? selectedServiceId!
                      : '';
                  return DropdownButtonFormField<String>(
                    initialValue: selectedServiceValue,
                    isExpanded: true,
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
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        onServiceChanged(value == '' ? null : value),
                  );
                },
              ),
            ),
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<String>(
                initialValue: selectedStatus?.value ?? '',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Todos')),
                  ...quickPaymentStatuses.map(
                    (status) => DropdownMenuItem(
                      value: status.value,
                      child: Text(status.label),
                    ),
                  ),
                ],
                onChanged: (value) => onStatusChanged(
                  value == null || value.isEmpty
                      ? null
                      : parsePaymentStatus(value),
                ),
              ),
            ),
            SizedBox(
              width: 190,
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
              width: 150,
              child: FutureBuilder<List<ServiceAccount>>(
                future: servicesFuture,
                builder: (context, snapshot) {
                  final currencies = serviceCurrencyOptions(
                    snapshot.data ?? const <ServiceAccount>[],
                  );
                  final selectedCurrencyValue =
                      selectedCurrency != null &&
                          currencies.contains(selectedCurrency)
                      ? selectedCurrency!
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
                    onChanged: (value) => onCurrencyChanged(
                      value == null || value.isEmpty ? null : value,
                    ),
                  );
                },
              ),
            ),
            _DateFilterButton(
              label: 'Desde',
              value: startDate,
              onChanged: onStartDateChanged,
            ),
            _DateFilterButton(
              label: 'Hasta',
              value: endDate,
              onChanged: onEndDateChanged,
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
          ],
        ),
      ),
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await pickAppDate(context, initialDate: value);
        if (picked != null) {
          onChanged(dateOnly(picked));
        }
      },
      onLongPress: () => onChanged(null),
      icon: const Icon(Icons.event_outlined),
      label: Text('$label: ${formatDate(value)}'),
    );
  }
}

class _PaymentsTable extends StatelessWidget {
  const _PaymentsTable({
    required this.payments,
    required this.selectedPaymentIds,
    required this.onSelectionChanged,
    required this.onOpenDetails,
    required this.onMarkPaid,
    required this.onUnmarkPaid,
    required this.onCancel,
  });

  final List<PaymentInstance> payments;
  final Set<String> selectedPaymentIds;
  final void Function(PaymentInstance payment, bool selected)
  onSelectionChanged;
  final void Function(PaymentInstance payment) onOpenDetails;
  final void Function(PaymentInstance payment) onMarkPaid;
  final void Function(PaymentInstance payment) onUnmarkPaid;
  final void Function(PaymentInstance payment) onCancel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: true,
          columns: const [
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Servicio')),
            DataColumn(label: Text('Proveedor')),
            DataColumn(label: Text('Vence')),
            DataColumn(label: Text('Estimado')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: payments.map((payment) {
            final canMutate =
                payment.status != PaymentStatus.paid &&
                payment.status != PaymentStatus.cancelled &&
                payment.status != PaymentStatus.cancelledByRecalculation &&
                payment.status != PaymentStatus.notApplicableException;
            return DataRow(
              selected: selectedPaymentIds.contains(payment.id),
              onSelectChanged: (selected) =>
                  onSelectionChanged(payment, selected ?? false),
              cells: [
                DataCell(
                  PaymentStatusIconBadge(
                    status: payment.status,
                    isAutopay: payment.isAutopay,
                    size: 34,
                  ),
                  onTap: () => onOpenDetails(payment),
                ),
                DataCell(
                  Text('${payment.objectName} - ${payment.serviceName}'),
                  onTap: () => onOpenDetails(payment),
                ),
                DataCell(Text(payment.providerName)),
                DataCell(Text(formatDate(payment.dueDate))),
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatMoneyWithCurrency(
                          payment.estimatedAmount,
                          payment.currency,
                        ),
                      ),
                      if (payment.status == PaymentStatus.paid)
                        Text(
                          'Pagado: ${formatMoneyWithCurrency(payment.paidAmount, payment.currency)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Detalle',
                        onPressed: () => onOpenDetails(payment),
                        icon: const Icon(Icons.open_in_new),
                      ),
                      IconButton(
                        tooltip: 'Marcar pagado',
                        onPressed: canMutate ? () => onMarkPaid(payment) : null,
                        icon: const Icon(Icons.payments_outlined),
                      ),
                      IconButton(
                        tooltip: 'Desmarcar pagado',
                        onPressed: payment.status == PaymentStatus.paid
                            ? () => onUnmarkPaid(payment)
                            : null,
                        icon: const Icon(Icons.undo_outlined),
                      ),
                      IconButton(
                        tooltip: 'Cancelar',
                        onPressed: canMutate ? () => onCancel(payment) : null,
                        icon: const Icon(Icons.cancel_outlined),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
