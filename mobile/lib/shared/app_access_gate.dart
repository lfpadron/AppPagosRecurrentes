import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import 'app_preferences.dart';
import 'auth/auth_session_controller.dart';

class AppAccessGate extends StatelessWidget {
  const AppAccessGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isRemoteWeb = kIsWeb && !AppConfig.forceLocalData;
    if (isRemoteWeb) {
      return _RemotePremiumGate(child: child);
    }

    return AnimatedBuilder(
      animation: AppPreferences.instance,
      builder: (context, _) {
        final prefs = AppPreferences.instance;
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

class _RemotePremiumGate extends StatefulWidget {
  const _RemotePremiumGate({required this.child});

  @override
  State<_RemotePremiumGate> createState() => _RemotePremiumGateState();

  final Widget child;
}

class _RemotePremiumGateState extends State<_RemotePremiumGate> {
  bool _requestedProfile = false;

  @override
  Widget build(BuildContext context) {
    final auth = AuthSessionController.instance;
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        if (!auth.isConfigured) {
          return const _AuthNotConfiguredPage();
        }
        if (!auth.isSignedIn) {
          _requestedProfile = false;
          return const _PremiumWebLoginPage();
        }

        if (auth.profile == null &&
            !auth.loadingProfile &&
            auth.profileError == null &&
            !_requestedProfile) {
          _requestedProfile = true;
          Future.microtask(() => auth.loadProfile());
        }

        if (auth.loadingProfile || auth.profile == null) {
          if (auth.profileError != null) {
            return _AuthErrorPage(message: auth.profileError!);
          }
          return const _AccessScaffold(
            title: 'Validando acceso',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Revisando plan Premium...'),
              ],
            ),
          );
        }

        if (!auth.profile!.isPremium) {
          return _PremiumRequiredPage(email: auth.profile!.email);
        }

        return widget.child;
      },
    );
  }
}

class _PremiumWebLoginPage extends StatefulWidget {
  const _PremiumWebLoginPage();

  @override
  State<_PremiumWebLoginPage> createState() => _PremiumWebLoginPageState();
}

class _PremiumWebLoginPageState extends State<_PremiumWebLoginPage> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  String? _error;
  String? _message;
  bool _sending = false;
  bool _validating = false;

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
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(_message!),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _sending ? null : _sendOtp,
                icon: const Icon(Icons.mail_outline),
                label: Text(_sending ? 'Enviando...' : 'Enviar codigo'),
              ),
              FilledButton.icon(
                onPressed: _validating ? null : _validate,
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(_validating ? 'Validando...' : 'Validar acceso'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    if (!email.contains('@')) {
      setState(() => _error = 'Correo invalido.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _message = null;
    });
    try {
      await AuthSessionController.instance.sendOtp(email);
      setState(() => _message = 'Codigo enviado. Revisa tu correo.');
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _validate() async {
    final email = _emailController.text.trim().toLowerCase();
    final otp = _otpController.text.trim();
    if (!email.contains('@') || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _error = 'Correo u OTP invalido.');
      return;
    }
    setState(() {
      _validating = true;
      _error = null;
    });
    try {
      await AuthSessionController.instance.verifyOtp(email, otp);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }
}

class _AuthNotConfiguredPage extends StatelessWidget {
  const _AuthNotConfiguredPage();

  @override
  Widget build(BuildContext context) {
    return const _AccessScaffold(
      title: 'Auth no configurado',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.admin_panel_settings_outlined, size: 48),
          SizedBox(height: 12),
          Text(
            'Configura SUPABASE_URL y SUPABASE_ANON_KEY al construir la web app.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AuthErrorPage extends StatelessWidget {
  const _AuthErrorPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _AccessScaffold(
      title: 'Acceso Premium',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => AuthSessionController.instance.loadProfile(
              force: true,
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: AuthSessionController.instance.signOut,
            child: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );
  }
}

class _PremiumRequiredPage extends StatelessWidget {
  const _PremiumRequiredPage({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return _AccessScaffold(
      title: 'Plan Premium requerido',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_outlined, size: 48),
          const SizedBox(height: 12),
          Text(email, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            'La web app esta disponible para usuarios Premium.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: AuthSessionController.instance.signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );
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
