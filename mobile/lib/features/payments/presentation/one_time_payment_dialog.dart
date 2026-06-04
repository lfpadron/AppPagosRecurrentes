import 'package:flutter/material.dart';

import '../../../shared/date_picker.dart';
import '../../../shared/app_preferences.dart';
import '../../../shared/formatters.dart';
import '../../../shared/icons/service_icon_catalog.dart';
import '../data/payments_api.dart';

class OneTimePaymentDialog extends StatefulWidget {
  const OneTimePaymentDialog({super.key});

  @override
  State<OneTimePaymentDialog> createState() => _OneTimePaymentDialogState();
}

class _OneTimePaymentDialogState extends State<OneTimePaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _objectController = TextEditingController();
  final _serviceController = TextEditingController();
  final _providerController = TextEditingController();
  final _numberController = TextEditingController();
  final _amountController = TextEditingController();
  late final TextEditingController _currencyController;
  final _notesController = TextEditingController();
  late DateTime _dueDate;
  String _iconKey = 'service_default';

  @override
  void initState() {
    super.initState();
    _currencyController = TextEditingController(
      text: AppPreferences.instance.defaultCurrency,
    );
    _dueDate = dateOnly(DateTime.now().add(const Duration(days: 7)));
  }

  @override
  void dispose() {
    _objectController.dispose();
    _serviceController.dispose();
    _providerController.dispose();
    _numberController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pago unico'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(
                  _objectController,
                  'Objeto',
                  Icons.location_city_outlined,
                ),
                _field(
                  _serviceController,
                  'Concepto',
                  Icons.receipt_long_outlined,
                ),
                _field(
                  _providerController,
                  'Proveedor',
                  Icons.business_outlined,
                ),
                _field(
                  _numberController,
                  'Referencia',
                  Icons.tag_outlined,
                  required: false,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _iconKey,
                  decoration: const InputDecoration(
                    labelText: 'Icono',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: serviceIconOptions
                      .map(
                        (option) => DropdownMenuItem(
                          value: option.key,
                          child: Row(
                            children: [
                              Icon(option.icon),
                              const SizedBox(width: 10),
                              Text(option.label),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _iconKey = value ?? 'service_default'),
                ),
                const SizedBox(height: 12),
                _field(
                  _amountController,
                  'Monto estimado',
                  Icons.attach_money,
                  required: false,
                  keyboardType: TextInputType.number,
                ),
                _field(
                  _currencyController,
                  'Moneda',
                  Icons.currency_exchange_outlined,
                  required: false,
                  maxLength: 3,
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await pickAppDate(
                      context,
                      initialDate: _dueDate,
                    );
                    if (picked != null) {
                      setState(() => _dueDate = dateOnly(picked));
                    }
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text('Vence ${formatDate(_dueDate)}'),
                ),
                const SizedBox(height: 12),
                _field(
                  _notesController,
                  'Notas',
                  Icons.notes_outlined,
                  required: false,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.add),
          label: const Text('Crear'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = true,
    int maxLines = 1,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          counterText: maxLength == null ? null : '',
        ),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                  ? 'Campo requerido'
                  : null
            : null,
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = _amountController.text.trim();
    final currency = _currencyController.text.trim().toUpperCase();
    Navigator.of(context).pop(
      OneTimePaymentDraft(
        objectName: _objectController.text.trim(),
        iconKey: _iconKey,
        serviceName: _serviceController.text.trim(),
        providerName: _providerController.text.trim(),
        serviceNumber: _numberController.text.trim().isEmpty
            ? null
            : _numberController.text.trim(),
        dueDate: _dueDate,
        currency: currency.isEmpty
            ? AppPreferences.instance.defaultCurrency
            : currency,
        estimatedAmount: amount.isEmpty ? null : double.tryParse(amount),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }
}
