import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/app_preferences.dart';
import '../../../shared/dependencies.dart';
import '../../../shared/formatters.dart';
import '../../../shared/platform/app_platform.dart';
import '../../../shared/widgets/api_error_view.dart';
import '../../../shared/widgets/payment_actions_table.dart';
import '../../../shared/widgets/payment_list_view_mode_toggle.dart';
import '../../payments/data/payment_instance.dart';
import '../../payments/data/payments_api.dart';
import '../../payments/presentation/one_time_payment_dialog.dart';
import '../../payments/presentation/payment_card.dart';
import '../../payments/presentation/payment_mutation_dialogs.dart';
import '../../services/data/services_api.dart';
import '../../services/presentation/service_form_dialog.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<List<PaymentInstance>> _future;
  _AgendaFilter _agendaFilter = _AgendaFilter.all;
  final Set<String> _selectedPaymentIds = {};

  PaymentsApi get _paymentsApi => DependenciesScope.of(context).paymentsApi;
  ServicesApi get _servicesApi => DependenciesScope.of(context).servicesApi;

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

  void _load() {
    final today = dateOnly(DateTime.now());
    setState(() {
      _selectedPaymentIds.clear();
      _future = _paymentsApi.listPayments(
        startDate: today.subtract(const Duration(days: 90)),
        endDate: today.add(const Duration(days: 7)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagos recurrentes')),
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
          final overdue = payments
              .where((payment) => payment.status == PaymentStatus.overdue)
              .toList();
          final confirm = payments
              .where(
                (payment) =>
                    payment.status ==
                        PaymentStatus.autopayPendingConfirmation ||
                    payment.status == PaymentStatus.autopayOverdueConfirmation,
              )
              .toList();
          final upcoming = payments
              .where((payment) => _isImmediateUpcoming(payment))
              .toList();
          final agendaPayments = _dedupeAgenda([
            ...overdue,
            ...confirm,
            ...upcoming,
          ]);

          final displayedPayments = switch (_agendaFilter) {
            _AgendaFilter.overdue => overdue,
            _AgendaFilter.confirm => confirm,
            _AgendaFilter.upcoming => upcoming,
            _AgendaFilter.all => agendaPayments,
          };
          final compactMetrics = isAndroidApp;
          final metricWidth = compactMetrics
              ? ((MediaQuery.sizeOf(context).width - 44) / 2)
                    .clamp(132.0, 190.0)
                    .toDouble()
              : 190.0;

          return AnimatedBuilder(
            animation: AppPreferences.instance,
            builder: (context, _) {
              final useCards =
                  isAndroidApp &&
                  AppPreferences.instance.paymentListViewMode ==
                      PaymentListViewMode.cards;
              return RefreshIndicator(
                onRefresh: () async => _load(),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MetricCard(
                          icon: Icons.warning_amber_outlined,
                          label: 'Vencidos',
                          value: overdue.length.toString(),
                          width: metricWidth,
                          compact: compactMetrics,
                          selected: _agendaFilter == _AgendaFilter.overdue,
                          onTap: () => setState(
                            () => _agendaFilter = _AgendaFilter.overdue,
                          ),
                        ),
                        _MetricCard(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Por confirmar',
                          value: confirm.length.toString(),
                          width: metricWidth,
                          compact: compactMetrics,
                          selected: _agendaFilter == _AgendaFilter.confirm,
                          onTap: () => setState(
                            () => _agendaFilter = _AgendaFilter.confirm,
                          ),
                        ),
                        _MetricCard(
                          icon: Icons.event_available_outlined,
                          label: 'Proximos 7 dias',
                          value: upcoming.length.toString(),
                          width: metricWidth,
                          compact: compactMetrics,
                          selected: _agendaFilter == _AgendaFilter.upcoming,
                          onTap: () => setState(
                            () => _agendaFilter = _AgendaFilter.upcoming,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _createService,
                            icon: const Icon(Icons.add_business_outlined),
                            label: const Text('Crear servicio'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _createOneTime,
                            icon: const Icon(Icons.add_card_outlined),
                            label: const Text('Pago unico'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Agenda inmediata',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _agendaFilter = _AgendaFilter.all),
                          icon: const Icon(Icons.view_list_outlined),
                          label: const Text('Ver todo'),
                        ),
                      ],
                    ),
                    if (isAndroidApp) ...[
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: PaymentListViewModeToggle(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (payments.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('Sin pagos en la ventana actual.'),
                        ),
                      )
                    else if (displayedPayments.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('Sin pagos para este atajo.'),
                        ),
                      )
                    else if (useCards)
                      ...displayedPayments.map(
                        (payment) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: PaymentCard(
                            payment: payment,
                            selected: _selectedPaymentIds.contains(payment.id),
                            onSelectionChanged: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedPaymentIds.add(payment.id);
                                } else {
                                  _selectedPaymentIds.remove(payment.id);
                                }
                              });
                            },
                            onOpenDetails: () => _openDetails(payment),
                            onMarkPaid: () => _markPaid(payment),
                            onUnmarkPaid: () => _unmarkPaid(payment),
                            onCancel: () => _cancel(payment),
                          ),
                        ),
                      )
                    else
                      Card(
                        child: PaymentActionsTable(
                          payments: displayedPayments,
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
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createService() async {
    final draft = await showDialog<ServiceDraft>(
      context: context,
      builder: (_) => const ServiceFormDialog(),
    );
    if (draft == null) return;
    try {
      await _servicesApi.createService(draft);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Servicio creado')));
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

  Future<void> _createOneTime() async {
    final draft = await showDialog<OneTimePaymentDraft>(
      context: context,
      builder: (_) => const OneTimePaymentDialog(),
    );
    if (draft == null) return;
    try {
      await _paymentsApi.createOneTime(draft);
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

  Future<void> _markPaid(PaymentInstance payment) async {
    final result = await showMarkPaidDialog(
      context,
      initialAmount: payment.estimatedAmount,
    );
    if (result == null) return;
    try {
      await _paymentsApi.markPaid(
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

  Future<void> _unmarkPaid(PaymentInstance payment) async {
    try {
      await _paymentsApi.unmarkPaid(payment.id);
      _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _cancel(PaymentInstance payment) async {
    if (!await confirmCancelPayment(context, payment)) return;
    try {
      await _paymentsApi.cancel(payment.id, reason: 'Cancelado desde inicio');
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

enum _AgendaFilter { all, overdue, confirm, upcoming }

bool _isImmediateUpcoming(PaymentInstance payment) {
  if (payment.status == PaymentStatus.dueSoon ||
      payment.status == PaymentStatus.autopayDueSoon) {
    return true;
  }
  if (payment.status != PaymentStatus.pending &&
      payment.status != PaymentStatus.active) {
    return false;
  }
  final today = dateOnly(DateTime.now());
  final due = dateOnly(payment.dueDate);
  return !due.isBefore(today) &&
      !due.isAfter(today.add(const Duration(days: 7)));
}

List<PaymentInstance> _dedupeAgenda(List<PaymentInstance> payments) {
  final seen = <String>{};
  final result = <PaymentInstance>[];
  for (final payment in payments) {
    if (seen.add(payment.id)) {
      result.add(payment);
    }
  }
  result.sort((a, b) {
    final due = a.dueDate.compareTo(b.dueDate);
    if (due != 0) return due;
    return _agendaPriority(a.status).compareTo(_agendaPriority(b.status));
  });
  return result;
}

int _agendaPriority(PaymentStatus status) => switch (status) {
  PaymentStatus.overdue => 0,
  PaymentStatus.autopayPendingConfirmation ||
  PaymentStatus.autopayOverdueConfirmation => 1,
  PaymentStatus.dueSoon || PaymentStatus.autopayDueSoon => 2,
  _ => 9,
};

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.width,
    this.compact = false,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final double width;
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? 10 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: compact ? 20 : null,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(height: compact ? 6 : 12),
                Text(
                  value,
                  style: compact
                      ? Theme.of(context).textTheme.titleLarge
                      : Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  label,
                  maxLines: compact ? 2 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
