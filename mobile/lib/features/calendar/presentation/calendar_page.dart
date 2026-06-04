import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/dependencies.dart';
import '../../../shared/app_preferences.dart';
import '../../../shared/formatters.dart';
import '../../../shared/icons/payment_status_icon_catalog.dart';
import '../../../shared/platform/app_platform.dart';
import '../../../shared/widgets/api_error_view.dart';
import '../../../shared/widgets/payment_actions_table.dart';
import '../../../shared/widgets/payment_list_view_mode_toggle.dart';
import '../../calendar/data/calendar_api.dart';
import '../../payments/data/payment_instance.dart';
import '../../payments/data/payments_api.dart';
import '../../payments/presentation/payment_card.dart';
import '../../payments/presentation/payment_mutation_dialogs.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;
  DateTime? _selectedDay;
  late Future<CalendarResponse> _future;
  final Set<String> _selectedPaymentIds = {};

  CalendarApi get _api => DependenciesScope.of(context).calendarApi;
  PaymentsApi get _paymentsApi => DependenciesScope.of(context).paymentsApi;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _future = Future.value(
      CalendarResponse(startDate: _month, endDate: _month, days: const []),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    final start = DateTime(_month.year, _month.month);
    final end = DateTime(_month.year, _month.month + 1, 0);
    setState(() {
      _selectedPaymentIds.clear();
      _future = _api.getCalendar(startDate: start, endDate: end);
    });
  }

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selectedDay = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: FutureBuilder<CalendarResponse>(
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
          final response = snapshot.data!;
          final byDate = {
            for (final day in response.days) isoDate(day.date): day.payments,
          };
          final selectedPayments = _selectedDay == null
              ? const <PaymentInstance>[]
              : byDate[isoDate(_selectedDay!)] ?? const [];

          return AnimatedBuilder(
            animation: AppPreferences.instance,
            builder: (context, _) {
              final useCards =
                  isAndroidApp &&
                  AppPreferences.instance.paymentListViewMode ==
                      PaymentListViewMode.cards;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Mes anterior',
                        onPressed: () => _moveMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            AppPreferences.instance.monthLabel(_month),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Mes siguiente',
                        onPressed: () => _moveMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _MonthGrid(
                    month: _month,
                    paymentsByDate: byDate,
                    selectedDay: _selectedDay,
                    onSelected: (day) => setState(() => _selectedDay = day),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedDay == null
                        ? 'Selecciona un dia'
                        : 'Pagos de ${formatDate(_selectedDay)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (isAndroidApp) ...[
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: PaymentListViewModeToggle(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (selectedPayments.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Sin pagos para este dia.'),
                      ),
                    )
                  else if (useCards)
                    ...selectedPayments.map(
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
                        payments: selectedPayments,
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
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openDetails(PaymentInstance payment) async {
    await showDialog<void>(
      context: context,
      builder: (_) => PaymentDetailDialog(payment: payment),
    );
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
      await _paymentsApi.cancel(
        payment.id,
        reason: 'Cancelado desde calendario',
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
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.paymentsByDate,
    required this.selectedDay,
    required this.onSelected,
  });

  final DateTime month;
  final Map<String, List<PaymentInstance>> paymentsByDate;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final prefs = AppPreferences.instance;
    final offset = prefs.monthGridOffset(first);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                for (final label in prefs.weekdayLabels) _Weekday(label),
              ],
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 42,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final dayNumber = index - offset + 1;
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox.shrink();
                }
                final day = DateTime(month.year, month.month, dayNumber);
                final payments = paymentsByDate[isoDate(day)] ?? const [];
                final selected =
                    selectedDay != null &&
                    isoDate(selectedDay!) == isoDate(day);
                return Padding(
                  padding: const EdgeInsets.all(3),
                  child: _CalendarDayTile(
                    dayNumber: dayNumber,
                    day: day,
                    payments: payments,
                    selected: selected,
                    onTap: () => onSelected(day),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDayTile extends StatelessWidget {
  const _CalendarDayTile({
    required this.dayNumber,
    required this.day,
    required this.payments,
    required this.selected,
    required this.onTap,
  });

  final int dayNumber;
  final DateTime day;
  final List<PaymentInstance> payments;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final groups = _calendarGroupsForDay(day, payments);
    final urgent = groups.isEmpty ? null : groups.first.signal;
    final tone = urgent?.tone ?? _CalendarTone.neutral;
    final visibleGroups = groups.take(3).toList();
    final hasOverflow = groups.length > visibleGroups.length;
    final compactAndroid = isAndroidApp;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tone.fill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tone.border, width: selected ? 2.2 : 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Stack(
              children: [
                if (urgent != null)
                  Align(
                    alignment: compactAndroid
                        ? Alignment.center
                        : Alignment.topLeft,
                    child: PaymentStatusIconBadge(
                      status: urgent.status,
                      isAutopay: urgent.isAutopay,
                      size: compactAndroid ? 28 : 25,
                      showBackground: false,
                    ),
                  ),
                Align(
                  alignment: Alignment.topRight,
                  child: Text(
                    '$dayNumber',
                    style: TextStyle(
                      color: payments.isEmpty
                          ? const Color(0xFF707570)
                          : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!compactAndroid)
                  Align(
                    alignment: Alignment.center,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        for (final group in visibleGroups)
                          _CalendarGroupCount(group: group),
                        if (hasOverflow)
                          const Tooltip(
                            message: 'Mas tipos de pago',
                            child: Icon(Icons.add_circle_outline, size: 15),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarGroupCount extends StatelessWidget {
  const _CalendarGroupCount({required this.group});

  final _CalendarGroup group;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PaymentStatusIconBadge(
          status: group.signal.status,
          isAutopay: group.signal.isAutopay,
          size: 15,
          showBackground: false,
        ),
        const SizedBox(width: 2),
        Text(
          '${group.count}',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CalendarGroup {
  const _CalendarGroup({required this.signal, required this.count});

  final _CalendarSignal signal;
  final int count;
}

class _CalendarSignal {
  const _CalendarSignal({
    required this.status,
    required this.isAutopay,
    required this.priority,
    required this.tone,
  });

  final PaymentStatus status;
  final bool isAutopay;
  final int priority;
  final _CalendarTone tone;
}

class _CalendarTone {
  const _CalendarTone({required this.fill, required this.border});

  final Color fill;
  final Color border;

  static const neutral = _CalendarTone(
    fill: Color(0xFFF2F3F2),
    border: Color(0xFFC8CCC8),
  );
  static const red = _CalendarTone(
    fill: Color(0xFFFFECEB),
    border: Color(0xFFE86B65),
  );
  static const orange = _CalendarTone(
    fill: Color(0xFFFFF0DF),
    border: Color(0xFFFF9800),
  );
  static const yellow = _CalendarTone(
    fill: Color(0xFFFFF8DD),
    border: Color(0xFFE1B400),
  );
  static const blue = _CalendarTone(
    fill: Color(0xFFEAF3FF),
    border: Color(0xFF5D9CEC),
  );
  static const green = _CalendarTone(
    fill: Color(0xFFEAF7EC),
    border: Color(0xFF66BB6A),
  );
}

List<_CalendarGroup> _calendarGroupsForDay(
  DateTime day,
  List<PaymentInstance> payments,
) {
  final counts = <({PaymentStatus status, bool isAutopay}), int>{};
  for (final payment in payments) {
    final signal = _calendarSignalForPayment(day, payment);
    final key = (status: signal.status, isAutopay: signal.isAutopay);
    counts[key] = (counts[key] ?? 0) + 1;
  }

  final groups =
      counts.entries
          .map(
            (entry) => _CalendarGroup(
              signal: _calendarSignalForKey(
                day,
                entry.key.status,
                entry.key.isAutopay,
              ),
              count: entry.value,
            ),
          )
          .toList()
        ..sort((a, b) => a.signal.priority.compareTo(b.signal.priority));
  return groups;
}

_CalendarSignal _calendarSignalForPayment(
  DateTime day,
  PaymentInstance payment,
) {
  return _calendarSignalForKey(day, payment.status, payment.isAutopay);
}

_CalendarSignal _calendarSignalForKey(
  DateTime day,
  PaymentStatus status,
  bool isAutopay,
) {
  final today = dateOnly(DateTime.now());
  final past = day.isBefore(today);

  if (status == PaymentStatus.paid) {
    return _CalendarSignal(
      status: PaymentStatus.paid,
      isAutopay: isAutopay,
      priority: past ? 30 : 50,
      tone: _CalendarTone.green,
    );
  }

  if (status == PaymentStatus.overdue) {
    return const _CalendarSignal(
      status: PaymentStatus.overdue,
      isAutopay: false,
      priority: 0,
      tone: _CalendarTone.red,
    );
  }

  if (status == PaymentStatus.autopayPendingConfirmation ||
      status == PaymentStatus.autopayOverdueConfirmation) {
    return const _CalendarSignal(
      status: PaymentStatus.autopayPendingConfirmation,
      isAutopay: true,
      priority: 10,
      tone: _CalendarTone.yellow,
    );
  }

  if (status == PaymentStatus.dueSoon) {
    return const _CalendarSignal(
      status: PaymentStatus.dueSoon,
      isAutopay: false,
      priority: 0,
      tone: _CalendarTone.orange,
    );
  }

  if (status == PaymentStatus.upcoming) {
    return const _CalendarSignal(
      status: PaymentStatus.upcoming,
      isAutopay: false,
      priority: 10,
      tone: _CalendarTone.yellow,
    );
  }

  if (status == PaymentStatus.autopayDueSoon) {
    return const _CalendarSignal(
      status: PaymentStatus.autopayDueSoon,
      isAutopay: true,
      priority: 12,
      tone: _CalendarTone.yellow,
    );
  }

  if (status == PaymentStatus.future || status == PaymentStatus.autopayFuture) {
    return _CalendarSignal(
      status: status,
      isAutopay: status == PaymentStatus.autopayFuture || isAutopay,
      priority: past ? 40 : 30,
      tone: _CalendarTone.blue,
    );
  }

  return _CalendarSignal(
    status: status,
    isAutopay: isAutopay,
    priority: 90,
    tone: _CalendarTone.neutral,
  );
}

class _Weekday extends StatelessWidget {
  const _Weekday(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
