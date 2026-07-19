import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
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
    final refreshInterval = ref.watch(serverMetricsRefreshIntervalProvider);
    final focusedRefreshInterval = ref.watch(
      focusedServerRefreshIntervalProvider,
    );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('settingsTitle', style: Theme.of(context).textTheme.headlineSmall).tr(),
        const SizedBox(height: 8),
        Text(
          'settingsDescription',
          style: Theme.of(context).textTheme.bodyLarge,
        ).tr(),
        const SizedBox(height: 32),
        Text('settingsAppearance', style: Theme.of(context).textTheme.titleMedium).tr(),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('settingsTheme').tr(),
                const SizedBox(height: 4),
                Text(
                  'settingsThemeDescription',
                  style: Theme.of(context).textTheme.bodyMedium,
                ).tr(),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('settingsThemeSystem'.tr()),
                      icon: const Icon(Symbols.brightness_auto),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('settingsThemeLight'.tr()),
                      icon: const Icon(Symbols.light_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('settingsThemeDark'.tr()),
                      icon: const Icon(Symbols.dark_mode),
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
        Text('settingsTerminal', style: Theme.of(context).textTheme.titleMedium).tr(),
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
                  decoration: InputDecoration(
                    labelText: 'settingsTerminalRenderer'.tr(),
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
                  'settingsTerminalRendererHint',
                  style: Theme.of(context).textTheme.bodySmall,
                ).tr(),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('settingsAnimateCursor').tr(),
                  subtitle: const Text(
                    'settingsAnimateCursorHint',
                  ).tr(),
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
        Text('settingsConnections', style: Theme.of(context).textTheme.titleMedium).tr(),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('settingsConnectOnStartup').tr(),
                  subtitle: const Text(
                    'settingsConnectOnStartupHint',
                  ).tr(),
                  value: connectOnStartup,
                  onChanged: (value) => ref
                      .read(connectOnStartupProvider.notifier)
                      .setEnabled(value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Duration>(
                  initialValue: _refreshIntervals.contains(refreshInterval)
                      ? refreshInterval
                      : _refreshIntervals[1],
                  decoration: InputDecoration(
                    labelText: 'settingsBackgroundRefreshInterval'.tr(),
                    helperText:
                        'settingsBackgroundRefreshIntervalHint'.tr(),
                  ),
                  items: [
                    for (final interval in _refreshIntervals)
                      DropdownMenuItem(
                        value: interval,
                        child: Text(_formatInterval(interval)),
                      ),
                  ],
                  onChanged: (interval) {
                    if (interval != null) {
                      ref
                          .read(serverMetricsRefreshIntervalProvider.notifier)
                          .setInterval(interval);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Duration>(
                  initialValue:
                      _focusedRefreshIntervals.contains(focusedRefreshInterval)
                      ? focusedRefreshInterval
                      : _focusedRefreshIntervals.first,
                  decoration: InputDecoration(
                    labelText: 'settingsFocusedRefreshInterval'.tr(),
                    helperText:
                        'settingsFocusedRefreshIntervalHint'.tr(),
                  ),
                  items: [
                    for (final interval in _focusedRefreshIntervals)
                      DropdownMenuItem(
                        value: interval,
                        child: Text(_formatInterval(interval)),
                      ),
                  ],
                  onChanged: (interval) {
                    if (interval != null) {
                      ref
                          .read(focusedServerRefreshIntervalProvider.notifier)
                          .setInterval(interval);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('settingsSecurity', style: Theme.of(context).textTheme.titleMedium).tr(),
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
              child: Text('settingsBiometricError'.tr(args: [error.toString()])),
            ),
            data: (enabled) => SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: const Text('settingsBiometricUnlock').tr(),
              subtitle: const Text(
                'settingsBiometricUnlockHint',
              ).tr(),
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

const _refreshIntervals = [
  Duration(seconds: 15),
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 2),
  Duration(minutes: 5),
];

const _focusedRefreshIntervals = [
  Duration(seconds: 3),
  Duration(seconds: 5),
  Duration(seconds: 10),
  Duration(seconds: 15),
  Duration(seconds: 30),
];

String _formatInterval(Duration interval) => interval.inMinutes >= 1
    ? '${interval.inMinutes} minute${interval.inMinutes == 1 ? '' : 's'}'
    : '${interval.inSeconds} seconds';
