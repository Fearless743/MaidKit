import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/routing/app_router.gr.dart';
import 'package:maid_kit/shared/presentation/app_scaffold.dart';

import 'database_backup_service.dart';
import 'cloud_sync_service.dart';
import 'server_providers.dart';
import 'terminal_color_scheme.dart';
import 'vault_service.dart';

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
    final activeVaultFile = ref.watch(activeVaultFileProvider);
    final vaultFiles = ref.watch(vaultFilesProvider);
    final cloudUser = ref.watch(cloudUserProvider);

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
                titleKey: 'settingsAccount',
                padding: EdgeInsets.zero,
                child: cloudUser.when(
                  loading: () => const ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    leading: CircleAvatar(child: Icon(Symbols.person)),
                    title: Text('…'),
                  ),
                  error: (_, _) => _cloudLoginTile(context, ref),
                  data: (user) => user == null
                      ? _cloudLoginTile(context, ref)
                      : Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              leading: _CloudAvatar(user: user),
                              title: Text(user.name),
                              subtitle: user.handle.isEmpty
                                  ? null
                                  : Text(user.handle),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              _SettingsSection(
                titleKey: 'settingsVaults',
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _VaultCloudBindingTile(
                      vaultId: 'maid_kit',
                      title: 'vaultDefaultName'.tr(),
                      active: activeVaultFile == null,
                      onExport: activeVaultFile == null
                          ? () => _exportDatabase(context, ref)
                          : null,
                      onImport: activeVaultFile == null
                          ? () => _importDatabase(context, ref)
                          : null,
                    ),
                    ...vaultFiles.map(
                      (path) => _VaultCloudBindingTile(
                        vaultId: path,
                        title: path.split(Platform.pathSeparator).last,
                        active: activeVaultFile == path,
                        onExport: activeVaultFile == path
                            ? () => _exportDatabase(context, ref)
                            : null,
                        onImport: activeVaultFile == path
                            ? () => _importDatabase(context, ref)
                            : null,
                      ),
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

  ListTile _cloudLoginTile(BuildContext context, WidgetRef ref) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    leading: const CircleAvatar(child: Icon(Symbols.person)),
    title: const Text('settingsCloudSignIn').tr(),
    subtitle: const Text('settingsCloudSignInHint').tr(),
    trailing: FilledButton(
      onPressed: () => _signInToCloud(context, ref),
      child: const Text('settingsCloudSignInAction').tr(),
    ),
    onTap: () => _signInToCloud(context, ref),
  );

  Future<void> _signInToCloud(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(cloudSyncServiceProvider).signIn();
      ref.invalidate(cloudUserProvider);
      ref.invalidate(cloudWorkspacesProvider);
    } on CloudSyncException catch (error) {
      if (context.mounted) _showMessage(error.message);
    } catch (_) {
      if (context.mounted) _showMessage('commonSomethingWentWrong'.tr());
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

    final destination = await showDialog<_ImportDestination>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('settingsImportDestinationTitle').tr(),
        content: RadioGroup<_ImportDestination>(
          groupValue: _ImportDestination.newVault,
          onChanged: (value) {
            if (value != null) Navigator.of(context).pop(value);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<_ImportDestination>(
                value: _ImportDestination.newVault,
                title: const Text('settingsImportNewVault').tr(),
                subtitle: const Text('settingsImportNewVaultHint').tr(),
              ),
              RadioListTile<_ImportDestination>(
                value: _ImportDestination.replaceCurrent,
                title: const Text('settingsImportReplaceCurrent').tr(),
                subtitle: const Text('settingsImportReplaceCurrentHint').tr(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('commonCancel').tr(),
          ),
        ],
      ),
    );
    if (destination == null || !context.mounted) return;

    if (destination == _ImportDestination.replaceCurrent) {
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
              child: const Text('settingsImportReplaceCurrent').tr(),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      await _importIntoCurrentVault(context, ref, path, password);
      return;
    }

    final vaultPassword = await _newVaultPasswordDialog(context);
    if (vaultPassword == null || !context.mounted) return;

    final vaultPath = await ref
        .read(vaultFileStorageProvider)
        .createVaultPath(name: path);

    final database = AppDatabase(filePath: vaultPath);
    final vault = VaultService(database, vaultId: vaultPath);
    try {
      await vault.create(vaultPassword);
      final archive = await File(path).readAsString();
      await DatabaseBackupService(
        database,
        vault,
      ).importArchive(archive, password);
      await ref.read(activeVaultFileProvider.notifier).select(vaultPath);
      if (context.mounted) _showMessage('settingsImportSuccess'.tr());
    } catch (error) {
      if (context.mounted) {
        _showMessage('settingsBackupError'.tr(args: [error.toString()]));
      }
    } finally {
      await database.close();
    }
  }

  Future<void> _importIntoCurrentVault(
    BuildContext context,
    WidgetRef ref,
    String path,
    String password,
  ) async {
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

enum _ImportDestination { newVault, replaceCurrent }

Future<String?> _backupPasswordDialog(
  BuildContext context, {
  required bool confirm,
}) => showDialog<String>(
  context: context,
  builder: (context) => _BackupPasswordDialog(confirm: confirm),
);

Future<String?> _newVaultPasswordDialog(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (context) => const _BackupPasswordDialog(
        confirm: true,
        titleKey: 'settingsImportNewVaultPasswordTitle',
        hintKey: 'settingsImportNewVaultPasswordHint',
        actionKey: 'vaultCreateAction',
      ),
    );

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog({
    required this.confirm,
    this.titleKey,
    this.hintKey,
    this.actionKey,
  });

  final bool confirm;
  final String? titleKey;
  final String? hintKey;
  final String? actionKey;

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
      widget.titleKey ??
          (widget.confirm
              ? 'settingsExportPasswordTitle'
              : 'settingsImportPasswordTitle'),
    ).tr(),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            (widget.hintKey ??
                    (widget.confirm
                        ? 'settingsExportVaultPasswordHint'
                        : 'settingsImportVaultPasswordHint'))
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
              ? (widget.actionKey ?? 'settingsExportData').tr()
              : (widget.actionKey ?? 'settingsImportData').tr(),
        ),
      ),
    ],
  );
}

void _showMessage(String message) {
  showSnackBar(message);
}

class _CloudAvatar extends StatelessWidget {
  const _CloudAvatar({required this.user});

  final CloudUser user;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    foregroundImage: user.avatarUrl == null
        ? null
        : NetworkImage(user.avatarUrl!),
    child: Text(user.initials),
  );
}

class _VaultCloudBindingTile extends ConsumerWidget {
  const _VaultCloudBindingTile({
    required this.vaultId,
    required this.title,
    required this.active,
    this.onExport,
    this.onImport,
  });

  final String vaultId;
  final String title;
  final bool active;
  final Future<void> Function()? onExport;
  final Future<void> Function()? onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binding = ref.watch(cloudSyncConfigurationForVaultProvider(vaultId));
    final configuration = binding.asData?.value;
    final workspace = configuration == null
        ? 'settingsVaultWorkspaceUnbound'.tr()
        : 'settingsVaultWorkspaceBound'.tr(args: [configuration.workspaceName]);
    final syncStatus = configuration == null
        ? 'settingsVaultSyncDisabled'.tr()
        : 'settingsVaultLastSync'.tr(args: ['settingsVaultNotYet'.tr()]);
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: const Icon(Symbols.lock),
          title: Text(title),
          subtitle: Text('$workspace\n$syncStatus'),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active) const Icon(Symbols.check),
              const SizedBox(width: 8),
              const Icon(Symbols.chevron_right),
            ],
          ),
          onTap: () => _bindWorkspace(context, ref),
        ),
        if (active)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onExport == null ? null : () => onExport!(),
                  icon: const Icon(Symbols.file_download),
                  label: const Text('settingsExportData').tr(),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onImport == null ? null : () => onImport!(),
                  icon: const Icon(Symbols.file_upload),
                  label: const Text('settingsImportData').tr(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _bindWorkspace(BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(cloudSyncServiceForVaultProvider(vaultId));
      final workspaces = await service.signInAndListWorkspaces();
      if (!context.mounted) return;
      final selected = ref
          .read(cloudSyncConfigurationForVaultProvider(vaultId))
          .asData
          ?.value;
      final workspace = await showDialog<CloudWorkspace>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 440,
            child: workspaces.isEmpty
                ? const Text('settingsCloudSyncNoWorkspaces').tr()
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final workspace in workspaces)
                        ListTile(
                          enabled: workspace.supportsSync,
                          title: Text(workspace.name),
                          subtitle: Text(
                            workspace.supportsSync
                                ? 'settingsCloudSyncWorkspaceEligible'.tr()
                                : 'settingsCloudSyncWorkspaceUpgrade'.tr(),
                          ),
                          trailing: selected?.workspaceId == workspace.id
                              ? const Icon(Symbols.check)
                              : null,
                          onTap: workspace.supportsSync
                              ? () => Navigator.of(context).pop(workspace)
                              : null,
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('commonCancel').tr(),
            ),
          ],
        ),
      );
      if (workspace == null) return;
      await service.enable(workspace);
      ref.invalidate(cloudSyncConfigurationForVaultProvider(vaultId));
      ref.invalidate(cloudUserProvider);
    } on CloudSyncException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('commonSomethingWentWrong'.tr())),
        );
      }
    }
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
