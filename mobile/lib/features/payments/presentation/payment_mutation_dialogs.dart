import 'package:flutter/material.dart';

import '../../../shared/date_picker.dart';
import '../../../shared/formatters.dart';
import '../data/payment_instance.dart';

class MarkPaidResult {
  const MarkPaidResult({required this.paidAt, this.amount, this.paymentMethod});

  final DateTime paidAt;
  final double? amount;
  final String? paymentMethod;
}

Future<MarkPaidResult?> showMarkPaidDialog(
  BuildContext context, {
  double? initialAmount,
}) async {
  final controller = TextEditingController(
    text: initialAmount?.toString() ?? '',
  );
  final methodController = TextEditingController();
  final result = await showDialog<MarkPaidResult>(
    context: context,
    builder: (context) => _MarkPaidDialog(
      controller: controller,
      methodController: methodController,
    ),
  );
  controller.dispose();
  methodController.dispose();
  return result;
}

Future<bool> confirmCancelPayment(
  BuildContext context,
  PaymentInstance payment,
) async {
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
  return confirmed == true;
}

class _MarkPaidDialog extends StatefulWidget {
  const _MarkPaidDialog({
    required this.controller,
    required this.methodController,
  });

  final TextEditingController controller;
  final TextEditingController methodController;

  @override
  State<_MarkPaidDialog> createState() => _MarkPaidDialogState();
}

class _MarkPaidDialogState extends State<_MarkPaidDialog> {
  late DateTime _paidAt;

  @override
  void initState() {
    super.initState();
    _paidAt = dateOnly(DateTime.now());
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
            controller: widget.methodController,
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
            MarkPaidResult(
              paidAt: _paidAt,
              amount: double.tryParse(widget.controller.text.trim()),
              paymentMethod: widget.methodController.text.trim().isEmpty
                  ? null
                  : widget.methodController.text.trim(),
            ),
          ),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
