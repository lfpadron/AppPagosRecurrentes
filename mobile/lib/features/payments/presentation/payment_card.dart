import 'package:flutter/material.dart';

import '../../../shared/formatters.dart';
import '../../../shared/icons/payment_status_icon_catalog.dart';
import '../../../shared/icons/service_icon_catalog.dart';
import '../data/payment_instance.dart';

class PaymentCard extends StatelessWidget {
  const PaymentCard({
    required this.payment,
    required this.onMarkPaid,
    required this.onUnmarkPaid,
    required this.onCancel,
    this.selected = false,
    this.onSelectionChanged,
    this.onOpenDetails,
    super.key,
  });

  final PaymentInstance payment;
  final VoidCallback onMarkPaid;
  final VoidCallback onUnmarkPaid;
  final VoidCallback onCancel;
  final bool selected;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback? onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final canMutate =
        payment.status != PaymentStatus.paid &&
        payment.status != PaymentStatus.cancelled &&
        payment.status != PaymentStatus.cancelledByRecalculation &&
        payment.status != PaymentStatus.notApplicableException;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpenDetails,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: onSelectionChanged == null
                        ? null
                        : (value) => onSelectionChanged!(value ?? false),
                  ),
                  const SizedBox(width: 6),
                  ServiceIconBadge(iconKey: payment.serviceIconKey),
                  const SizedBox(width: 10),
                  PaymentStatusIconBadge(
                    status: payment.status,
                    isAutopay: payment.isAutopay,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      payment.serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(status: payment.status),
                ],
              ),
              const SizedBox(height: 8),
              _InfoLine(
                icon: Icons.location_city_outlined,
                label: 'Objeto',
                value: payment.objectName,
              ),
              const SizedBox(height: 4),
              _InfoLine(
                icon: Icons.storefront_outlined,
                label: 'Proveedor',
                value: payment.serviceNumber.trim().isEmpty
                    ? payment.providerName
                    : '${payment.providerName} / ${payment.serviceNumber}',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Fact(
                    icon: Icons.event_outlined,
                    label: 'Vence',
                    value: formatDate(payment.dueDate),
                  ),
                  _Fact(
                    icon: Icons.attach_money,
                    label: 'Estimado',
                    value: formatMoneyWithCurrency(
                      payment.estimatedAmount,
                      payment.currency,
                    ),
                  ),
                  if (payment.paidAt != null)
                    _Fact(
                      icon: Icons.check_circle_outline,
                      label: 'Pagado',
                      value:
                          '${formatMoneyWithCurrency(payment.paidAmount, payment.currency)} / ${formatDate(payment.paidAt)}',
                    ),
                  if (payment.paymentMethod != null &&
                      payment.paymentMethod!.isNotEmpty)
                    _Fact(
                      icon: Icons.credit_card_outlined,
                      label: 'Metodo',
                      value: payment.paymentMethod!,
                    ),
                ],
              ),
              if (canMutate) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: onMarkPaid,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Pagado'),
                    ),
                  ],
                ),
              ] else if (payment.status == PaymentStatus.paid) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: onUnmarkPaid,
                    icon: const Icon(Icons.undo_outlined),
                    label: const Text('Desmarcar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        SizedBox(
          width: 72,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PaymentStatus.paid => Colors.green,
      PaymentStatus.dueSoon => Colors.deepOrange,
      PaymentStatus.upcoming => Colors.amber,
      PaymentStatus.overdue ||
      PaymentStatus.autopayOverdueConfirmation => Colors.red,
      PaymentStatus.autopayPendingConfirmation ||
      PaymentStatus.autopayDueSoon => Colors.amber,
      PaymentStatus.autopayFuture => Colors.blue,
      PaymentStatus.cancelled ||
      PaymentStatus.cancelledByRecalculation => Colors.grey,
      PaymentStatus.notApplicableException => Colors.blueGrey,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(status.label),
      side: BorderSide(color: color),
      labelStyle: TextStyle(color: color),
    );
  }
}

class PaymentDetailDialog extends StatelessWidget {
  const PaymentDetailDialog({required this.payment, super.key});

  final PaymentInstance payment;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PaymentStatusIconBadge(
            status: payment.status,
            isAutopay: payment.isAutopay,
            size: 50,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${payment.objectName} - ${payment.serviceName}'),
                Text(
                  payment.status.label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailRow(label: 'Proveedor', value: payment.providerName),
            _DetailRow(label: 'Numero', value: payment.serviceNumber),
            _DetailRow(label: 'Vence', value: formatDate(payment.dueDate)),
            _DetailRow(
              label: 'Monto estimado',
              value: formatMoneyWithCurrency(
                payment.estimatedAmount,
                payment.currency,
              ),
            ),
            _DetailRow(
              label: 'Monto pagado',
              value: payment.paidAmount == null
                  ? '-'
                  : formatMoneyWithCurrency(
                      payment.paidAmount,
                      payment.currency,
                    ),
            ),
            _DetailRow(label: 'Pagado el', value: formatDate(payment.paidAt)),
            _DetailRow(
              label: 'Metodo de pago',
              value: payment.paymentMethod ?? '-',
            ),
            _DetailRow(
              label: 'Domiciliado',
              value: payment.isAutopay ? 'Si' : 'No',
            ),
            if (payment.notes != null && payment.notes!.isNotEmpty)
              _DetailRow(label: 'Notas', value: payment.notes!),
            _DetailRow(
              label: 'Modificado',
              value:
                  '${payment.lastModifiedPlatform ?? '-'} / ${formatDateTime(payment.lastModifiedAt)}',
            ),
            _DetailRow(
              label: 'Dispositivo',
              value: payment.lastModifiedDeviceId ?? '-',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text('$label: $value'),
      ],
    );
  }
}
