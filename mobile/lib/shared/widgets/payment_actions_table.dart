import 'package:flutter/material.dart';

import '../../features/payments/data/payment_instance.dart';
import '../formatters.dart';
import '../icons/payment_status_icon_catalog.dart';

class PaymentActionsTable extends StatelessWidget {
  const PaymentActionsTable({
    super.key,
    required this.payments,
    required this.selectedPaymentIds,
    required this.onSelectionChanged,
    required this.onOpenDetails,
    required this.onMarkPaid,
    required this.onUnmarkPaid,
    required this.onCancel,
    this.padding = const EdgeInsets.all(16),
  });

  final List<PaymentInstance> payments;
  final Set<String> selectedPaymentIds;
  final void Function(PaymentInstance payment, bool selected)
  onSelectionChanged;
  final void Function(PaymentInstance payment) onOpenDetails;
  final void Function(PaymentInstance payment) onMarkPaid;
  final void Function(PaymentInstance payment) onUnmarkPaid;
  final void Function(PaymentInstance payment) onCancel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
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
                DataCell(
                  Text(payment.providerName),
                  onTap: () => onOpenDetails(payment),
                ),
                DataCell(
                  Text(formatDate(payment.dueDate)),
                  onTap: () => onOpenDetails(payment),
                ),
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
                  onTap: () => onOpenDetails(payment),
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
