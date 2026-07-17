import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
  bool _biometric = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit(bool exists) async {
    setState(() => _error = null);
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
        await vault.create(_password.text, enableBiometrics: _biometric);
      }
      if (exists && _biometric) {
        await vault.enableBiometricUnlock();
      }
      if (mounted) {
        setState(() => _unlocked = true);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;
    final exists = ref.watch(vaultExistsProvider);
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
                    Icons.lock_outline,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasVault ? 'Unlock MaidKit' : 'Create your vault',
                    style: Theme.of(context).textTheme.headlineSmall,
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
                      onSubmitted: (_) => _submit(false),
                      decoration: const InputDecoration(
                        labelText: 'Confirm vault password',
                      ),
                    ),
                  ],
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _biometric,
                    onChanged: (v) => setState(() => _biometric = v ?? false),
                    title: Text(
                      hasVault
                          ? 'Enable biometric unlock after password unlock'
                          : 'Enable biometric unlock',
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => _submit(hasVault),
                    child: Text(hasVault ? 'Unlock' : 'Create vault'),
                  ),
                  if (hasVault)
                    TextButton(
                      onPressed: () async {
                        try {
                          final unlocked = await ref
                              .read(vaultServiceProvider)
                              .unlockWithBiometrics();
                          if (unlocked && mounted) {
                            setState(() => _unlocked = true);
                          }
                        } catch (error) {
                          if (mounted) {
                            setState(() => _error = error.toString());
                          }
                        }
                      },
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
