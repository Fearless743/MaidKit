import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:maid_kit/routing/app_router.gr.dart';
import 'package:maid_kit/shared/presentation/app_scaffold.dart';

import 'database_backup_service.dart';
import 'server_providers.dart';
import 'terminal_color_scheme.dart';

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
    final brandingEnvironmentEnabled = ref.watch(
      terminalBrandingEnvironmentEnabledProvider,
    );
    final terminalColorScheme = ref.watch(terminalColorSchemeProvider);
    final connectOnStartup = ref.watch(connectOnStartupProvider);
    final refreshInterval = ref.watch(serverMetricsRefreshIntervalProvider);
    final focusedRefreshInterval = ref.watch(
      focusedServerRefreshIntervalProvider,
    );
    final backgroundImage = ref.watch(maidKitBackgroundImageProvider);
    final backgroundImageEnabled = ref.watch(
      maidKitBackgroundImageEnabledProvider,
    );
    final transparentTerminalBackground = ref.watch(
      transparentTerminalBackgroundEnabledProvider,
    );
    final windowOpacity = ref.watch(maidKitWindowOpacityProvider);

    final selectedAdapterOption = adapterOptions.firstWhere(
      (option) => option.id == selectedAdapter,
      orElse: () => adapterOptions.first,
    );

    return MaidKitAppScaffold(
      body: Align(
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
                    if (!kIsWeb) ...[
                      const SizedBox(height: 24),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('settingsBackgroundImage').tr(),
                        subtitle: Text(
                          backgroundImage.asData?.value == null
                              ? 'settingsBackgroundImageNone'.tr()
                              : 'settingsBackgroundImageHint'.tr(),
                        ),
                        value: backgroundImageEnabled.asData?.value ?? true,
                        onChanged: backgroundImage.asData?.value == null
                            ? null
                            : (enabled) => setMaidKitBackgroundImageEnabled(
                                ref,
                                enabled,
                              ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () =>
                                _selectBackgroundImage(context, ref),
                            icon: const Icon(Symbols.image),
                            label: const Text(
                              'settingsBackgroundImageChoose',
                            ).tr(),
                          ),
                          if (backgroundImage.asData?.value != null)
                            TextButton.icon(
                              onPressed: () =>
                                  _clearBackgroundImage(context, ref),
                              icon: const Icon(Symbols.delete_outline),
                              label: const Text(
                                'settingsBackgroundImageClear',
                              ).tr(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('settingsTerminalTransparent').tr(),
                        subtitle: const Text(
                          'settingsTerminalTransparentHint',
                        ).tr(),
                        value:
                            transparentTerminalBackground.asData?.value ??
                            false,
                        onChanged:
                            backgroundImage.asData?.value == null ||
                                !(backgroundImageEnabled.asData?.value ?? true)
                            ? null
                            : (enabled) =>
                                  setTransparentTerminalBackgroundEnabled(
                                    ref,
                                    enabled,
                                  ),
                      ),
                    ],
                    if (DesktopWindowFrame.isPlatformDesktop) ...[
                      const SizedBox(height: 16),
                      Text(
                        'settingsWindowOpacity',
                        style: Theme.of(context).textTheme.titleSmall,
                      ).tr(),
                      const SizedBox(height: 4),
                      Text(
                        'settingsWindowOpacityHint',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ).tr(),
                      Slider(
                        value: windowOpacity.asData?.value ?? 1.0,
                        min: 0.4,
                        max: 1.0,
                        divisions: 12,
                        label:
                            '${((windowOpacity.asData?.value ?? 1.0) * 100).round()}%',
                        onChanged: (value) =>
                            setMaidKitWindowOpacity(ref, value),
                      ),
                    ],
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
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey(terminalColorScheme.id),
                      initialValue: terminalColorScheme.id,
                      decoration: InputDecoration(
                        labelText: 'settingsTerminalColorScheme'.tr(),
                      ),
                      items: [
                        for (final scheme in TerminalColorSchemes.all)
                          DropdownMenuItem(
                            value: scheme.id,
                            child: Text(scheme.label),
                          ),
                      ],
                      onChanged: (schemeId) async {
                        if (schemeId != null) {
                          await ref
                              .read(terminalColorSchemeProvider.notifier)
                              .select(schemeId);
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'settingsTerminalColorSchemeHint',
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
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'settingsTerminalBrandingEnvironment',
                      ).tr(),
                      subtitle: const Text(
                        'settingsTerminalBrandingEnvironmentHint',
                      ).tr(),
                      value: brandingEnvironmentEnabled,
                      onChanged: (enabled) => ref
                          .read(
                            terminalBrandingEnvironmentEnabledProvider.notifier,
                          )
                          .setEnabled(enabled),
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
                    onChanged: (value) =>
                        _setBiometricUnlock(context, ref, value),
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
              const SizedBox(height: 24),
              _SettingsSection(
                titleKey: 'settingsData',
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      leading: const Icon(Symbols.file_download),
                      title: const Text('settingsExportData').tr(),
                      subtitle: const Text('settingsExportDataHint').tr(),
                      onTap: () => _exportDatabase(context, ref),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      leading: const Icon(Symbols.file_upload),
                      title: const Text('settingsImportData').tr(),
                      subtitle: const Text('settingsImportDataHint').tr(),
                      onTap: () => _importDatabase(context, ref),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectBackgroundImage(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final selection = await FilePicker.pickFiles(
      dialogTitle: 'settingsBackgroundImageChoose'.tr(),
      type: FileType.image,
    );
    final path = selection?.files.singleOrNull?.path;
    if (path == null) return;
    try {
      await saveMaidKitBackgroundImage(ref, File(path));
    } catch (error) {
      if (context.mounted) _showMessage(error.toString());
    }
  }

  Future<void> _clearBackgroundImage(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await clearMaidKitBackgroundImage(ref);
    if (context.mounted) _showMessage('settingsBackgroundImageCleared'.tr());
  }

  Future<void> _setBiometricUnlock(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final vault = ref.read(vaultServiceProvider);
    try {
      if (enabled) {
        // Prompt once during setup; only persist when authentication succeeds.
        await vault.enableBiometricUnlock();
      } else {
        await vault.disableBiometricUnlock();
      }
    } catch (error) {
      // Leave the switch off if setup fails (e.g. cancelled or unavailable).
      await vault.disableBiometricUnlock();
      if (context.mounted) {
        _showMessage(
          'settingsBiometricSetupFailed'.tr(args: [error.toString()]),
        );
      }
    } finally {
      ref.invalidate(biometricUnlockEnabledProvider);
    }
  }

  Future<void> _exportDatabase(BuildContext context, WidgetRef ref) async {
    final password = await _backupPasswordDialog(context, confirm: true);
    if (password == null || !context.mounted) return;

    final vault = ref.read(vaultServiceProvider);
    if (!await vault.unlockWithPassword(password)) {
      if (context.mounted) {
        _showMessage('settingsVaultPasswordInvalid'.tr());
      }
      return;
    }
    if (!context.mounted) return;

    final path = await FilePicker.saveFile(
      dialogTitle: 'settingsExportData'.tr(),
      fileName: 'maidkit-backup.mkb',
      type: FileType.custom,
      allowedExtensions: const ['mkb'],
    );
    if (path == null || !context.mounted) return;

    try {
      final archive = await DatabaseBackupService(
        ref.read(databaseProvider),
        ref.read(vaultServiceProvider),
      ).exportArchive(password);
      await File(path).writeAsString(archive);
      if (context.mounted) _showMessage('settingsExportSuccess'.tr());
    } catch (error) {
      if (context.mounted) {
        _showMessage('settingsBackupError'.tr(args: [error.toString()]));
      }
    }
  }

  Future<void> _importDatabase(BuildContext context, WidgetRef ref) async {
    final selection = await FilePicker.pickFiles(
      dialogTitle: 'settingsImportData'.tr(),
      type: FileType.custom,
      allowedExtensions: const ['mkb'],
    );
    final path = selection?.files.singleOrNull?.path;
    if (path == null || !context.mounted) return;

    final password = await _backupPasswordDialog(context, confirm: false);
    if (password == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('settingsImportConfirmTitle').tr(),
        content: const Text('settingsImportConfirmDescription').tr(),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('commonCancel').tr(),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('settingsImportData').tr(),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final archive = await File(path).readAsString();
      await DatabaseBackupService(
        ref.read(databaseProvider),
        ref.read(vaultServiceProvider),
      ).importArchive(archive, password);
      if (context.mounted) _showMessage('settingsImportSuccess'.tr());
    } catch (error) {
      if (context.mounted) {
        _showMessage('settingsBackupError'.tr(args: [error.toString()]));
      }
    }
  }
}

Future<String?> _backupPasswordDialog(
  BuildContext context, {
  required bool confirm,
}) => showDialog<String>(
  context: context,
  builder: (context) => _BackupPasswordDialog(confirm: confirm),
);

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog({required this.confirm});

  final bool confirm;

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      widget.confirm
          ? 'settingsExportPasswordTitle'.tr()
          : 'settingsImportPasswordTitle'.tr(),
    ),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            (widget.confirm
                    ? 'settingsExportVaultPasswordHint'
                    : 'settingsImportVaultPasswordHint')
                .tr(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(labelText: 'vaultPasswordLabel'.tr()),
          ),
          if (widget.confirm) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _confirmation,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'vaultConfirmPasswordLabel'.tr(),
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('commonCancel').tr(),
      ),
      FilledButton(
        onPressed: () {
          if (widget.confirm && _password.text != _confirmation.text) {
            _showMessage('vaultPasswordsDontMatch'.tr());
            return;
          }
          Navigator.of(context).pop(_password.text);
        },
        child: Text(
          widget.confirm
              ? 'settingsExportData'.tr()
              : 'settingsImportData'.tr(),
        ),
      ),
    ],
  );
}

void _showMessage(String message) {
  showSnackBar(message);
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
