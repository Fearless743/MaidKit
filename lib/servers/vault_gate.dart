import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'server_providers.dart';
import 'cloud_sync_service.dart';
import 'database_backup_service.dart';

class VaultGate extends ConsumerStatefulWidget {
  const VaultGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends ConsumerState<VaultGate>
    with WidgetsBindingObserver {
  static const _defaultVaultOption = '__default_vault__';
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _unlocked = false;
  bool _busy = false;
  bool _preservePasswordDuringVaultSwitch = false;
  Timer? _autoSyncTimer;
  bool _autoSyncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _autoSync(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSyncTimer?.cancel();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoSync();
  }

  Future<void> _autoSync() async {
    if (!_unlocked || _autoSyncing || !mounted) return;
    _autoSyncing = true;
    try {
      final vault = ref.read(vaultServiceProvider);
      final password = await vault.syncPassphrase();
      if (password == null || !mounted) return;
      final sync = ref.read(cloudSyncServiceProvider);
      if (await sync.configuration() == null || !mounted) return;
      final backup = DatabaseBackupService(ref.read(databaseProvider), vault);
      await sync.sync(
        archive: await backup.exportArchive(password),
        applyArchive: (archive) => backup.importArchive(archive, password),
      );
      if (mounted) ref.invalidate(cloudSyncConfigurationProvider);
    } catch (_) {
      // Auto-sync is best effort. Manual sync remains available for errors.
    } finally {
      _autoSyncing = false;
    }
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
      var downloadedCloudVault = false;
      if (exists) {
        final ok = await vault.unlockWithPassword(_password.text);
        if (!ok) {
          throw StateError('vaultInvalidPassword'.tr());
        }
      } else {
        final sync = ref.read(cloudSyncServiceProvider);
        final configuration = await sync.configuration();
        final isCloudDownload = configuration?.pendingDownload == true;
        if (!isCloudDownload && _password.text != _confirmation.text) {
          throw StateError('vaultPasswordsDontMatch'.tr());
        }
        await vault.create(_password.text);
        if (isCloudDownload) {
          final backup = DatabaseBackupService(
            ref.read(databaseProvider),
            vault,
          );
          try {
            await sync.sync(
              archive: await backup.exportArchive(_password.text),
              applyArchive: (archive) =>
                  backup.importArchive(archive, _password.text),
              conflictResolution: CloudSyncConflictResolution.downloadRemote,
            );
            await sync.completePendingDownload();
            ref.invalidate(cloudSyncConfigurationProvider);
            downloadedCloudVault = true;
          } on CloudSyncException {
            await vault.discardNewVault();
            rethrow;
          } catch (_) {
            await vault.discardNewVault();
            throw StateError('vaultDownloadedPasswordInvalid'.tr());
          }
        }
      }
      if (mounted) {
        setState(() => _unlocked = true);
        if (!downloadedCloudVault) unawaited(_autoSync());
      }
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
      if (unlocked && mounted) {
        setState(() => _unlocked = true);
        unawaited(_autoSync());
      }
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted && !_unlocked) setState(() => _busy = false);
    }
  }

  Future<void> _openVaultFile() async {
    if (_busy) return;
    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['sqlite', 'db', 'maidkit'],
    );
    final path = selection?.files.singleOrNull?.path;
    if (path == null) return;
    try {
      final managedPath = await ref
          .read(vaultFileStorageProvider)
          .importVault(path);
      await ref.read(activeVaultFileProvider.notifier).select(managedPath);
    } on FileSystemException catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
      return;
    }
    if (mounted) {
      setState(() {
        _error = null;
        _password.clear();
        _confirmation.clear();
      });
    }
  }

  Future<void> _createVaultFile() async {
    if (_busy) return;
    final path = await ref.read(vaultFileStorageProvider).createVaultPath();
    await ref.read(activeVaultFileProvider.notifier).select(path);
    if (mounted) {
      setState(() {
        _error = null;
        _password.clear();
        _confirmation.clear();
      });
    }
  }

  Future<void> _createCloudVault() async {
    if (_busy) return;
    if (_password.text != _confirmation.text) {
      setState(() => _error = 'vaultPasswordsDontMatch'.tr());
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final path = await ref
          .read(vaultFileStorageProvider)
          .createVaultPath(name: 'Solarpass vault');
      _preservePasswordDuringVaultSwitch = true;
      await ref.read(activeVaultFileProvider.notifier).select(path);
      final vault = ref.read(vaultServiceProvider);
      await vault.create(_password.text);
      _preservePasswordDuringVaultSwitch = false;

      final service = ref.read(cloudSyncServiceForVaultProvider(path));
      final workspaces = await service.signInAndListWorkspaces();
      if (!mounted) return;
      final workspace = await _selectCloudWorkspace(workspaces);
      if (workspace == null) {
        if (mounted) setState(() => _unlocked = true);
        return;
      }
      await service.enable(workspace);
      final backup = DatabaseBackupService(
        ref.read(databaseProvider),
        ref.read(vaultServiceProvider),
      );
      await service.sync(
        archive: await backup.exportArchive(_password.text),
        applyArchive: (archive) =>
            backup.importArchive(archive, _password.text),
      );
      ref.invalidate(cloudSyncConfigurationForVaultProvider(path));
      if (mounted) setState(() => _unlocked = true);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      _preservePasswordDuringVaultSwitch = false;
      if (mounted && !_unlocked) setState(() => _busy = false);
    }
  }

  Future<CloudWorkspace?> _selectCloudWorkspace(
    List<CloudWorkspace> workspaces,
  ) => showDialog<CloudWorkspace>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('vaultCloudWorkspaceTitle'.tr()),
      content: SizedBox(
        width: 440,
        child: workspaces.isEmpty
            ? Text('settingsCloudSyncNoWorkspaces'.tr())
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
          child: Text('commonCancel'.tr()),
        ),
      ],
    ),
  );

  Future<void> _selectVault(String? path) async {
    if (_busy) return;
    await ref.read(activeVaultFileProvider.notifier).select(path);
    if (!mounted) return;
    setState(() {
      _error = null;
      _password.clear();
      _confirmation.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(activeVaultFileProvider, (previous, next) {
      if (previous != next && mounted) {
        setState(() {
          _unlocked = false;
          _error = null;
          if (!_preservePasswordDuringVaultSwitch) {
            _busy = false;
            _password.clear();
            _confirmation.clear();
          }
        });
      }
    });
    final exists = ref.watch(vaultExistsProvider);
    final biometricEnabled = ref.watch(biometricUnlockEnabledProvider);
    final cloudConfiguration = ref.watch(cloudSyncConfigurationProvider);
    final activeFile = ref.watch(activeVaultFileProvider);
    final vaultFiles = ref.watch(vaultFilesProvider);
    final theme = Theme.of(context);
    final showBiometricUnlock = biometricEnabled.asData?.value ?? false;
    final isCloudDownload =
        cloudConfiguration.asData?.value?.pendingDownload == true;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _unlocked
          ? KeyedSubtree(
              key: const ValueKey('vault_gate_unlocked'),
              child: widget.child,
            )
          : KeyedSubtree(
              key: const ValueKey('vault_gate_locked'),
              child: exists.when(
                loading: () => const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Scaffold(
                  body: Center(
                    child: Text('vaultOpenError'.tr(args: [error.toString()])),
                  ),
                ),
                data: (hasVault) => Scaffold(
                  body: SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Center(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.asset(
                                          'assets/icons/icon.png',
                                          width: 72,
                                          height: 72,
                                          errorBuilder: (_, _, _) => Container(
                                            width: 72,
                                            height: 72,
                                            alignment: Alignment.center,
                                            color: theme
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            child: Icon(
                                              Symbols.lock,
                                              size: 36,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      hasVault
                                          ? 'vaultUnlockTitle'.tr()
                                          : isCloudDownload
                                          ? 'vaultDownloadedTitle'.tr()
                                          : 'vaultCreateTitle'.tr(),
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      hasVault
                                          ? 'vaultUnlockSubtitle'.tr()
                                          : isCloudDownload
                                          ? 'vaultDownloadedSubtitle'.tr()
                                          : 'vaultCreateSubtitle'.tr(),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    DropdownButtonFormField<String>(
                                      key: ValueKey(activeFile),
                                      initialValue:
                                          activeFile ?? _defaultVaultOption,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: 'vaultSelectLabel'.tr(),
                                      ),
                                      onChanged: _busy
                                          ? null
                                          : (value) => _selectVault(
                                              value == _defaultVaultOption
                                                  ? null
                                                  : value,
                                            ),
                                      items: [
                                        DropdownMenuItem(
                                          value: _defaultVaultOption,
                                          child: Text('vaultDefaultName'.tr()),
                                        ),
                                        ...vaultFiles.map(
                                          (path) => DropdownMenuItem(
                                            value: path,
                                            child: Text(
                                              path
                                                  .split(Platform.pathSeparator)
                                                  .last,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _password,
                                      obscureText: true,
                                      autofocus: true,
                                      enabled: !_busy,
                                      onSubmitted: (_) => _submit(hasVault),
                                      decoration: InputDecoration(
                                        labelText: 'vaultPasswordLabel'.tr(),
                                        suffix: showBiometricUnlock
                                            ? IconButton(
                                                icon: const Icon(
                                                  Symbols.fingerprint,
                                                ),
                                                onPressed: _busy
                                                    ? null
                                                    : _unlockWithBiometrics,
                                                tooltip: 'vaultBiometricAction'
                                                    .tr(),
                                                constraints:
                                                    const BoxConstraints(),
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                iconSize: 20,
                                              )
                                            : null,
                                      ),
                                    ),
                                    if (!hasVault && !isCloudDownload) ...[
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: _confirmation,
                                        obscureText: true,
                                        enabled: !_busy,
                                        onSubmitted: (_) => _submit(false),
                                        decoration: InputDecoration(
                                          labelText: 'vaultConfirmPasswordLabel'
                                              .tr(),
                                        ),
                                      ),
                                    ],
                                    if (_error != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text(
                                          _error!,
                                          style: TextStyle(
                                            color: theme.colorScheme.error,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    FilledButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _submit(hasVault),
                                      child: _busy
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              hasVault
                                                  ? 'vaultUnlockAction'.tr()
                                                  : isCloudDownload
                                                  ? 'vaultDownloadedAction'.tr()
                                                  : 'vaultCreateAction'.tr(),
                                            ),
                                    ),
                                    if (!hasVault) ...[
                                      const SizedBox(height: 8),
                                      OutlinedButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : _createCloudVault,
                                        icon: const Icon(
                                          Symbols.cloud_download,
                                        ),
                                        label: Text(
                                          'vaultCreateFromCloudAction'.tr(),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: _busy ? null : _openVaultFile,
                                      icon: const Icon(Symbols.folder_open),
                                      label: Text('vaultOpenFileAction'.tr()),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : _createVaultFile,
                                      icon: const Icon(Symbols.add),
                                      label: Text('vaultCreateFileAction'.tr()),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
