import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:maid_kit/routing/app_router.gr.dart';

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

    final selectedAdapterOption = adapterOptions.firstWhere(
      (option) => option.id == selectedAdapter,
      orElse: () => adapterOptions.first,
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Text(
              'settingsTitle',
              style: Theme.of(context).textTheme.headlineSmall,
            ).tr(),
            const SizedBox(height: 8),
            Text(
              'settingsDescription',
              style: Theme.of(context).textTheme.bodyLarge,
            ).tr(),
            const SizedBox(height: 32),
            _SettingsSection(
              titleKey: 'settingsAppearance',
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
                  const SizedBox(height: 16),
                  const _LanguageSwitcher(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SettingsSection(
              titleKey: 'settingsTerminal',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedAdapterOption.id,
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
                    selectedAdapterOption.description,
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
                    subtitle: const Text('settingsAnimateCursorHint').tr(),
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
            const SizedBox(height: 24),
            _SettingsSection(
              titleKey: 'settingsConnections',
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('settingsConnectOnStartup').tr(),
                    subtitle: const Text('settingsConnectOnStartupHint').tr(),
                    value: connectOnStartup,
                    onChanged: (value) => ref
                        .read(connectOnStartupProvider.notifier)
                        .setEnabled(value),
                  ),
                  const SizedBox(height: 12),
                  _IntervalDropdown(
                    labelKey: 'settingsBackgroundRefreshInterval',
                    helperKey: 'settingsBackgroundRefreshIntervalHint',
                    value: refreshInterval,
                    options: _refreshIntervals,
                    fallback: _refreshIntervals[1],
                    onChanged: (interval) {
                      ref
                          .read(serverMetricsRefreshIntervalProvider.notifier)
                          .setInterval(interval);
                    },
                  ),
                  const SizedBox(height: 16),
                  _IntervalDropdown(
                    labelKey: 'settingsFocusedRefreshInterval',
                    helperKey: 'settingsFocusedRefreshIntervalHint',
                    value: focusedRefreshInterval,
                    options: _focusedRefreshIntervals,
                    fallback: _focusedRefreshIntervals.first,
                    onChanged: (interval) {
                      ref
                          .read(focusedServerRefreshIntervalProvider.notifier)
                          .setInterval(interval);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SettingsSection(
              titleKey: 'settingsSecurity',
              padding: EdgeInsets.zero,
              child: biometricEnabled.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'settingsBiometricError'.tr(args: [error.toString()]),
                  ),
                ),
                data: (enabled) => SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('settingsBiometricUnlock').tr(),
                  subtitle: const Text('settingsBiometricUnlockHint').tr(),
                  value: enabled,
                  onChanged: (value) => _setBiometricUnlock(ref, value),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SettingsSection(
              titleKey: 'settingsAbout',
              padding: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Symbols.info),
                title: Text('aboutTitle'.tr()),
                subtitle: Text('settingsAboutHint'.tr()),
                trailing: const Icon(Symbols.chevron_right),
                onTap: () => context.router.push(const AboutRoute()),
              ),
            ),
          ],
        ),
      ),
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.titleKey,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final String titleKey;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titleKey, style: Theme.of(context).textTheme.titleMedium).tr(),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: padding, child: child),
        ),
      ],
    );
  }
}

class _IntervalDropdown extends StatelessWidget {
  const _IntervalDropdown({
    required this.labelKey,
    required this.helperKey,
    required this.value,
    required this.options,
    required this.fallback,
    required this.onChanged,
  });

  final String labelKey;
  final String helperKey;
  final Duration value;
  final List<Duration> options;
  final Duration fallback;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Duration>(
      initialValue: options.contains(value) ? value : fallback,
      decoration: InputDecoration(
        labelText: labelKey.tr(),
        helperText: helperKey.tr(),
      ),
      items: [
        for (final interval in options)
          DropdownMenuItem(
            value: interval,
            child: Text(_formatInterval(interval)),
          ),
      ],
      onChanged: (interval) {
        if (interval != null) onChanged(interval);
      },
    );
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

String _formatInterval(Duration interval) {
  if (interval.inMinutes >= 1) {
    return 'settingsIntervalMinutes'.tr(args: ['${interval.inMinutes}']);
  }
  return 'settingsIntervalSeconds'.tr(args: ['${interval.inSeconds}']);
}

String _languageDisplayName(Locale locale) {
  switch ('${locale.languageCode}-${locale.countryCode}') {
    case 'en-US':
      return 'English (US)';
    case 'zh-CN':
      return '简体中文';
    default:
      return '${locale.languageCode}-${locale.countryCode}';
  }
}

class _LanguageSwitcher extends StatelessWidget {
  const _LanguageSwitcher();

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale;
    final supportedLocales = context.supportedLocales;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('settingsDisplayLanguage').tr(),
              const SizedBox(height: 2),
              Text(
                _languageDisplayName(currentLocale),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        DropdownButton<Locale?>(
          value: supportedLocales.contains(currentLocale)
              ? currentLocale
              : null,
          underline: const SizedBox.shrink(),
          items: [
            for (final locale in supportedLocales)
              DropdownMenuItem<Locale?>(
                value: locale,
                child: Text(_languageDisplayName(locale)),
              ),
            DropdownMenuItem<Locale?>(
              value: null,
              child: Text('languageFollowSystem'.tr()),
            ),
          ],
          onChanged: (Locale? value) {
            if (value != null) {
              context.setLocale(value);
            } else {
              context.resetLocale();
            }
          },
        ),
      ],
    );
  }
}
