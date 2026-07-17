import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'server_providers.dart';

@RoutePage()
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final biometricEnabled = ref.watch(biometricUnlockEnabledProvider);
    final adapterOptions = ref.watch(terminalSessionAdapterOptionsProvider);
    final selectedAdapter = ref.watch(selectedTerminalSessionAdapterProvider);
    final cursorAnimationEnabled = ref.watch(cursorAnimationEnabledProvider);
    final connectOnStartup = ref.watch(connectOnStartupProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Customize MaidKit and how it protects your saved credentials.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),
        Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Theme'),
                const SizedBox(height: 4),
                Text(
                  'Choose how MaidKit follows your system appearance.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Symbols.brightness_auto),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Symbols.light_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Symbols.dark_mode),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (selection) {
                    ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(selection.first);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Terminal', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue:
                      adapterOptions.any(
                        (option) => option.id == selectedAdapter,
                      )
                      ? selectedAdapter
                      : adapterOptions.first.id,
                  decoration: const InputDecoration(
                    labelText: 'Terminal renderer',
                  ),
                  items: [
                    for (final option in adapterOptions)
                      DropdownMenuItem(
                        value: option.id,
                        child: Text(option.label),
                      ),
                  ],
                  onChanged: adapterOptions.length < 2
                      ? null
                      : (adapterId) async {
                          if (adapterId != null) {
                            await ref
                                .read(
                                  selectedTerminalSessionAdapterProvider
                                      .notifier,
                                )
                                .select(adapterId);
                          }
                        },
                ),
                const SizedBox(height: 8),
                Text(
                  adapterOptions
                      .firstWhere(
                        (option) => option.id == selectedAdapter,
                        orElse: () => adapterOptions.first,
                      )
                      .description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'New terminals use the selected renderer. Reopen existing terminals to switch them.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Animate cursor movement'),
                  subtitle: const Text(
                    'Smoothly move the Ghostty cursor between terminal cells.',
                  ),
                  value: cursorAnimationEnabled,
                  onChanged: selectedAdapter == 'ghostty'
                      ? (enabled) async {
                          await ref
                              .read(cursorAnimationEnabledProvider.notifier)
                              .setEnabled(enabled);
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Connections', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('Connect saved servers on startup'),
            subtitle: const Text(
              'Keep SSH connections ready to collect server statistics after the vault unlocks.',
            ),
            value: connectOnStartup,
            onChanged: (value) =>
                ref.read(connectOnStartupProvider.notifier).setEnabled(value),
          ),
        ),
        const SizedBox(height: 24),
        Text('Security', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: biometricEnabled.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Could not load biometric settings: $error'),
            ),
            data: (enabled) => SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: const Text('Biometric unlock'),
              subtitle: const Text(
                'Use Touch ID or your device biometric prompt to unlock the vault.',
              ),
              value: enabled,
              onChanged: (value) => _setBiometricUnlock(ref, value),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _setBiometricUnlock(WidgetRef ref, bool enabled) async {
    final vault = ref.read(vaultServiceProvider);
    if (enabled) {
      await vault.enableBiometricUnlock();
    } else {
      await vault.disableBiometricUnlock();
    }
    ref.invalidate(biometricUnlockEnabledProvider);
  }
}
