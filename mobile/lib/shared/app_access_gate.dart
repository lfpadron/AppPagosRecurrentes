import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import 'app_preferences.dart';

class AppAccessGate extends StatelessWidget {
  const AppAccessGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppPreferences.instance,
      builder: (context, _) {
        final prefs = AppPreferences.instance;
        if (kIsWeb && !prefs.isPremium && !AppConfig.forceLocalData) {
          return const _PremiumWebGate();
        }
        if (!prefs.hasLocalUser) {
          return const _LocalUserSetupPage();
        }
        if (prefs.sessionClosed) {
          return const _SessionClosedPage();
        }
        if (prefs.requiresPinUnlock) {
          return const _PinUnlockPage();
        }
        return child;
      },
    );
  }
}

class _LocalUserSetupPage extends StatefulWidget {
  const _LocalUserSetupPage();

  @override
  State<_LocalUserSetupPage> createState() => _LocalUserSetupPageState();
}

class _LocalUserSetupPageState extends State<_LocalUserSetupPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AccessScaffold(
      title: 'Pagos recurrentes',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_outline, size: 48),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty && email.isEmpty) {
      setState(() => _error = 'Captura nombre o correo.');
      return;
    }
    await AppPreferences.instance.setLocalUser(name: name, email: email);
  }
}

class _SessionClosedPage extends StatelessWidget {
  const _SessionClosedPage();

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.instance;
    return _AccessScaffold(
      title: 'Sesion cerrada',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 48),
          const SizedBox(height: 12),
          Text(
            prefs.localUserEmail?.isNotEmpty == true
                ? prefs.localUserEmail!
                : prefs.localUserName ?? '',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: prefs.reopenSession,
            icon: const Icon(Icons.login),
            label: const Text('Entrar'),
          ),
        ],
      ),
    );
  }
}

class _PinUnlockPage extends StatefulWidget {
  const _PinUnlockPage();

  @override
  State<_PinUnlockPage> createState() => _PinUnlockPageState();
}

class _PinUnlockPageState extends State<_PinUnlockPage> {
  final _pinController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AccessScaffold(
      title: 'PIN',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pin_outlined, size: 48),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            obscureText: true,
            maxLength: 4,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'PIN de 4 digitos',
              counterText: '',
            ),
            onSubmitted: (_) => _unlock(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _unlock,
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Desbloquear'),
          ),
        ],
      ),
    );
  }

  void _unlock() {
    final ok = AppPreferences.instance.verifyPin(_pinController.text.trim());
    if (!ok) setState(() => _error = 'PIN incorrecto.');
  }
}

class _PremiumWebGate extends StatefulWidget {
  const _PremiumWebGate();

  @override
  State<_PremiumWebGate> createState() => _PremiumWebGateState();
}

class _PremiumWebGateState extends State<_PremiumWebGate> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AccessScaffold(
      title: 'Acceso Premium',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_outlined, size: 48),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo registrado'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _otpController,
            maxLength: 6,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'OTP',
              counterText: '',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _validate,
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('Validar acceso'),
          ),
        ],
      ),
    );
  }

  Future<void> _validate() async {
    final email = _emailController.text.trim().toLowerCase();
    final otp = _otpController.text.trim();
    if (!email.contains('@') || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _error = 'Correo u OTP invalido.');
      return;
    }
    final prefs = AppPreferences.instance;
    await prefs.setLocalUser(name: prefs.localUserName ?? '', email: email);
    prefs.setSubscriptionPlanForLocalTesting(SubscriptionPlan.premium);
  }
}

class _AccessScaffold extends StatelessWidget {
  const _AccessScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(padding: const EdgeInsets.all(20), child: child),
          ),
        ),
      ),
    );
  }
}
