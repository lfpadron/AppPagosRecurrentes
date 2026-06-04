import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/local_app_database.dart';
import '../../../shared/app_preferences.dart';
import '../../../shared/formatters.dart';
import '../../../shared/platform/app_platform.dart';
import '../../../shared/widgets/sync_conflict_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _currencyController;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _pinController;
  late final LocalAppDatabase _localDatabase;

  @override
  void initState() {
    super.initState();
    _currencyController = TextEditingController(
      text: AppPreferences.instance.defaultCurrency,
    );
    _nameController = TextEditingController(
      text: AppPreferences.instance.localUserName ?? '',
    );
    _emailController = TextEditingController(
      text: AppPreferences.instance.localUserEmail ?? '',
    );
    _pinController = TextEditingController();
    _localDatabase = LocalAppDatabase(userId: AppConfig.userId);
  }

  @override
  void dispose() {
    _currencyController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuracion')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preferencias',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: AppPreferences.instance,
                    builder: (context, _) {
                      final prefs = AppPreferences.instance;
                      if (_currencyController.text != prefs.defaultCurrency) {
                        _currencyController.text = prefs.defaultCurrency;
                      }
                      return Column(
                        children: [
                          TextField(
                            controller: _currencyController,
                            maxLength: 3,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Moneda principal',
                              prefixIcon: Icon(Icons.payments_outlined),
                              counterText: '',
                            ),
                            onSubmitted: prefs.setDefaultCurrency,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final currency in const [
                                'MXN',
                                'USD',
                                'EUR',
                              ])
                                ChoiceChip(
                                  label: Text(currency),
                                  selected: prefs.defaultCurrency == currency,
                                  onSelected: (_) {
                                    prefs.setDefaultCurrency(currency);
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Horizonte de generacion: ${prefs.generationHorizonMonths} meses',
                            ),
                          ),
                          Slider(
                            value: prefs.generationHorizonMonths.toDouble(),
                            min: 6,
                            max: 60,
                            divisions: 9,
                            label: '${prefs.generationHorizonMonths}',
                            onChanged: (value) =>
                                prefs.setGenerationHorizonMonths(value.round()),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<WeekStart>(
                            initialValue: prefs.weekStart,
                            decoration: const InputDecoration(
                              labelText: 'Semana inicia en',
                              prefixIcon: Icon(Icons.view_week_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: WeekStart.sunday,
                                child: Text('Domingo'),
                              ),
                              DropdownMenuItem(
                                value: WeekStart.monday,
                                child: Text('Lunes'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                prefs.setWeekStart(value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<MonthLabelFormat>(
                            initialValue: prefs.monthLabelFormat,
                            decoration: const InputDecoration(
                              labelText: 'Formato de mes',
                              prefixIcon: Icon(Icons.calendar_month_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: MonthLabelFormat.numeric,
                                child: Text('2026-05'),
                              ),
                              DropdownMenuItem(
                                value: MonthLabelFormat.spanish,
                                child: Text('Mayo 2026'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                prefs.setMonthLabelFormat(value);
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ProfileCard(
            nameController: _nameController,
            emailController: _emailController,
          ),
          const SizedBox(height: 12),
          _PinCard(pinController: _pinController),
          const SizedBox(height: 12),
          _PlanCard(),
          const SizedBox(height: 12),
          _SyncPrepCard(localDatabase: _localDatabase),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Plan Pro'),
              subtitle: const Text(
                'Preparado para RevenueCat, Google Play y limites premium.',
              ),
              trailing: FilledButton(
                onPressed: null,
                child: const Text('Pronto'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(
                isAndroidApp
                    ? Icons.phone_android_outlined
                    : Icons.cloud_outlined,
              ),
              title: Text(isAndroidApp ? 'Datos locales' : 'API'),
              subtitle: Text(
                isAndroidApp
                    ? 'Este dispositivo es la fuente principal de datos.\nUser: ${AppConfig.userId}'
                    : '${AppConfig.apiBaseUrl}\nUser: ${AppConfig.userId}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.nameController,
    required this.emailController,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedBuilder(
          animation: AppPreferences.instance,
          builder: (context, _) {
            final prefs = AppPreferences.instance;
            if (nameController.text != (prefs.localUserName ?? '')) {
              nameController.text = prefs.localUserName ?? '';
            }
            if (emailController.text != (prefs.localUserEmail ?? '')) {
              emailController.text = prefs.localUserEmail ?? '';
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usuario local',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => prefs.setLocalUser(
                        name: nameController.text,
                        email: emailController.text,
                      ),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar usuario'),
                    ),
                    OutlinedButton.icon(
                      onPressed: prefs.hasLocalUser ? prefs.closeSession : null,
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesion'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({required this.pinController});

  final TextEditingController pinController;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedBuilder(
          animation: AppPreferences.instance,
          builder: (context, _) {
            final prefs = AppPreferences.instance;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PIN de acceso',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinController,
                  maxLength: 4,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: prefs.hasPin ? 'Actualizar PIN' : 'Nuevo PIN',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        final ok = await prefs.setPin(
                          pinController.text.trim(),
                        );
                        pinController.clear();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'PIN guardado'
                                  : 'El PIN debe tener 4 digitos',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.lock_outline),
                      label: Text(prefs.hasPin ? 'Actualizar' : 'Activar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: prefs.hasPin ? prefs.clearPin : null,
                      icon: const Icon(Icons.lock_open_outlined),
                      label: const Text('Quitar PIN'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedBuilder(
          animation: AppPreferences.instance,
          builder: (context, _) {
            final prefs = AppPreferences.instance;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plan', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                DropdownButtonFormField<SubscriptionPlan>(
                  initialValue: prefs.subscriptionPlan,
                  decoration: const InputDecoration(
                    labelText: 'Plan local de prueba',
                    prefixIcon: Icon(Icons.workspace_premium_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: SubscriptionPlan.economic,
                      child: Text('Economico'),
                    ),
                    DropdownMenuItem(
                      value: SubscriptionPlan.premium,
                      child: Text('Premium anual'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      prefs.setSubscriptionPlanForLocalTesting(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  prefs.syncEnabled
                      ? 'Sync, web app y respaldo: activos para pruebas.'
                      : 'Sync, web app y respaldo: inactivos.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SyncPrepCard extends StatelessWidget {
  const _SyncPrepCard({required this.localDatabase});

  final LocalAppDatabase localDatabase;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sincronizacion',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            FutureBuilder<String>(
              future: localDatabase.storedDeviceId(),
              builder: (context, snapshot) =>
                  Text('Dispositivo: ${snapshot.data ?? '-'}'),
            ),
            FutureBuilder<int>(
              future: localDatabase.storedSchemaVersion(),
              builder: (context, snapshot) => Text(
                'Esquema local: ${snapshot.data ?? LocalAppDatabase.currentSchemaVersion}',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await showDialog<SyncConflictResolution>(
                  context: context,
                  builder: (context) => SyncConflictDialog(
                    local: SyncConflictCandidate(
                      title: 'Version celular',
                      subtitle: 'Pago marcado como pagado',
                      platform: 'android',
                      modifiedAt: DateTime.now().subtract(
                        const Duration(minutes: 4),
                      ),
                    ),
                    remote: SyncConflictCandidate(
                      title: 'Version web',
                      subtitle: 'Pago cancelado',
                      platform: 'web',
                      modifiedAt: DateTime.now().subtract(
                        const Duration(minutes: 2),
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.merge_type_outlined),
              label: const Text('Probar conflicto'),
            ),
            const SizedBox(height: 8),
            Text('Ultima revision: ${formatDateTime(DateTime.now())}'),
          ],
        ),
      ),
    );
  }
}
