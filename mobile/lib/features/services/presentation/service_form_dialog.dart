import 'package:flutter/material.dart';

import '../../../shared/formatters.dart';
import '../../../shared/date_picker.dart';
import '../../../shared/app_preferences.dart';
import '../../../shared/icons/service_icon_catalog.dart';
import '../data/service_account.dart';
import '../data/services_api.dart';

class ServiceFormDialog extends StatefulWidget {
  const ServiceFormDialog({this.initial, super.key});

  final ServiceAccount? initial;

  @override
  State<ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<ServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _objectController;
  late final TextEditingController _serviceController;
  late final TextEditingController _providerController;
  late final TextEditingController _numberController;
  late final TextEditingController _amountController;
  late final TextEditingController _currencyController;
  late final TextEditingController _recurrenceCountController;
  late final TextEditingController _chargeAccountController;
  late final TextEditingController _notesController;
  late DateTime _dueDate;
  DateTime? _cutoffDate;
  DateTime? _recurrenceEndDate;
  late Frequency _frequency;
  late WeekendAdjustment _weekendAdjustment;
  late int _intervalCount;
  late bool _isAutopay;
  late ServiceLifecycleStatus _status;
  late String _iconKey;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _objectController = TextEditingController(text: initial?.objectName ?? '');
    _serviceController = TextEditingController(
      text: initial?.serviceName ?? '',
    );
    _providerController = TextEditingController(
      text: initial?.providerName ?? '',
    );
    _numberController = TextEditingController(
      text: initial?.serviceNumber ?? '',
    );
    _amountController = TextEditingController(
      text: initial?.estimatedAmount?.toString() ?? '',
    );
    _currencyController = TextEditingController(
      text: initial?.currency ?? AppPreferences.instance.defaultCurrency,
    );
    _recurrenceCountController = TextEditingController(
      text: initial?.recurrencePaymentCount?.toString() ?? '',
    );
    _chargeAccountController = TextEditingController(
      text: initial?.chargeAccount ?? '',
    );
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _dueDate =
        initial?.initialDueDate ??
        dateOnly(DateTime.now().add(const Duration(days: 7)));
    _cutoffDate = initial?.initialCutoffDate;
    _recurrenceEndDate = initial?.recurrenceEndDate;
    _frequency = initial?.frequency ?? Frequency.monthly;
    _weekendAdjustment = initial?.weekendAdjustment ?? WeekendAdjustment.none;
    _intervalCount = initial?.intervalCount ?? 1;
    _isAutopay = initial?.isAutopay ?? false;
    _status = initial?.status ?? ServiceLifecycleStatus.active;
    _iconKey = serviceIconByKey(initial?.iconKey).key;
  }

  @override
  void dispose() {
    _objectController.dispose();
    _serviceController.dispose();
    _providerController.dispose();
    _numberController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    _recurrenceCountController.dispose();
    _chargeAccountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;
    return AlertDialog(
      title: Text(isEditing ? 'Editar servicio' : 'Crear servicio'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _textField(
                  _objectController,
                  'Objeto',
                  Icons.location_city_outlined,
                ),
                _textField(
                  _serviceController,
                  'Servicio',
                  Icons.home_repair_service_outlined,
                ),
                _textField(
                  _providerController,
                  'Proveedor',
                  Icons.business_outlined,
                ),
                _textField(
                  _numberController,
                  'Numero de servicio',
                  Icons.tag_outlined,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _iconKey,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Icono del servicio',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: serviceIconOptions
                      .map(
                        (option) => DropdownMenuItem(
                          value: option.key,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ServiceIconBadge(iconKey: option.key, size: 28),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 220,
                                child: Text(
                                  option.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _iconKey = value ?? 'service_default'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: 'Vencimiento inicial',
                        value: _dueDate,
                        onPick: (value) {
                          if (value != null) {
                            setState(() => _dueDate = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateButton(
                        label: 'Corte inicial',
                        value: _cutoffDate,
                        allowClear: true,
                        onPick: (value) => setState(() => _cutoffDate = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Frequency>(
                        initialValue: _frequency,
                        decoration: const InputDecoration(
                          labelText: 'Frecuencia',
                        ),
                        items: Frequency.values
                            .map(
                              (frequency) => DropdownMenuItem(
                                value: frequency,
                                child: Text(frequency.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(
                          () => _frequency = value ?? Frequency.monthly,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _intervalCount,
                        decoration: const InputDecoration(
                          labelText: 'Intervalo',
                        ),
                        items: const [1, 2, 3, 6, 12]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text('$value'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _intervalCount = value ?? 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<WeekendAdjustment>(
                  initialValue: _weekendAdjustment,
                  decoration: const InputDecoration(
                    labelText: 'Fecha en sabado o domingo',
                    prefixIcon: Icon(Icons.weekend_outlined),
                  ),
                  items: WeekendAdjustment.values
                      .map(
                        (policy) => DropdownMenuItem(
                          value: policy,
                          child: Text(policy.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(
                    () => _weekendAdjustment = value ?? WeekendAdjustment.none,
                  ),
                ),
                const SizedBox(height: 12),
                _textField(
                  _amountController,
                  'Monto estimado',
                  Icons.attach_money,
                  keyboardType: TextInputType.number,
                  required: false,
                ),
                _textField(
                  _currencyController,
                  'Moneda',
                  Icons.currency_exchange_outlined,
                  required: false,
                  maxLength: 3,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: 'Finaliza',
                        value: _recurrenceEndDate,
                        allowClear: true,
                        onPick: (value) => setState(() {
                          _recurrenceEndDate = value;
                          if (value != null &&
                              _recurrenceCountController.text.trim().isEmpty) {
                            _recurrenceCountController.text = _countUntil(
                              value,
                            ).toString();
                          }
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _recurrenceCountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Num. pagos',
                          prefixIcon: Icon(Icons.repeat_outlined),
                        ),
                        onChanged: (value) {
                          final count = int.tryParse(value.trim());
                          if (count != null && count > 0) {
                            setState(
                              () => _recurrenceEndDate = _dateForCount(count),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isAutopay,
                  title: const Text('Pago domiciliado'),
                  secondary: const Icon(Icons.account_balance_outlined),
                  onChanged: (value) => setState(() => _isAutopay = value),
                ),
                if (_isAutopay)
                  _textField(
                    _chargeAccountController,
                    'Cuenta de cargo',
                    Icons.credit_card_outlined,
                    required: false,
                  ),
                DropdownButtonFormField<ServiceLifecycleStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Estado del servicio',
                    prefixIcon: Icon(Icons.toggle_on_outlined),
                  ),
                  items: ServiceLifecycleStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(
                    () => _status = value ?? ServiceLifecycleStatus.active,
                  ),
                ),
                const SizedBox(height: 12),
                if (_status == ServiceLifecycleStatus.ended)
                  _textField(
                    _notesController,
                    'Motivo o notas de cierre',
                    Icons.notes_outlined,
                    required: false,
                    maxLines: 3,
                  )
                else
                  _textField(
                    _notesController,
                    'Notas',
                    Icons.notes_outlined,
                    required: false,
                    maxLines: 3,
                  ),
                if (widget.initial != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Modificado: ${widget.initial!.lastModifiedPlatform ?? '-'} / ${formatDateTime(widget.initial!.lastModifiedAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Dispositivo: ${widget.initial!.lastModifiedDeviceId ?? '-'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
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
          icon: Icon(isEditing ? Icons.save_outlined : Icons.add),
          label: Text(isEditing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }

  Widget _textField(
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
    final amountText = _amountController.text.trim();
    final notesText = _notesController.text.trim();
    final countText = _recurrenceCountController.text.trim();
    final count = countText.isEmpty ? null : int.tryParse(countText);
    final currency = _currencyController.text.trim().toUpperCase();
    final draft = ServiceDraft(
      active: _status == ServiceLifecycleStatus.active,
      status: _status,
      endedAt: _status == ServiceLifecycleStatus.ended
          ? dateOnly(DateTime.now())
          : null,
      pausedFrom: _status == ServiceLifecycleStatus.paused
          ? dateOnly(DateTime.now())
          : null,
      endReason: _status == ServiceLifecycleStatus.ended && notesText.isNotEmpty
          ? notesText
          : null,
      iconKey: _iconKey,
      objectName: _objectController.text.trim(),
      serviceName: _serviceController.text.trim(),
      providerName: _providerController.text.trim(),
      serviceNumber: _numberController.text.trim(),
      isAutopay: _isAutopay,
      chargeAccount: _chargeAccountController.text.trim().isEmpty
          ? null
          : _chargeAccountController.text.trim(),
      initialCutoffDate: _cutoffDate,
      initialDueDate: _dueDate,
      weekendAdjustment: _weekendAdjustment,
      frequency: _frequency,
      intervalCount: _intervalCount,
      estimatedAmount: amountText.isEmpty ? null : double.tryParse(amountText),
      currency: currency.isEmpty
          ? AppPreferences.instance.defaultCurrency
          : currency,
      recurrenceEndDate: _recurrenceEndDate,
      recurrencePaymentCount: count,
      notes: notesText.isEmpty ? null : notesText,
    );
    Navigator.of(context).pop(draft);
  }

  DateTime _dateForCount(int count) {
    final index = count <= 1 ? 0 : count - 1;
    return switch (_frequency) {
      Frequency.weekly => dateOnly(
        _dueDate.add(Duration(days: 7 * _intervalCount * index)),
      ),
      Frequency.biweekly => dateOnly(
        _dueDate.add(Duration(days: 14 * _intervalCount * index)),
      ),
      Frequency.monthly => _addMonths(_dueDate, _intervalCount * index),
      Frequency.yearly => _addMonths(_dueDate, 12 * _intervalCount * index),
    };
  }

  int _countUntil(DateTime endDate) {
    var count = 0;
    var date = _dueDate;
    while (!date.isAfter(endDate) && count < 500) {
      count++;
      date = _dateForCount(count + 1);
    }
    return count;
  }
}

DateTime _addMonths(DateTime value, int months) {
  final target = DateTime(value.year, value.month + months);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  final day = value.day > lastDay ? lastDay : value.day;
  return DateTime(target.year, target.month, day);
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onPick,
    this.allowClear = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await pickAppDate(context, initialDate: value);
        if (picked != null) onPick(dateOnly(picked));
      },
      onLongPress: allowClear ? () => onPick(null) : null,
      icon: const Icon(Icons.event_outlined),
      label: Text('$label\n${formatDate(value)}', textAlign: TextAlign.center),
    );
  }
}
