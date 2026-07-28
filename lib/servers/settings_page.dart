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
    final vaultLabels = ref.watch(vaultLabelsProvider);
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
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                    if (!kIsWeb) ...[
                      const SizedBox(height: 24),
                      SwitchListTile(
                        contentPadding: _sectionTilePadding,
                        shape: RoundedRectangleBorder(
                          borderRadius: _sectionTileBorderRadius(
                            _SettingsTilePosition.only,
                          ),
                        ),
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
                      Padding(
                        padding: _sectionTilePadding,
                        child: Wrap(
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
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: _sectionTilePadding,
                        shape: RoundedRectangleBorder(
                          borderRadius: _sectionTileBorderRadius(
                            _SettingsTilePosition.only,
                          ),
                        ),
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SettingsSection(
                titleKey: 'settingsTerminal',
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                        ],
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: _sectionTilePadding,
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
                      contentPadding: _sectionTilePadding,
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
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: _sectionTilePadding,
                      title: const Text('settingsConnectOnStartup').tr(),
                      subtitle: const Text('settingsConnectOnStartupHint').tr(),
                      value: connectOnStartup,
                      onChanged: (value) => ref
                          .read(connectOnStartupProvider.notifier)
                          .setEnabled(value),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          _IntervalDropdown(
                            labelKey: 'settingsBackgroundRefreshInterval',
                            helperKey: 'settingsBackgroundRefreshIntervalHint',
                            value: refreshInterval,
                            options: _refreshIntervals,
                            fallback: _refreshIntervals[1],
                            onChanged: (interval) {
                              ref
                                  .read(
                                    serverMetricsRefreshIntervalProvider
                                        .notifier,
                                  )
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
                                  .read(
                                    focusedServerRefreshIntervalProvider
                                        .notifier,
                                  )
                                  .setInterval(interval);
                            },
                          ),
                        ],
                      ),
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
                  data: (enabled) => Column(
                    children: [
                      SwitchListTile(
                        contentPadding: _sectionTilePadding,
                        shape: RoundedRectangleBorder(
                          borderRadius: _sectionTileBorderRadius(
                            _SettingsTilePosition.first,
                          ),
                        ),
                        title: const Text('settingsBiometricUnlock').tr(),
                        subtitle: const Text(
                          'settingsBiometricUnlockHint',
                        ).tr(),
                        value: enabled,
                        onChanged: (value) =>
                            _setBiometricUnlock(context, ref, value),
                      ),
                      ListTile(
                        contentPadding: _sectionTilePadding,
                        shape: RoundedRectangleBorder(
                          borderRadius: _sectionTileBorderRadius(
                            _SettingsTilePosition.last,
                          ),
                        ),
                        leading: const Icon(Symbols.password),
                        title: const Text('settingsVaultChangePassword').tr(),
                        subtitle: const Text(
                          'settingsVaultChangePasswordHint',
                        ).tr(),
                        trailing: const Icon(Symbols.chevron_right),
                        onTap: () => _changeVaultPassword(context, ref),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _SettingsSection(
                titleKey: 'settingsAbout',
                padding: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: _sectionTilePadding,
                  shape: RoundedRectangleBorder(
                    borderRadius: _sectionTileBorderRadius(
                      _SettingsTilePosition.only,
                    ),
                  ),
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
                  loading: () => ListTile(
                    contentPadding: _sectionTilePadding,
                    shape: RoundedRectangleBorder(
                      borderRadius: _sectionTileBorderRadius(
                        _SettingsTilePosition.only,
                      ),
                    ),
                    leading: const CircleAvatar(child: Icon(Symbols.person)),
                    title: const Text('…'),
                  ),
                  error: (_, _) => _cloudLoginTile(context, ref),
                  data: (user) => user == null
                      ? _cloudLoginTile(context, ref)
                      : Column(
                          children: [
                            ListTile(
                              contentPadding: _sectionTilePadding,
                              shape: RoundedRectangleBorder(
                                borderRadius: _sectionTileBorderRadius(
                                  _SettingsTilePosition.only,
                                ),
                              ),
                              leading: _CloudAvatar(user: user),
                              title: Text(user.name),
                              subtitle: user.handle.isEmpty
                                  ? null
                                  : Text(user.handle),
                              trailing: IconButton(
                                icon: const Icon(Symbols.logout),
                                tooltip: 'settingsCloudSignOut'.tr(),
                                onPressed: () =>
                                    _signOutFromCloud(context, ref),
                              ),
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
                      position: _SettingsTilePosition.first,
                      active: activeVaultFile == null,
                      onSelect: () => ref
                          .read(activeVaultFileProvider.notifier)
                          .select(null),
                      onExport: activeVaultFile == null
                          ? () => _exportDatabase(context, ref)
                          : null,
                      onImport: activeVaultFile == null
                          ? () => _importDatabase(context, ref)
                          : null,
                      onSync: activeVaultFile == null
                          ? () => _syncVault(context, ref, 'maid_kit')
                          : null,
                    ),
                    ...vaultFiles.map(
                      (path) => _VaultCloudBindingTile(
                        vaultId: path,
                        position: _SettingsTilePosition.middle,
                        title:
                            vaultLabels[path] ??
                            path.split(Platform.pathSeparator).last,
                        active: activeVaultFile == path,
                        onSelect: () => ref
                            .read(activeVaultFileProvider.notifier)
                            .select(path),
                        onExport: activeVaultFile == path
                            ? () => _exportDatabase(context, ref)
                            : null,
                        onRename: () => _renameVault(
                          context,
                          ref,
                          path,
                          vaultLabels[path] ??
                              path.split(Platform.pathSeparator).last,
                        ),
                        onDelete: () => _deleteVault(context, ref, path),
                        onImport: activeVaultFile == path
                            ? () => _importDatabase(context, ref)
                            : null,
                        onSync: activeVaultFile == path
                            ? () => _syncVault(context, ref, path)
                            : null,
                      ),
                    ),
                    ListTile(
                      contentPadding: _sectionTilePadding,
                      shape: RoundedRectangleBorder(
                        borderRadius: _sectionTileBorderRadius(
                          _SettingsTilePosition.last,
                        ),
                      ),
                      leading: const Icon(Symbols.add),
                      title: const Text('settingsVaultCreate').tr(),
                      trailing: const Icon(Symbols.chevron_right),
                      onTap: () => _showVaultOnboarding(context, ref),
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

  Widget _cloudLoginTile(BuildContext context, WidgetRef ref) => ListTile(
    contentPadding: _sectionTilePadding,
    shape: RoundedRectangleBorder(
      borderRadius: _sectionTileBorderRadius(_SettingsTilePosition.only),
    ),
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

  Future<void> _signOutFromCloud(BuildContext context, WidgetRef ref) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (sheetContext) => SheetScaffold(
        titleText: 'settingsCloudSignOut'.tr(),
        heightFactor: 0.32,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text('settingsCloudSignOutHint'.tr()),
            const SizedBox(height: 20),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: const Text('commonCancel').tr(),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('settingsCloudSignOut').tr(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(cloudSyncServiceProvider).signOut();
      ref.invalidate(cloudUserProvider);
      ref.invalidate(cloudWorkspacesProvider);
      for (final vaultId in ['maid_kit', ...ref.read(vaultFilesProvider)]) {
        ref.invalidate(cloudSyncConfigurationForVaultProvider(vaultId));
      }
      if (context.mounted) _showMessage('settingsCloudSignOutSuccess'.tr());
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

  Future<void> _changeVaultPassword(BuildContext context, WidgetRef ref) async {
    final password = await _changeVaultPasswordSheet(context);
    if (password == null || !context.mounted) return;
    try {
      await ref.read(vaultServiceProvider).changePassword(password);
      if (context.mounted) {
        _showMessage('settingsVaultPasswordChanged'.tr());
      }
    } catch (error) {
      if (context.mounted) {
        _showMessage('settingsBackupError'.tr(args: [error.toString()]));
      }
    }
  }

  Future<void> _exportDatabase(BuildContext context, WidgetRef ref) async {
    final password = await _backupPasswordSheet(context, confirm: true);
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

    final password = await _backupPasswordSheet(context, confirm: false);
    if (password == null || !context.mounted) return;

    final destination = await showModalBottomSheet<_ImportDestination>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (sheetContext) => SheetScaffold(
        titleText: 'settingsImportDestinationTitle'.tr(),
        heightFactor: 0.44,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            RadioGroup<_ImportDestination>(
              groupValue: _ImportDestination.newVault,
              onChanged: (value) {
                if (value != null) Navigator.of(sheetContext).pop(value);
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
                    subtitle: const Text(
                      'settingsImportReplaceCurrentHint',
                    ).tr(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('commonCancel').tr(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (destination == null || !context.mounted) return;

    if (destination == _ImportDestination.replaceCurrent) {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        useRootNavigator: true,
        builder: (sheetContext) => SheetScaffold(
          titleText: 'settingsImportConfirmTitle'.tr(),
          heightFactor: 0.34,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const Text('settingsImportConfirmDescription').tr(),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    child: const Text('commonCancel').tr(),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: const Text('settingsImportReplaceCurrent').tr(),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      if (confirmed != true || !context.mounted) return;
      await _importIntoCurrentVault(context, ref, path, password);
      return;
    }

    final vaultPassword = await _newVaultPasswordSheet(context);
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

  Future<void> _createLocalVault(BuildContext context, WidgetRef ref) async {
    final name = await _chooseVaultNameSheet(context);
    if (name == null || !context.mounted) return;
    final path = await ref
        .read(vaultFileStorageProvider)
        .createVaultPath(name: name);
    try {
      await ref.read(activeVaultFileProvider.notifier).select(path);
    } catch (error) {
      if (context.mounted) {
        _showMessage('settingsBackupError'.tr(args: [error.toString()]));
      }
    }
  }

  Future<void> _renameVault(
    BuildContext context,
    WidgetRef ref,
    String vaultId,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (sheetContext) => SheetScaffold(
        titleText: 'settingsVaultRename'.tr(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: 'settingsVaultName'.tr()),
              onSubmitted: (value) => Navigator.of(sheetContext).pop(value),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('commonCancel').tr(),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(controller.text),
                  child: const Text('commonSave').tr(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (name != null) {
      await ref.read(vaultLabelsProvider.notifier).rename(vaultId, name);
    }
  }

  Future<void> _deleteVault(
    BuildContext context,
    WidgetRef ref,
    String vaultId,
  ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (sheetContext) => SheetScaffold(
        titleText: 'settingsVaultDelete'.tr(),
        heightFactor: 0.34,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Text('settingsVaultDeleteHint').tr(),
            const SizedBox(height: 20),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: const Text('commonCancel').tr(),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text('commonDelete').tr(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (ref.read(activeVaultFileProvider) == vaultId) {
      await ref.read(activeVaultFileProvider.notifier).select(null);
    }
    await ref.read(vaultFileStorageProvider).deleteVault(vaultId);
    await ref.read(vaultFilesProvider.notifier).forget(vaultId);
    await ref.read(vaultLabelsProvider.notifier).remove(vaultId);
  }

  Future<void> _showVaultOnboarding(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<_VaultOnboardingChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (sheetContext) => SheetScaffold(
        titleText: 'settingsVaultCreate'.tr(),
        heightFactor: 0.46,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            ListTile(
              leading: const Icon(Symbols.lock),
              title: const Text('settingsVaultCreateLocal').tr(),
              subtitle: const Text('settingsVaultCreateLocalHint').tr(),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_VaultOnboardingChoice.local),
            ),
            ListTile(
              leading: const Icon(Symbols.cloud_download),
              title: const Text('settingsVaultDownloadCloud').tr(),
              subtitle: const Text('settingsVaultDownloadCloudHint').tr(),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_VaultOnboardingChoice.cloud),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('commonCancel').tr(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (choice == _VaultOnboardingChoice.local && context.mounted) {
      await _createLocalVault(context, ref);
    } else if (choice == _VaultOnboardingChoice.cloud && context.mounted) {
      await _downloadCloudVault(context, ref);
    }
  }

  Future<void> _downloadCloudVault(BuildContext context, WidgetRef ref) async {
    try {
      final accountService = ref.read(cloudSyncServiceProvider);
      final workspaces = await accountService.signInAndListWorkspaces();
      if (!context.mounted) return;
      final workspace = await _chooseCloudWorkspace(context, workspaces);
      if (workspace == null || !context.mounted) return;
      final blobs = await accountService.listVaultBlobs(workspace);
      if (!context.mounted) return;
      final blob = await _chooseCloudVault(context, blobs);
      if (blob == null || !context.mounted) return;
      final name = await _chooseVaultNameSheet(
        context,
        initialValue: workspace.name,
      );
      if (name == null || !context.mounted) return;

      final path = await ref
          .read(vaultFileStorageProvider)
          .createVaultPath(name: name);
      final sync = ref.read(cloudSyncServiceForVaultProvider(path));
      await sync.enable(workspace, existingBlob: blob);
      ref.invalidate(cloudSyncConfigurationForVaultProvider(path));
      await ref.read(activeVaultFileProvider.notifier).select(path);
    } on CloudSyncException catch (error) {
      if (context.mounted) _showMessage(error.message);
    } catch (error) {
      if (context.mounted) {
        _showMessage('settingsBackupError'.tr(args: [error.toString()]));
      }
    }
  }

  Future<CloudWorkspace?> _chooseCloudWorkspace(
    BuildContext context,
    List<CloudWorkspace> workspaces,
  ) => showModalBottomSheet<CloudWorkspace>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (sheetContext) => SheetScaffold(
      titleText: 'vaultCloudWorkspaceTitle'.tr(),
      heightFactor: 0.6,
      child: workspaces.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [const Text('settingsCloudSyncNoWorkspaces').tr()],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                    onTap: workspace.supportsSync
                        ? () => Navigator.of(sheetContext).pop(workspace)
                        : null,
                  ),
              ],
            ),
    ),
  );

  Future<CloudVaultBlob?> _chooseCloudVault(
    BuildContext context,
    List<CloudVaultBlob> blobs,
  ) => showModalBottomSheet<CloudVaultBlob>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (sheetContext) => SheetScaffold(
      titleText: 'settingsVaultDownloadCloud'.tr(),
      heightFactor: 0.6,
      child: blobs.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [const Text('settingsVaultNoCloudVaults').tr()],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                for (final blob in blobs)
                  ListTile(
                    leading: const Icon(Symbols.lock),
                    title: Text(
                      'settingsVaultCloudVault'.tr(
                        args: [blob.revision.toString()],
                      ),
                    ),
                    subtitle: Text(blob.id),
                    onTap: () => Navigator.of(sheetContext).pop(blob),
                  ),
              ],
            ),
    ),
  );

  Future<void> _syncVault(
    BuildContext context,
    WidgetRef ref,
    String vaultId,
  ) async {
    try {
      final vault = ref.read(vaultServiceProvider);
      final password = await vault.syncPassphrase();
      if (password == null) {
        if (context.mounted) {
          _showMessage('settingsVaultSyncPasswordRequired'.tr());
        }
        return;
      }
      final backup = DatabaseBackupService(ref.read(databaseProvider), vault);
      final service = ref.read(cloudSyncServiceForVaultProvider(vaultId));
      final archive = await backup.exportArchive(password);
      await service.sync(
        archive: archive,
        applyArchive: (archive) => backup.importArchive(archive, password),
      );
      ref.invalidate(cloudSyncConfigurationForVaultProvider(vaultId));
      if (context.mounted) {
        showSnackBar('settingsVaultSyncComplete'.tr());
      }
    } on CloudSyncException catch (error) {
      if (context.mounted) showSnackBar(error.message);
    } catch (error) {
      if (context.mounted) {
        showSnackBar('settingsBackupError'.tr(args: [error.toString()]));
      }
    }
  }
}

enum _ImportDestination { newVault, replaceCurrent }

enum _VaultOnboardingChoice { local, cloud }

enum _VaultTileAction { changeCloudBinding, rename, delete }

enum _SettingsTilePosition { only, first, middle, last }

const _sectionTilePadding = EdgeInsets.symmetric(horizontal: 16);

BorderRadius _sectionTileBorderRadius(_SettingsTilePosition position) {
  const radius = Radius.circular(12);
  return BorderRadius.only(
    topLeft:
        position == _SettingsTilePosition.only ||
            position == _SettingsTilePosition.first
        ? radius
        : Radius.zero,
    topRight:
        position == _SettingsTilePosition.only ||
            position == _SettingsTilePosition.first
        ? radius
        : Radius.zero,
    bottomLeft:
        position == _SettingsTilePosition.only ||
            position == _SettingsTilePosition.last
        ? radius
        : Radius.zero,
    bottomRight:
        position == _SettingsTilePosition.only ||
            position == _SettingsTilePosition.last
        ? radius
        : Radius.zero,
  );
}

Future<String?> _backupPasswordSheet(
  BuildContext context, {
  required bool confirm,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  builder: (context) => _BackupPasswordSheet(confirm: confirm),
);

Future<String?> _newVaultPasswordSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (context) => const _BackupPasswordSheet(
        confirm: true,
        titleKey: 'settingsImportNewVaultPasswordTitle',
        hintKey: 'settingsImportNewVaultPasswordHint',
        actionKey: 'vaultCreateAction',
      ),
    );

Future<String?> _changeVaultPasswordSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (context) => const _BackupPasswordSheet(
        confirm: true,
        titleKey: 'settingsVaultChangePassword',
        hintKey: 'settingsVaultChangePasswordHint',
        actionKey: 'commonSave',
      ),
    );

Future<String?> _chooseVaultNameSheet(
  BuildContext context, {
  String? initialValue,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  builder: (context) =>
      _VaultNameSheet(initialValue: initialValue ?? 'settingsVaultCreate'.tr()),
);

class _VaultNameSheet extends StatefulWidget {
  const _VaultNameSheet({required this.initialValue});

  final String initialValue;

  @override
  State<_VaultNameSheet> createState() => _VaultNameSheetState();
}

class _VaultNameSheetState extends State<_VaultNameSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    titleText: 'settingsVaultName'.tr(),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(labelText: 'settingsVaultName'.tr()),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('commonCancel').tr(),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _submit,
              child: const Text('commonContinue').tr(),
            ),
          ],
        ),
      ],
    ),
  );
}

class _BackupPasswordSheet extends StatefulWidget {
  const _BackupPasswordSheet({
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
  State<_BackupPasswordSheet> createState() => _BackupPasswordSheetState();
}

class _BackupPasswordSheetState extends State<_BackupPasswordSheet> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    titleText:
        (widget.titleKey ??
                (widget.confirm
                    ? 'settingsExportPasswordTitle'
                    : 'settingsImportPasswordTitle'))
            .tr(),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
        const SizedBox(height: 20),
        Row(
          children: [
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('commonCancel').tr(),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                if (widget.confirm && _password.text != _confirmation.text) {
                  showSnackBar('vaultPasswordsDontMatch'.tr());
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
        ),
      ],
    ),
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
    required this.position,
    required this.active,
    required this.onSelect,
    this.onExport,
    this.onImport,
    this.onSync,
    this.onRename,
    this.onDelete,
  });

  final String vaultId;
  final String title;
  final _SettingsTilePosition position;
  final bool active;
  final Future<void> Function() onSelect;
  final Future<void> Function()? onExport;
  final Future<void> Function()? onImport;
  final Future<void> Function()? onSync;
  final Future<void> Function()? onRename;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final binding = ref.watch(cloudSyncConfigurationForVaultProvider(vaultId));
    final configuration = binding.asData?.value;
    final workspace = configuration == null
        ? 'settingsVaultWorkspaceUnbound'.tr()
        : 'settingsVaultWorkspaceBound'.tr(args: [configuration.workspaceName]);
    final syncStatus = configuration == null
        ? 'settingsVaultSyncDisabled'.tr()
        : 'settingsVaultLastSync'.tr(
            args: [
              configuration.lastSyncedAt == null
                  ? 'settingsVaultNotYet'.tr()
                  : DateFormat.yMMMd().add_jm().format(
                      configuration.lastSyncedAt!,
                    ),
            ],
          );
    final tileBorderRadius = _sectionTileBorderRadius(position);
    return Material(
      color: active ? Theme.of(context).colorScheme.secondaryContainer : null,
      borderRadius: tileBorderRadius,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            contentPadding: _sectionTilePadding,
            shape: RoundedRectangleBorder(borderRadius: tileBorderRadius),
            leading: const Icon(Symbols.lock),
            title: Text(title),
            subtitle: Text('$workspace\n$syncStatus'),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<_VaultTileAction>(
                  onSelected: (action) {
                    if (action == _VaultTileAction.changeCloudBinding) {
                      _bindWorkspace(context, ref);
                    }
                    if (action == _VaultTileAction.rename) onRename?.call();
                    if (action == _VaultTileAction.delete) onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _VaultTileAction.changeCloudBinding,
                      child: Text('settingsVaultChangeCloudBinding'.tr()),
                    ),
                    if (onRename != null)
                      PopupMenuItem(
                        value: _VaultTileAction.rename,
                        child: Text('settingsVaultRename'.tr()),
                      ),
                    if (onDelete != null)
                      PopupMenuItem(
                        value: _VaultTileAction.delete,
                        child: Text('settingsVaultDelete'.tr()),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Symbols.chevron_right),
              ],
            ),
            onTap: () => onSelect(),
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
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: configuration == null || onSync == null
                        ? null
                        : () => onSync!(),
                    icon: const Icon(Symbols.sync),
                    label: const Text('settingsVaultSyncNow').tr(),
                  ),
                ],
              ),
            ),
        ],
      ),
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
      final workspace = await showModalBottomSheet<CloudWorkspace>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        useRootNavigator: true,
        builder: (sheetContext) => SheetScaffold(
          title: Text(title),
          heightFactor: 0.6,
          child: workspaces.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [const Text('settingsCloudSyncNoWorkspaces').tr()],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                            ? () => Navigator.of(sheetContext).pop(workspace)
                            : null,
                      ),
                  ],
                ),
        ),
      );
      if (workspace == null) return;
      await service.enable(workspace);
      ref.invalidate(cloudSyncConfigurationForVaultProvider(vaultId));
      ref.invalidate(cloudUserProvider);
    } on CloudSyncException catch (error) {
      if (context.mounted) showSnackBar(error.message);
    } catch (_) {
      if (context.mounted) showSnackBar('commonSomethingWentWrong'.tr());
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
