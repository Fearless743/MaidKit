import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'server_providers.dart';

class VaultGate extends ConsumerStatefulWidget {
  const VaultGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends ConsumerState<VaultGate> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _unlocked = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  String _friendlyError(Object error) => error.toString().replaceFirst(
    RegExp(r'^(Bad state|ArgumentError): '),
    '',
  );

  Future<void> _submit(bool exists) async {
    if (_busy) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    final vault = ref.read(vaultServiceProvider);
    try {
      if (exists) {
        final ok = await vault.unlockWithPassword(_password.text);
        if (!ok) {
          throw StateError('The vault password is incorrect.');
        }
      } else {
        if (_password.text != _confirmation.text) {
          throw StateError('The passwords do not match.');
        }
        await vault.create(_password.text);
      }
      if (mounted) setState(() => _unlocked = true);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted && !_unlocked) setState(() => _busy = false);
    }
  }

  Future<void> _unlockWithBiometrics() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final unlocked = await ref
          .read(vaultServiceProvider)
          .unlockWithBiometrics();
      if (unlocked && mounted) setState(() => _unlocked = true);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted && !_unlocked) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;

    final exists = ref.watch(vaultExistsProvider);
    final biometricEnabled = ref.watch(biometricUnlockEnabledProvider);
    final theme = Theme.of(context);
    final showBiometricUnlock = biometricEnabled.asData?.value ?? false;

    return exists.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          Scaffold(body: Center(child: Text('Could not open vault: $error'))),
      data: (hasVault) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Symbols.lock,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasVault ? 'Unlock MaidKit' : 'Create your vault',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasVault
                        ? 'Enter your vault password to access saved SSH credentials.'
                        : 'Your vault password encrypts SSH credentials stored on this device.',
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofocus: true,
                    enabled: !_busy,
                    onSubmitted: (_) => _submit(hasVault),
                    decoration: const InputDecoration(
                      labelText: 'Vault password',
                    ),
                  ),
                  if (!hasVault) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmation,
                      obscureText: true,
                      enabled: !_busy,
                      onSubmitted: (_) => _submit(false),
                      decoration: const InputDecoration(
                        labelText: 'Confirm vault password',
                      ),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : () => _submit(hasVault),
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(hasVault ? 'Unlock' : 'Create vault'),
                  ),
                  if (hasVault && showBiometricUnlock)
                    TextButton(
                      onPressed: _busy ? null : _unlockWithBiometrics,
                      child: const Text('Unlock with biometrics'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
