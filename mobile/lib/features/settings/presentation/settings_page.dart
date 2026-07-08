import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/local_app_database.dart';
import '../../../features/sync/data/sync_api.dart';
import '../../../shared/app_preferences.dart';
import '../../../shared/auth/auth_session_controller.dart';
import '../../../shared/dependencies.dart';
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
          _SyncPrepCard(
            localDatabase: _localDatabase,
            syncApi: DependenciesScope.of(context).syncApi,
          ),
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
            final remoteAuth = AppConfig.supabaseAuthEnabled;
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
                      onPressed: remoteAuth
                          ? AuthSessionController.instance.signOut
                          : prefs.hasLocalUser
                          ? prefs.closeSession
                          : null,
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

class _SyncPrepCard extends StatefulWidget {
  const _SyncPrepCard({required this.localDatabase, required this.syncApi});

  final LocalAppDatabase localDatabase;
  final SyncApi syncApi;

  @override
  State<_SyncPrepCard> createState() => _SyncPrepCardState();
}

class _SyncPrepCardState extends State<_SyncPrepCard> {
  final _syncEmailController = TextEditingController();
  final _syncOtpController = TextEditingController();
  bool _sendingOtp = false;
  bool _validatingOtp = false;
  bool _syncing = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _syncEmailController.dispose();
    _syncOtpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedBuilder(
          animation: AuthSessionController.instance,
          builder: (context, _) {
            final auth = AuthSessionController.instance;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sincronizacion',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                FutureBuilder<String>(
                  future: widget.localDatabase.storedDeviceId(),
                  builder: (context, snapshot) =>
                      Text('Dispositivo: ${snapshot.data ?? '-'}'),
                ),
                FutureBuilder<int>(
                  future: widget.localDatabase.storedSchemaVersion(),
                  builder: (context, snapshot) => Text(
                    'Esquema local: ${snapshot.data ?? LocalAppDatabase.currentSchemaVersion}',
                  ),
                ),
                FutureBuilder<DateTime?>(
                  future: widget.localDatabase.storedLastBootstrapAt(),
                  builder: (context, snapshot) => Text(
                    'Ultimo bootstrap: ${snapshot.data == null ? '-' : formatDateTime(snapshot.data!)}',
                  ),
                ),
                const SizedBox(height: 12),
                if (!AppConfig.supabaseAuthEnabled)
                  const Text(
                    'Configura Supabase para activar sync con el servidor.',
                  )
                else if (!auth.isSignedIn)
                  _SyncLoginForm(
                    emailController: _syncEmailController,
                    otpController: _syncOtpController,
                    sendingOtp: _sendingOtp,
                    validatingOtp: _validatingOtp,
                    onSendOtp: _sendSyncOtp,
                    onValidateOtp: _validateSyncOtp,
                  )
                else ...[
                  Text('Sesion: ${auth.userEmail ?? '-'}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _syncing ? null : _bootstrapLocal,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: Text(
                          _syncing ? 'Sincronizando...' : 'Subir datos locales',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showConflictDemo,
                        icon: const Icon(Icons.merge_type_outlined),
                        label: const Text('Probar conflicto'),
                      ),
                    ],
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 8),
                  Text(_message!),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _sendSyncOtp() async {
    final email = _syncEmailController.text.trim().toLowerCase();
    if (!email.contains('@')) {
      setState(() => _error = 'Correo invalido.');
      return;
    }
    setState(() {
      _sendingOtp = true;
      _error = null;
      _message = null;
    });
    try {
      await AuthSessionController.instance.sendOtp(email);
      setState(() => _message = 'Codigo enviado. Revisa tu correo.');
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  Future<void> _validateSyncOtp() async {
    final email = _syncEmailController.text.trim().toLowerCase();
    final otp = _syncOtpController.text.trim();
    if (!email.contains('@') || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _error = 'Correo u OTP invalido.');
      return;
    }
    setState(() {
      _validatingOtp = true;
      _error = null;
      _message = null;
    });
    try {
      await AuthSessionController.instance.verifyOtp(email, otp);
      setState(() => _message = 'Sesion validada.');
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _validatingOtp = false);
    }
  }

  Future<void> _bootstrapLocal() async {
    setState(() {
      _syncing = true;
      _error = null;
      _message = null;
    });
    try {
      final status = await widget.syncApi.status();
      if (!status.isPremium) {
        setState(() => _error = 'La sincronizacion requiere plan Premium.');
        return;
      }
      final result = await widget.syncApi.bootstrapLocal();
      setState(() {
        _message =
            'Bootstrap listo. Servicios: ${result.importedServices} nuevos, '
            '${result.updatedServices} actualizados. Pagos: '
            '${result.importedPayments} nuevos, ${result.updatedPayments} actualizados, '
            '${result.skippedPayments} omitidos. Conflictos: ${result.conflictCount}.';
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _showConflictDemo() async {
    await showDialog<SyncConflictResolution>(
      context: context,
      builder: (context) => SyncConflictDialog(
        local: SyncConflictCandidate(
          title: 'Version celular',
          subtitle: 'Pago marcado como pagado',
          platform: 'android',
          modifiedAt: DateTime.now().subtract(const Duration(minutes: 4)),
        ),
        remote: SyncConflictCandidate(
          title: 'Version web',
          subtitle: 'Pago cancelado',
          platform: 'web',
          modifiedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      ),
    );
  }
}

class _SyncLoginForm extends StatelessWidget {
  const _SyncLoginForm({
    required this.emailController,
    required this.otpController,
    required this.sendingOtp,
    required this.validatingOtp,
    required this.onSendOtp,
    required this.onValidateOtp,
  });

  final TextEditingController emailController;
  final TextEditingController otpController;
  final bool sendingOtp;
  final bool validatingOtp;
  final VoidCallback onSendOtp;
  final VoidCallback onValidateOtp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Correo Premium',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: otpController,
          maxLength: 6,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'OTP',
            prefixIcon: Icon(Icons.pin_outlined),
            counterText: '',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: sendingOtp ? null : onSendOtp,
              icon: const Icon(Icons.mail_outline),
              label: Text(sendingOtp ? 'Enviando...' : 'Enviar codigo'),
            ),
            FilledButton.icon(
              onPressed: validatingOtp ? null : onValidateOtp,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(validatingOtp ? 'Validando...' : 'Validar'),
            ),
          ],
        ),
      ],
    );
  }
}
