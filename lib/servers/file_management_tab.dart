import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:dartssh2/dartssh2.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:super_context_menu/super_context_menu.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/shared/presentation/maidkit_alert.dart';
import 'package:maid_kit/shared/presentation/task_progress.dart';
import 'package:maid_kit/theme.dart';
import 'file_editor_tab.dart';
import 'server_connection_actions.dart';
import 'server_providers.dart';
import 'terminal_tabs_provider.dart';

enum _FileSide { local, remote }

enum _ClipboardMode { copy, cut }

class _TransferCancelled implements Exception {
  const _TransferCancelled();
}

class _TransferController {
  var _isPaused = false;
  var _isCancelled = false;
  Completer<void>? _resumeCompleter;

  bool get isCancelled => _isCancelled;

  void pause() {
    if (_isCancelled || _isPaused) return;
    _isPaused = true;
    _resumeCompleter = Completer<void>();
  }

  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    final completer = _resumeCompleter;
    _resumeCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    resume();
  }

  Future<void> waitIfPaused() async {
    throwIfCancelled();
    final completer = _resumeCompleter;
    if (_isPaused && completer != null) {
      await completer.future;
    }
    throwIfCancelled();
  }

  void throwIfCancelled() {
    if (_isCancelled) throw const _TransferCancelled();
  }
}

class _QueuedTransfer {
  const _QueuedTransfer({
    required this.id,
    required this.title,
    required this.totalBytes,
    required this.controller,
    required this.notify,
    required this.action,
    this.onSuccess,
    this.onFinish,
  });

  final String id;
  final String title;
  final int? totalBytes;
  final _TransferController controller;
  final bool notify;
  final Future<void> Function(_TransferController, void Function(int)) action;
  final Future<void> Function()? onSuccess;
  final Future<void> Function()? onFinish;
}

class _ClipboardEntry {
  const _ClipboardEntry({
    required this.side,
    required this.path,
    required this.name,
    required this.isDirectory,
  });

  final _FileSide side;
  final String path;
  final String name;
  final bool isDirectory;
}

class _FileClipboard {
  const _FileClipboard({required this.mode, required this.entries});

  final _ClipboardMode mode;
  final List<_ClipboardEntry> entries;

  bool get isEmpty => entries.isEmpty;
  bool get isNotEmpty => entries.isNotEmpty;
}

class _FileDragData {
  const _FileDragData({required this.side, required this.entries});

  final _FileSide side;
  final List<_ClipboardEntry> entries;
}

class FileManagementTabView extends ConsumerStatefulWidget {
  const FileManagementTabView({required this.tab, super.key});

  final FileManagementTab tab;

  @override
  ConsumerState<FileManagementTabView> createState() =>
      _FileManagementTabViewState();
}

class _FileManagementTabViewState extends ConsumerState<FileManagementTabView> {
  late Directory _localDirectory;
  var _remotePath = '.';
  List<FileSystemEntity> _localEntries = const [];
  List<SftpName> _remoteEntries = const [];
  var _loadingLocal = true;
  var _loadingRemote = true;
  String? _localError;
  String? _remoteError;
  String? _workingPath;
  final Queue<_QueuedTransfer> _transferQueue = Queue<_QueuedTransfer>();
  var _processingTransferQueue = false;
  var _draggingFiles = false;
  _FileSide? _dropTargetSide;
  Future<SftpClient>? _sftpClient;
  late final TextEditingController _remotePathController;
  late final FocusNode _remotePathFocusNode;
  late final FocusNode _shortcutFocusNode;

  Set<String> _selectedLocalPaths = {};
  Set<String> _selectedRemotePaths = {};
  int? _localAnchorIndex;
  int? _remoteAnchorIndex;
  _FileSide? _focusedSide;
  _FileClipboard? _clipboard;
  var _localCollapsed = false;

  @override
  void initState() {
    super.initState();
    _localDirectory = Directory.current;
    _remotePathController = TextEditingController(text: _remotePath);
    _remotePathFocusNode = FocusNode();
    _shortcutFocusNode = FocusNode(debugLabel: 'file-management-shortcuts');
    _refreshLocal();
    _refreshRemote();
  }

  @override
  void dispose() {
    for (final transfer in _transferQueue) {
      transfer.controller.cancel();
    }
    _transferQueue.clear();
    _remotePathController.dispose();
    _remotePathFocusNode.dispose();
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  Future<void> _refreshLocal() async {
    setState(() {
      _loadingLocal = true;
      _localError = null;
    });
    try {
      final entries = await _localDirectory.list().toList();
      entries.sort((a, b) {
        final directoryOrder =
            ((b is Directory) ? 1 : 0) - ((a is Directory) ? 1 : 0);
        return directoryOrder != 0
            ? directoryOrder
            : _entityName(
                a,
              ).toLowerCase().compareTo(_entityName(b).toLowerCase());
      });
      if (mounted) {
        final paths = entries.map((entry) => entry.path).toSet();
        setState(() {
          _localEntries = entries;
          _selectedLocalPaths = _selectedLocalPaths
              .where(paths.contains)
              .toSet();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _localError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingLocal = false);
    }
  }

  Future<void> _refreshRemote() async {
    setState(() {
      _loadingRemote = true;
      _remoteError = null;
    });
    try {
      final sftp = await _sftp();
      final absolutePath = await sftp.absolute(_remotePath);
      final entries = await sftp.listdir(absolutePath);
      entries.removeWhere(
        (entry) => entry.filename == '.' || entry.filename == '..',
      );
      entries.sort((a, b) {
        final directoryOrder =
            (b.attr.isDirectory ? 1 : 0) - (a.attr.isDirectory ? 1 : 0);
        return directoryOrder != 0
            ? directoryOrder
            : a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
      });
      if (mounted) {
        final paths = {
          for (final entry in entries)
            _joinRemotePath(absolutePath, entry.filename),
        };
        setState(() {
          _remotePath = absolutePath;
          _remoteEntries = entries;
          _selectedRemotePaths = _selectedRemotePaths
              .where(paths.contains)
              .toSet();
        });
        if (!_remotePathFocusNode.hasFocus) {
          _remotePathController.text = absolutePath;
        }
      }
    } catch (error) {
      if (mounted) setState(() => _remoteError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingRemote = false);
    }
  }

  Future<void> _chooseLocalDirectory() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose local folder',
      initialDirectory: _localDirectory.path,
    );
    if (path == null || !mounted) return;
    setState(() {
      _localDirectory = Directory(path);
      _selectedLocalPaths = {};
      _localAnchorIndex = null;
      _focusedSide = _FileSide.local;
    });
    await _refreshLocal();
  }

  Future<void> _openLocal(FileSystemEntity entry) async {
    if (entry is! Directory) return;
    setState(() {
      _localDirectory = entry;
      _selectedLocalPaths = {};
      _localAnchorIndex = null;
      _focusedSide = _FileSide.local;
    });
    await _refreshLocal();
  }

  Future<void> _openRemote(SftpName entry) async {
    if (!entry.attr.isDirectory) return;
    setState(() {
      _remotePath = _joinRemotePath(_remotePath, entry.filename);
      _selectedRemotePaths = {};
      _remoteAnchorIndex = null;
      _focusedSide = _FileSide.remote;
    });
    await _refreshRemote();
  }

  Future<void> _navigateRemote(String path) async {
    final destination = path.trim();
    if (destination.isEmpty) return;
    setState(() {
      _remotePath = destination;
      _selectedRemotePaths = {};
      _remoteAnchorIndex = null;
      _focusedSide = _FileSide.remote;
    });
    _remotePathFocusNode.unfocus();
    await _refreshRemote();
  }

  Future<void> _goUpLocal() async {
    final parent = _localDirectory.parent;
    if (parent.path == _localDirectory.path) return;
    setState(() {
      _localDirectory = parent;
      _selectedLocalPaths = {};
      _localAnchorIndex = null;
      _focusedSide = _FileSide.local;
    });
    await _refreshLocal();
  }

  Future<void> _goUpRemote() async {
    if (_remotePath == '/') return;
    final parent = _parentRemotePath(_remotePath);
    setState(() {
      _remotePath = parent;
      _selectedRemotePaths = {};
      _remoteAnchorIndex = null;
      _focusedSide = _FileSide.remote;
    });
    await _refreshRemote();
  }

  Future<void> _copyRemotePath() =>
      Clipboard.setData(ClipboardData(text: _remotePath));

  Future<void> _openTerminalHere() async {
    final servers = ref.read(serversProvider).asData?.value ?? const [];
    final server = servers
        .where((item) => item.id == widget.tab.serverId)
        .firstOrNull;
    if (server == null) {
      if (!mounted) return;
      showStyledSnackBar(
        message: 'The server for this file session is no longer available.',
        title: 'Could not open terminal',
        icon: Symbols.error,
        accentColor: Theme.of(context).colorScheme.error,
      );
      return;
    }
    await openTerminalSession(
      context,
      ref,
      server,
      initialDirectory: _remotePath,
    );
  }

  bool get _isMultiModifierPressed =>
      HardwareKeyboard.instance.isMetaPressed ||
      HardwareKeyboard.instance.isControlPressed;

  bool get _isRangeModifierPressed => HardwareKeyboard.instance.isShiftPressed;

  void _selectLocal(
    FileSystemEntity entry, {
    required int index,
    bool toggle = false,
    bool range = false,
  }) {
    setState(() {
      _focusedSide = _FileSide.local;
      _selectedRemotePaths = {};
      _remoteAnchorIndex = null;
      if (range && _localAnchorIndex != null) {
        final start = math.min(_localAnchorIndex!, index);
        final end = math.max(_localAnchorIndex!, index);
        _selectedLocalPaths = {
          for (var i = start; i <= end && i < _localEntries.length; i++)
            _localEntries[i].path,
        };
      } else if (toggle) {
        final next = {..._selectedLocalPaths};
        if (!next.add(entry.path)) next.remove(entry.path);
        _selectedLocalPaths = next;
        _localAnchorIndex = index;
      } else {
        _selectedLocalPaths = {entry.path};
        _localAnchorIndex = index;
      }
    });
  }

  void _selectRemote(
    SftpName entry, {
    required int index,
    bool toggle = false,
    bool range = false,
  }) {
    final path = _joinRemotePath(_remotePath, entry.filename);
    setState(() {
      _focusedSide = _FileSide.remote;
      _selectedLocalPaths = {};
      _localAnchorIndex = null;
      if (range && _remoteAnchorIndex != null) {
        final start = math.min(_remoteAnchorIndex!, index);
        final end = math.max(_remoteAnchorIndex!, index);
        _selectedRemotePaths = {
          for (var i = start; i <= end && i < _remoteEntries.length; i++)
            _joinRemotePath(_remotePath, _remoteEntries[i].filename),
        };
      } else if (toggle) {
        final next = {..._selectedRemotePaths};
        if (!next.add(path)) next.remove(path);
        _selectedRemotePaths = next;
        _remoteAnchorIndex = index;
      } else {
        _selectedRemotePaths = {path};
        _remoteAnchorIndex = index;
      }
    });
  }

  void _ensureLocalContextSelection(FileSystemEntity entry, int index) {
    if (_selectedLocalPaths.contains(entry.path)) {
      setState(() {
        _focusedSide = _FileSide.local;
        _selectedRemotePaths = {};
      });
      return;
    }
    _selectLocal(entry, index: index);
  }

  void _ensureRemoteContextSelection(SftpName entry, int index) {
    final path = _joinRemotePath(_remotePath, entry.filename);
    if (_selectedRemotePaths.contains(path)) {
      setState(() {
        _focusedSide = _FileSide.remote;
        _selectedLocalPaths = {};
      });
      return;
    }
    _selectRemote(entry, index: index);
  }

  void _focusSide(_FileSide side) {
    if (_focusedSide == side) return;
    setState(() => _focusedSide = side);
  }

  void _selectAllOnFocusedSide() {
    final side = _focusedSide;
    if (side == null) return;
    setState(() {
      if (side == _FileSide.local) {
        _selectedLocalPaths = {for (final entry in _localEntries) entry.path};
        _selectedRemotePaths = {};
        _localAnchorIndex = _localEntries.isEmpty ? null : 0;
      } else {
        _selectedRemotePaths = {
          for (final entry in _remoteEntries)
            _joinRemotePath(_remotePath, entry.filename),
        };
        _selectedLocalPaths = {};
        _remoteAnchorIndex = _remoteEntries.isEmpty ? null : 0;
      }
    });
  }

  List<_ClipboardEntry> _entriesForSelection(_FileSide side) {
    if (side == _FileSide.local) {
      return [
        for (final entity in _localEntries)
          if (_selectedLocalPaths.contains(entity.path))
            _ClipboardEntry(
              side: _FileSide.local,
              path: entity.path,
              name: _entityName(entity),
              isDirectory: entity is Directory,
            ),
      ];
    }
    return [
      for (final entry in _remoteEntries)
        if (_selectedRemotePaths.contains(
          _joinRemotePath(_remotePath, entry.filename),
        ))
          _ClipboardEntry(
            side: _FileSide.remote,
            path: _joinRemotePath(_remotePath, entry.filename),
            name: entry.filename,
            isDirectory: entry.attr.isDirectory,
          ),
    ];
  }

  _ClipboardEntry _clipboardEntryForLocal(FileSystemEntity entity) =>
      _ClipboardEntry(
        side: _FileSide.local,
        path: entity.path,
        name: _entityName(entity),
        isDirectory: entity is Directory,
      );

  _ClipboardEntry _clipboardEntryForRemote(SftpName entry) => _ClipboardEntry(
    side: _FileSide.remote,
    path: _joinRemotePath(_remotePath, entry.filename),
    name: entry.filename,
    isDirectory: entry.attr.isDirectory,
  );

  _FileDragData _dragDataForLocal(FileSystemEntity entry) {
    final selected = _selectedLocalPaths.contains(entry.path)
        ? _entriesForSelection(_FileSide.local)
        : [_clipboardEntryForLocal(entry)];
    return _FileDragData(side: _FileSide.local, entries: selected);
  }

  _FileDragData _dragDataForRemote(SftpName entry) {
    final path = _joinRemotePath(_remotePath, entry.filename);
    final selected = _selectedRemotePaths.contains(path)
        ? _entriesForSelection(_FileSide.remote)
        : [_clipboardEntryForRemote(entry)];
    return _FileDragData(side: _FileSide.remote, entries: selected);
  }

  void _setClipboard(_ClipboardMode mode) {
    final side = _focusedSide;
    if (side == null) return;
    final entries = _entriesForSelection(side);
    if (entries.isEmpty) return;
    setState(() {
      _clipboard = _FileClipboard(mode: mode, entries: entries);
    });
    if (!mounted) return;
    final label = entries.length == 1
        ? entries.first.name
        : '${entries.length} items';
    showStyledSnackBar(
      message: label,
      title: mode == _ClipboardMode.copy
          ? 'fileManagerCopied'.tr()
          : 'fileManagerCut'.tr(),
      icon: mode == _ClipboardMode.copy
          ? Symbols.content_copy
          : Symbols.content_cut,
      accentColor: Theme.of(context).colorScheme.primary,
    );
  }

  Future<void> _handleInternalDrop(
    _FileDragData data,
    _FileSide targetSide,
  ) async {
    if (data.side == targetSide || data.entries.isEmpty) {
      return;
    }
    setState(() {
      _focusedSide = targetSide;
      _dropTargetSide = null;
    });
    try {
      for (final entry in data.entries) {
        if (entry.side == _FileSide.local && targetSide == _FileSide.remote) {
          await _transferLocalToRemote(entry, notify: false);
        } else if (entry.side == _FileSide.remote &&
            targetSide == _FileSide.local) {
          await _transferRemoteToLocal(entry, notify: false);
        }
      }
      if (mounted) {
        showStyledSnackBar(
          message: data.entries.length == 1
              ? data.entries.first.name
              : '${data.entries.length} items',
          title: 'Transfer queued',
          icon: Symbols.schedule,
          accentColor: Theme.of(context).colorScheme.primary,
        );
      }
    } catch (error) {
      if (mounted) {
        showStyledSnackBar(
          message: error.toString(),
          title: 'fileManagerDropFailed'.tr(),
          icon: Symbols.error,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<void> _pasteInto(_FileSide targetSide) async {
    final clipboard = _clipboard;
    if (clipboard == null || clipboard.isEmpty || !_canPasteInto(targetSide)) {
      return;
    }
    final transferPaste = clipboard.entries.any(
      (entry) => entry.side != targetSide,
    );

    setState(() => _focusedSide = targetSide);
    try {
      for (final entry in clipboard.entries) {
        await _pasteEntry(entry, clipboard.mode, targetSide);
      }
      if (clipboard.mode == _ClipboardMode.cut) {
        setState(() => _clipboard = null);
      }
      if (mounted) {
        showStyledSnackBar(
          message: transferPaste
              ? '${clipboard.entries.length} transfer task${clipboard.entries.length == 1 ? '' : 's'}'
              : clipboard.mode == _ClipboardMode.cut
              ? 'Items moved'
              : 'Items pasted',
          title: transferPaste ? 'Transfer queued' : 'fileManagerDone'.tr(),
          icon: transferPaste ? Symbols.schedule : Symbols.check_circle,
          accentColor: Theme.of(context).colorScheme.primary,
        );
      }
    } catch (error) {
      if (mounted) {
        showStyledSnackBar(
          message: error.toString(),
          title: 'fileManagerPasteFailed'.tr(),
          icon: Symbols.error,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<void> _pasteEntry(
    _ClipboardEntry entry,
    _ClipboardMode mode,
    _FileSide targetSide,
  ) async {
    if (entry.side == targetSide && mode == _ClipboardMode.cut) {
      await _moveSameSide(entry, targetSide);
      return;
    }
    if (entry.side == targetSide && mode == _ClipboardMode.copy) {
      await _copySameSide(entry, targetSide);
      return;
    }
    if (entry.side == _FileSide.local && targetSide == _FileSide.remote) {
      if (mode == _ClipboardMode.cut) {
        await _transferLocalToRemote(
          entry,
          notify: false,
          onSuccess: () => _deleteEntry(entry, confirm: false, notify: false),
        );
      } else {
        await _transferLocalToRemote(entry, notify: false);
      }
      return;
    }
    if (entry.side == _FileSide.remote && targetSide == _FileSide.local) {
      if (mode == _ClipboardMode.cut) {
        await _transferRemoteToLocal(
          entry,
          notify: false,
          onSuccess: () => _deleteEntry(entry, confirm: false, notify: false),
        );
      } else {
        await _transferRemoteToLocal(entry, notify: false);
      }
    }
  }

  bool _canPasteInto(_FileSide targetSide) {
    final clipboard = _clipboard;
    if (clipboard == null || clipboard.isEmpty) return false;
    final transferPaste = clipboard.entries.any(
      (entry) => entry.side != targetSide,
    );
    return transferPaste || _workingPath == null;
  }

  Future<void> _moveSameSide(_ClipboardEntry entry, _FileSide side) async {
    if (side == _FileSide.local) {
      final destinationDir = _localDirectory.path;
      if (File(entry.path).parent.path == destinationDir ||
          Directory(entry.path).parent.path == destinationDir) {
        return;
      }
      final destination = await _uniqueLocalPath(destinationDir, entry.name);
      if (entry.isDirectory) {
        await Directory(entry.path).rename(destination);
      } else {
        await File(entry.path).rename(destination);
      }
      await _refreshLocal();
      return;
    }

    final destinationDir = _remotePath;
    if (_parentRemotePath(entry.path) == destinationDir) return;
    final sftp = await _sftp();
    final destination = await _uniqueRemotePath(
      sftp,
      destinationDir,
      entry.name,
    );
    await sftp.rename(entry.path, destination);
    await _refreshRemote();
  }

  Future<void> _copySameSide(_ClipboardEntry entry, _FileSide side) async {
    if (side == _FileSide.local) {
      final destination = await _uniqueLocalPath(
        _localDirectory.path,
        entry.name,
      );
      if (entry.isDirectory) {
        await _copyLocalDirectory(
          Directory(entry.path),
          Directory(destination),
        );
      } else {
        await File(entry.path).copy(destination);
      }
      await _refreshLocal();
      return;
    }

    final sftp = await _sftp();
    final destination = await _uniqueRemotePath(sftp, _remotePath, entry.name);
    if (entry.isDirectory) {
      await _copyRemoteDirectory(sftp, entry.path, destination);
    } else {
      await _copyRemoteFile(sftp, entry.path, destination);
    }
    await _refreshRemote();
  }

  Future<void> _transferLocalToRemote(
    _ClipboardEntry entry, {
    bool notify = true,
    Future<void> Function()? onSuccess,
  }) async {
    if (entry.isDirectory) {
      await _uploadDirectory(
        Directory(entry.path),
        entry.name,
        notify: notify,
        onSuccess: onSuccess,
      );
    } else {
      await _upload(File(entry.path), notify: notify, onSuccess: onSuccess);
    }
  }

  Future<void> _transferRemoteToLocal(
    _ClipboardEntry entry, {
    bool notify = true,
    Future<void> Function()? onSuccess,
  }) async {
    if (entry.isDirectory) {
      await _downloadDirectory(
        entry.path,
        entry.name,
        notify: notify,
        onSuccess: onSuccess,
      );
    } else {
      final sftpName = _remoteEntries
          .where((item) => item.filename == entry.name)
          .firstOrNull;
      if (sftpName != null) {
        await _download(sftpName, notify: notify, onSuccess: onSuccess);
      } else {
        await _downloadPath(
          entry.path,
          entry.name,
          null,
          notify: notify,
          onSuccess: onSuccess,
        );
      }
    }
  }

  Future<void> _deleteSelection() async {
    final side = _focusedSide;
    if (side == null) return;
    final entries = _entriesForSelection(side);
    if (entries.isEmpty) return;
    await _deleteEntries(entries, confirm: true);
  }

  Future<void> _deleteEntries(
    List<_ClipboardEntry> entries, {
    required bool confirm,
    bool notify = true,
  }) async {
    if (entries.isEmpty) return;
    if (confirm) {
      final label = entries.length == 1
          ? entries.first.name
          : '${entries.length} items';
      final message = entries.length == 1 && entries.first.isDirectory
          ? 'This folder and its contents will be permanently removed.'
          : entries.length == 1
          ? 'This file will be permanently removed.'
          : 'Selected files and folders will be permanently removed.';
      final approved = await showMaidKitConfirmAlert(
        message,
        'Delete $label?',
        isDanger: true,
      );
      if (!approved || !mounted) return;
    }

    try {
      final deletedLocal = <String>{};
      final deletedRemote = <String>{};
      for (final entry in entries) {
        if (entry.side == _FileSide.local) {
          if (entry.isDirectory) {
            await Directory(entry.path).delete(recursive: true);
          } else {
            await File(entry.path).delete();
          }
          deletedLocal.add(entry.path);
        } else {
          final sftp = await _sftp();
          if (entry.isDirectory) {
            await _deleteRemoteDirectory(sftp, entry.path);
          } else {
            await sftp.remove(entry.path);
          }
          deletedRemote.add(entry.path);
        }
      }
      if (deletedLocal.isNotEmpty) {
        setState(() {
          _selectedLocalPaths = _selectedLocalPaths
              .difference(deletedLocal)
              .toSet();
        });
        await _refreshLocal();
      }
      if (deletedRemote.isNotEmpty) {
        setState(() {
          _selectedRemotePaths = _selectedRemotePaths
              .difference(deletedRemote)
              .toSet();
        });
        await _refreshRemote();
      }
      if (notify && mounted) {
        showStyledSnackBar(
          message: entries.length == 1
              ? entries.first.name
              : '${entries.length} items',
          title: 'fileManagerDeleted'.tr(),
          icon: Symbols.delete,
          accentColor: Theme.of(context).colorScheme.primary,
        );
      }
    } catch (error) {
      if (notify && mounted) {
        showStyledSnackBar(
          message: error.toString(),
          title: 'fileManagerDeleteFailed'.tr(),
          icon: Symbols.error,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
      rethrow;
    }
  }

  Future<void> _deleteEntry(
    _ClipboardEntry entry, {
    required bool confirm,
    bool notify = true,
  }) => _deleteEntries([entry], confirm: confirm, notify: notify);

  Future<void> _upload(
    FileSystemEntity entry, {
    bool notify = true,
    Future<void> Function()? onSuccess,
    Future<void> Function()? onFinish,
  }) async {
    if (entry is! File) return;
    final totalBytes = await entry.length();
    await _runTransfer(
      title: 'Uploading ${_entityName(entry)}',
      totalBytes: totalBytes,
      notify: notify,
      action: (controller, reportProgress) async {
        final sftp = await _sftp();
        final remotePath = await _uniqueRemotePath(
          sftp,
          _remotePath,
          _entityName(entry),
        );
        final remoteFile = await sftp.open(
          remotePath,
          mode:
              SftpFileOpenMode.write |
              SftpFileOpenMode.create |
              SftpFileOpenMode.truncate,
        );
        try {
          var transferredBytes = 0;
          await for (final chunk in entry.openRead().map(Uint8List.fromList)) {
            await controller.waitIfPaused();
            await remoteFile.writeBytes(chunk, offset: transferredBytes);
            transferredBytes += chunk.length;
            reportProgress(transferredBytes);
          }
        } finally {
          await remoteFile.close();
          if (controller.isCancelled) {
            try {
              await sftp.remove(remotePath);
            } catch (_) {}
          }
        }
        await _refreshRemote();
      },
      onSuccess: onSuccess,
      onFinish: onFinish,
    );
  }

  Future<void> _uploadDirectory(
    Directory directory,
    String name, {
    bool notify = true,
    Future<void> Function()? onSuccess,
    Future<void> Function()? onFinish,
  }) async {
    await _runTransfer(
      title: 'Uploading $name',
      totalBytes: null,
      notify: notify,
      action: (controller, reportProgress) async {
        final sftp = await _sftp();
        final remoteRoot = await _uniqueRemotePath(sftp, _remotePath, name);
        try {
          await _uploadLocalDirectory(
            sftp,
            directory,
            remoteRoot,
            controller: controller,
            reportProgress: reportProgress,
          );
        } finally {
          if (controller.isCancelled) {
            try {
              await _deleteRemoteDirectory(sftp, remoteRoot);
            } catch (_) {}
          }
        }
        await _refreshRemote();
      },
      onSuccess: onSuccess,
      onFinish: onFinish,
    );
  }

  Future<int> _uploadLocalDirectory(
    SftpClient sftp,
    Directory local,
    String remotePath, {
    _TransferController? controller,
    void Function(int)? reportProgress,
    int transferredBytes = 0,
  }) async {
    await controller?.waitIfPaused();
    await sftp.mkdir(remotePath);
    await for (final entity in local.list(followLinks: false)) {
      await controller?.waitIfPaused();
      final name = _entityName(entity);
      final childRemote = _joinRemotePath(remotePath, name);
      if (entity is Directory) {
        transferredBytes = await _uploadLocalDirectory(
          sftp,
          entity,
          childRemote,
          controller: controller,
          reportProgress: reportProgress,
          transferredBytes: transferredBytes,
        );
      } else if (entity is File) {
        final remoteFile = await sftp.open(
          childRemote,
          mode:
              SftpFileOpenMode.write |
              SftpFileOpenMode.create |
              SftpFileOpenMode.truncate,
        );
        try {
          var fileOffset = 0;
          await for (final chunk in entity.openRead().map(Uint8List.fromList)) {
            await controller?.waitIfPaused();
            await remoteFile.writeBytes(chunk, offset: fileOffset);
            fileOffset += chunk.length;
            transferredBytes += chunk.length;
            reportProgress?.call(transferredBytes);
          }
        } finally {
          await remoteFile.close();
        }
      }
    }
    return transferredBytes;
  }

  Future<void> _uploadDroppedFiles(List<DropItem> items) async {
    for (final item in items.whereType<DropItemFile>()) {
      final bookmark = item.extraAppleBookmark;
      final hasSecurityScopedAccess =
          bookmark != null &&
          await DesktopDrop.instance.startAccessingSecurityScopedResource(
            bookmark: bookmark,
          );
      await _upload(
        File(item.path),
        onFinish: hasSecurityScopedAccess
            ? () => DesktopDrop.instance.stopAccessingSecurityScopedResource(
                bookmark: bookmark,
              )
            : null,
      );
    }
  }

  Future<void> _download(
    SftpName entry, {
    bool notify = true,
    Future<void> Function()? onSuccess,
    Future<void> Function()? onFinish,
  }) async {
    if (!entry.attr.isFile) return;
    await _downloadPath(
      _joinRemotePath(_remotePath, entry.filename),
      entry.filename,
      entry.attr.size,
      notify: notify,
      onSuccess: onSuccess,
      onFinish: onFinish,
    );
  }

  Future<void> _downloadPath(
    String remotePath,
    String filename,
    int? totalBytes, {
    bool notify = true,
    Future<void> Function()? onSuccess,
    Future<void> Function()? onFinish,
  }) async {
    await _runTransfer(
      title: 'Downloading $filename',
      totalBytes: totalBytes,
      notify: notify,
      action: (controller, reportProgress) async {
        final sftp = await _sftp();
        final destinationPath = await _uniqueLocalPath(
          _localDirectory.path,
          filename,
        );
        final destination = File(destinationPath);
        final remoteFile = await sftp.open(
          remotePath,
          mode: SftpFileOpenMode.read,
        );
        final sink = destination.openWrite();
        var transferredBytes = 0;
        try {
          await for (final chunk in remoteFile.read(
            length: totalBytes,
            chunkSize: 64 * 1024,
            maxPendingRequests: 4,
          )) {
            await controller.waitIfPaused();
            sink.add(chunk);
            transferredBytes += chunk.length;
            reportProgress(transferredBytes);
            if (transferredBytes % (1024 * 1024) < chunk.length) {
              await sink.flush();
            }
          }
        } finally {
          await sink.close();
          await remoteFile.close();
          if (controller.isCancelled) {
            try {
              await destination.delete();
            } catch (_) {}
          }
        }
        await _refreshLocal();
      },
      onSuccess: onSuccess,
      onFinish: onFinish,
    );
  }

  Future<void> _downloadDirectory(
    String remotePath,
    String name, {
    bool notify = true,
    Future<void> Function()? onSuccess,
    Future<void> Function()? onFinish,
  }) async {
    await _runTransfer(
      title: 'Downloading $name',
      totalBytes: null,
      notify: notify,
      action: (controller, reportProgress) async {
        final sftp = await _sftp();
        final localRoot = await _uniqueLocalPath(_localDirectory.path, name);
        final localDirectory = Directory(localRoot);
        try {
          await _downloadRemoteDirectory(
            sftp,
            remotePath,
            localDirectory,
            controller: controller,
            reportProgress: reportProgress,
          );
        } finally {
          if (controller.isCancelled) {
            try {
              await localDirectory.delete(recursive: true);
            } catch (_) {}
          }
        }
        await _refreshLocal();
      },
      onSuccess: onSuccess,
      onFinish: onFinish,
    );
  }

  Future<int> _downloadRemoteDirectory(
    SftpClient sftp,
    String remotePath,
    Directory local, {
    _TransferController? controller,
    void Function(int)? reportProgress,
    int transferredBytes = 0,
  }) async {
    await controller?.waitIfPaused();
    await local.create(recursive: true);
    final entries = await sftp.listdir(remotePath);
    for (final entry in entries) {
      if (entry.filename == '.' || entry.filename == '..') continue;
      await controller?.waitIfPaused();
      final childRemote = _joinRemotePath(remotePath, entry.filename);
      final childLocal = local.uri.resolve(entry.filename).toFilePath();
      if (entry.attr.isDirectory) {
        transferredBytes = await _downloadRemoteDirectory(
          sftp,
          childRemote,
          Directory(childLocal),
          controller: controller,
          reportProgress: reportProgress,
          transferredBytes: transferredBytes,
        );
      } else if (entry.attr.isFile) {
        final remoteFile = await sftp.open(
          childRemote,
          mode: SftpFileOpenMode.read,
        );
        final sink = File(childLocal).openWrite();
        try {
          await for (final chunk in remoteFile.read(
            length: entry.attr.size,
            chunkSize: 64 * 1024,
            maxPendingRequests: 4,
          )) {
            await controller?.waitIfPaused();
            sink.add(chunk);
            transferredBytes += chunk.length;
            reportProgress?.call(transferredBytes);
          }
        } finally {
          await sink.close();
          await remoteFile.close();
        }
      }
    }
    return transferredBytes;
  }

  Future<void> _copyLocalDirectory(
    Directory source,
    Directory destination,
  ) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final name = _entityName(entity);
      final child = destination.uri.resolve(name).toFilePath();
      if (entity is Directory) {
        await _copyLocalDirectory(entity, Directory(child));
      } else if (entity is File) {
        await entity.copy(child);
      }
    }
  }

  Future<void> _copyRemoteFile(
    SftpClient sftp,
    String source,
    String destination,
  ) async {
    final remoteFile = await sftp.open(
      destination,
      mode:
          SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate,
    );
    try {
      final sourceFile = await sftp.open(source, mode: SftpFileOpenMode.read);
      try {
        final data = await sourceFile.readBytes();
        await remoteFile.writeBytes(data);
      } finally {
        await sourceFile.close();
      }
    } finally {
      await remoteFile.close();
    }
  }

  Future<void> _copyRemoteDirectory(
    SftpClient sftp,
    String source,
    String destination,
  ) async {
    await sftp.mkdir(destination);
    final entries = await sftp.listdir(source);
    for (final entry in entries) {
      if (entry.filename == '.' || entry.filename == '..') continue;
      final childSource = _joinRemotePath(source, entry.filename);
      final childDestination = _joinRemotePath(destination, entry.filename);
      if (entry.attr.isDirectory) {
        await _copyRemoteDirectory(sftp, childSource, childDestination);
      } else if (entry.attr.isFile) {
        await _copyRemoteFile(sftp, childSource, childDestination);
      }
    }
  }

  Future<void> _deleteRemoteDirectory(SftpClient sftp, String path) async {
    final entries = await sftp.listdir(path);
    for (final entry in entries) {
      if (entry.filename == '.' || entry.filename == '..') continue;
      final child = _joinRemotePath(path, entry.filename);
      if (entry.attr.isDirectory) {
        await _deleteRemoteDirectory(sftp, child);
      } else {
        await sftp.remove(child);
      }
    }
    await sftp.rmdir(path);
  }

  Future<String> _uniqueLocalPath(String directory, String name) async {
    var candidate = '$directory${Platform.pathSeparator}$name';
    if (!await FileSystemEntity.type(
      candidate,
    ).then((type) => type != FileSystemEntityType.notFound)) {
      return candidate;
    }
    final dot = name.lastIndexOf('.');
    final hasExtension = dot > 0 && !name.startsWith('.');
    final stem = hasExtension ? name.substring(0, dot) : name;
    final extension = hasExtension ? name.substring(dot) : '';
    var index = 1;
    while (true) {
      candidate = '$directory${Platform.pathSeparator}$stem ($index)$extension';
      final exists = await FileSystemEntity.type(
        candidate,
      ).then((type) => type != FileSystemEntityType.notFound);
      if (!exists) return candidate;
      index += 1;
    }
  }

  Future<String> _uniqueRemotePath(
    SftpClient sftp,
    String directory,
    String name,
  ) async {
    var candidate = _joinRemotePath(directory, name);
    if (!await _remoteExists(sftp, candidate)) return candidate;
    final dot = name.lastIndexOf('.');
    final hasExtension = dot > 0 && !name.startsWith('.');
    final stem = hasExtension ? name.substring(0, dot) : name;
    final extension = hasExtension ? name.substring(dot) : '';
    var index = 1;
    while (true) {
      candidate = _joinRemotePath(directory, '$stem ($index)$extension');
      if (!await _remoteExists(sftp, candidate)) return candidate;
      index += 1;
    }
  }

  Future<bool> _remoteExists(SftpClient sftp, String path) async {
    try {
      await sftp.stat(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _runTransfer({
    required String title,
    required int? totalBytes,
    required Future<void> Function(_TransferController, void Function(int))
    action,
    bool notify = true,
    Future<void> Function()? onSuccess,
    Future<void> Function()? onFinish,
  }) async {
    final controller = _TransferController();
    final taskId = ref
        .read(taskProgressProvider.notifier)
        .start(
          title: title,
          totalBytes: totalBytes,
          status: TaskProgressStatus.queued,
          onCancel: controller.cancel,
        );
    _transferQueue.add(
      _QueuedTransfer(
        id: taskId,
        title: title,
        totalBytes: totalBytes,
        controller: controller,
        notify: notify,
        action: action,
        onSuccess: onSuccess,
        onFinish: onFinish,
      ),
    );
    _processTransferQueue();
  }

  void _processTransferQueue() {
    if (_processingTransferQueue) return;
    _processingTransferQueue = true;
    unawaited(_drainTransferQueue());
  }

  Future<void> _drainTransferQueue() async {
    try {
      while (_transferQueue.isNotEmpty) {
        final transfer = _transferQueue.removeFirst();
        if (transfer.controller.isCancelled) continue;
        await _executeQueuedTransfer(transfer);
      }
    } finally {
      _processingTransferQueue = false;
      if (_transferQueue.isNotEmpty) _processTransferQueue();
    }
  }

  Future<void> _executeQueuedTransfer(_QueuedTransfer transfer) async {
    final controller = transfer.controller;
    ref
        .read(taskProgressProvider.notifier)
        .startRunning(
          transfer.id,
          onPause: controller.pause,
          onResume: controller.resume,
          onCancel: controller.cancel,
        );
    Timer? progressTimer;
    var pendingBytes = 0;
    var hasPendingProgress = false;
    var lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);

    void flushProgress() {
      progressTimer?.cancel();
      progressTimer = null;
      if (!hasPendingProgress) return;
      hasPendingProgress = false;
      lastProgressAt = DateTime.now();
      ref.read(taskProgressProvider.notifier).update(transfer.id, pendingBytes);
    }

    void reportProgress(int transferredBytes) {
      pendingBytes = transferredBytes;
      hasPendingProgress = true;
      final elapsed = DateTime.now().difference(lastProgressAt);
      if (elapsed >= const Duration(milliseconds: 250)) {
        flushProgress();
        return;
      }
      progressTimer ??= Timer(
        const Duration(milliseconds: 250) - elapsed,
        flushProgress,
      );
    }

    if (mounted) setState(() => _workingPath = transfer.title);
    try {
      await transfer.action(controller, reportProgress);
      controller.throwIfCancelled();
      flushProgress();
      if (transfer.onSuccess != null) {
        await transfer.onSuccess!();
      }
      ref.read(taskProgressProvider.notifier).complete(transfer.id);
      if (transfer.notify && mounted) {
        showStyledSnackBar(
          message: transfer.title,
          title: 'fileManagerTransferComplete'.tr(),
          icon: Symbols.check_circle,
          accentColor: Theme.of(context).colorScheme.primary,
        );
      }
    } on _TransferCancelled {
      flushProgress();
      await ref.read(taskProgressProvider.notifier).cancel(transfer.id);
    } catch (error) {
      flushProgress();
      ref.read(taskProgressProvider.notifier).fail(transfer.id);
      if (transfer.notify && mounted) {
        showStyledSnackBar(
          message: error.toString(),
          title: 'fileManagerTransferFailed'.tr(),
          icon: Symbols.error,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
      // Re-throw for compound ops (paste) that silence notifications and
      // handle failures themselves. Direct upload/download already notified.
    } finally {
      progressTimer?.cancel();
      if (transfer.onFinish != null) {
        await transfer.onFinish!();
      }
      if (mounted) setState(() => _workingPath = null);
    }
  }

  Future<SftpClient> _sftp() => _sftpClient ??= ref
      .read(connectionManagerProvider)
      .withClient(widget.tab.serverId, (client) => client.sftp());

  Future<void> _editLocal(File file) async {
    final server = _serverForTab();
    if (server == null) return;
    try {
      final length = await file.length();
      validateEditableText(length, file.path);
    } catch (error) {
      if (!mounted) return;
      showMaidKitErrorAlert(
        error,
        title: 'fileManagerCouldNotOpen'.tr(args: [_entityName(file)]),
      );
      return;
    }
    ref
        .read(terminalTabsProvider.notifier)
        .openFileEditor(
          server: server,
          path: file.path,
          fileName: _entityName(file),
          isRemote: false,
        );
  }

  Future<void> _editRemote(SftpName entry) async {
    final server = _serverForTab();
    if (server == null) return;
    final path = _joinRemotePath(_remotePath, entry.filename);
    try {
      validateEditableText(entry.attr.size, path);
    } catch (error) {
      if (!mounted) return;
      showMaidKitErrorAlert(
        error,
        title: 'fileManagerCouldNotOpen'.tr(args: [entry.filename]),
      );
      return;
    }
    ref
        .read(terminalTabsProvider.notifier)
        .openFileEditor(
          server: server,
          path: path,
          fileName: entry.filename,
          isRemote: true,
        );
  }

  Server? _serverForTab() {
    final servers = ref.read(serversProvider).asData?.value ?? const [];
    final server = servers
        .where((item) => item.id == widget.tab.serverId)
        .firstOrNull;
    if (server == null && mounted) {
      showStyledSnackBar(
        message: 'The server for this file session is no longer available.',
        title: 'fileManagerCouldNotOpen'.tr(args: ['']),
        icon: Symbols.error,
        accentColor: Theme.of(context).colorScheme.error,
      );
    }
    return server;
  }

  Menu _localEntryMenu(FileSystemEntity entry, int index) {
    final selected = _entriesForSelection(_FileSide.local);
    final entries = selected.isEmpty
        ? [_clipboardEntryForLocal(entry)]
        : selected;
    final onlyThis = entries.length == 1 && entries.first.path == entry.path;
    final isDirectory = entry is Directory;
    final busy = _workingPath != null;
    final canPaste = _canPasteInto(_FileSide.local);
    final transferLabel = entries.length == 1
        ? 'Upload to remote'
        : 'Upload ${entries.length} items';
    return Menu(
      children: [
        if (onlyThis && isDirectory)
          MenuAction(
            title: 'fileManagerOpen'.tr(),
            callback: () => _openLocal(entry),
          ),
        if (onlyThis && entry is File)
          MenuAction(
            title: 'fileManagerEdit'.tr(),
            callback: () => _editLocal(entry),
          ),
        MenuAction(
          title: transferLabel,
          callback: () async {
            _ensureLocalContextSelection(entry, index);
            for (final item in _entriesForSelection(_FileSide.local)) {
              await _transferLocalToRemote(item);
            }
          },
        ),
        MenuSeparator(),
        MenuAction(
          title: 'commonCopy'.tr(),
          activator: const SingleActivator(LogicalKeyboardKey.keyC, meta: true),
          callback: () {
            _ensureLocalContextSelection(entry, index);
            _setClipboard(_ClipboardMode.copy);
          },
        ),
        MenuAction(
          title: 'fileManagerCut'.tr(),
          activator: const SingleActivator(LogicalKeyboardKey.keyX, meta: true),
          callback: () {
            _ensureLocalContextSelection(entry, index);
            _setClipboard(_ClipboardMode.cut);
          },
        ),
        MenuAction(
          title: 'fileManagerPaste'.tr(),
          attributes: MenuActionAttributes(disabled: !canPaste),
          activator: const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
          callback: () => _pasteInto(_FileSide.local),
        ),
        MenuSeparator(),
        MenuAction(
          title: entries.length == 1
              ? 'commonDelete'.tr()
              : 'Delete ${entries.length}',
          attributes: MenuActionAttributes(destructive: true, disabled: busy),
          activator: const SingleActivator(LogicalKeyboardKey.backspace),
          callback: () {
            _ensureLocalContextSelection(entry, index);
            _deleteSelection();
          },
        ),
      ],
    );
  }

  Menu _remoteEntryMenu(SftpName entry, int index) {
    final selected = _entriesForSelection(_FileSide.remote);
    final path = _joinRemotePath(_remotePath, entry.filename);
    final entries = selected.isEmpty
        ? [_clipboardEntryForRemote(entry)]
        : selected;
    final onlyThis = entries.length == 1 && entries.first.path == path;
    final isDirectory = entry.attr.isDirectory;
    final busy = _workingPath != null;
    final canPaste = _canPasteInto(_FileSide.remote);
    final transferLabel = entries.length == 1
        ? 'Download to local'
        : 'Download ${entries.length} items';
    return Menu(
      children: [
        if (onlyThis && isDirectory)
          MenuAction(
            title: 'fileManagerOpen'.tr(),
            callback: () => _openRemote(entry),
          ),
        if (onlyThis && entry.attr.isFile)
          MenuAction(
            title: 'fileManagerEdit'.tr(),
            callback: () => _editRemote(entry),
          ),
        MenuAction(
          title: transferLabel,
          callback: () async {
            _ensureRemoteContextSelection(entry, index);
            for (final item in _entriesForSelection(_FileSide.remote)) {
              await _transferRemoteToLocal(item);
            }
          },
        ),
        MenuSeparator(),
        MenuAction(
          title: 'commonCopy'.tr(),
          activator: const SingleActivator(LogicalKeyboardKey.keyC, meta: true),
          callback: () {
            _ensureRemoteContextSelection(entry, index);
            _setClipboard(_ClipboardMode.copy);
          },
        ),
        MenuAction(
          title: 'fileManagerCut'.tr(),
          activator: const SingleActivator(LogicalKeyboardKey.keyX, meta: true),
          callback: () {
            _ensureRemoteContextSelection(entry, index);
            _setClipboard(_ClipboardMode.cut);
          },
        ),
        MenuAction(
          title: 'fileManagerPaste'.tr(),
          attributes: MenuActionAttributes(disabled: !canPaste),
          activator: const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
          callback: () => _pasteInto(_FileSide.remote),
        ),
        MenuSeparator(),
        MenuAction(
          title: entries.length == 1
              ? 'commonDelete'.tr()
              : 'Delete ${entries.length}',
          attributes: MenuActionAttributes(destructive: true, disabled: busy),
          activator: const SingleActivator(LogicalKeyboardKey.backspace),
          callback: () {
            _ensureRemoteContextSelection(entry, index);
            _deleteSelection();
          },
        ),
      ],
    );
  }

  Menu _paneBackgroundMenu(_FileSide side) {
    final canPaste = _canPasteInto(side);
    final canGoUp = side == _FileSide.local
        ? _localDirectory.parent.path != _localDirectory.path
        : _remotePath != '/';
    return Menu(
      children: [
        MenuAction(
          title: 'fileManagerPaste'.tr(),
          attributes: MenuActionAttributes(disabled: !canPaste),
          activator: const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
          callback: () => _pasteInto(side),
        ),
        MenuSeparator(),
        MenuAction(
          title: 'fileManagerGoUp'.tr(),
          attributes: MenuActionAttributes(disabled: !canGoUp),
          callback: () =>
              side == _FileSide.local ? _goUpLocal() : _goUpRemote(),
        ),
        if (side == _FileSide.local)
          MenuAction(title: 'Choose folder…', callback: _chooseLocalDirectory),
        MenuAction(
          title: 'commonRefresh'.tr(),
          callback: () =>
              side == _FileSide.local ? _refreshLocal() : _refreshRemote(),
        ),
      ],
    );
  }

  /// True when a text field (path bar, etc.) should own typing shortcuts.
  bool get _isTextInputFocused {
    if (_remotePathFocusNode.hasFocus) return true;
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || primary.context == null) return false;
    // TextField / EditableText own the primary focus while editing.
    return primary.context!.widget is EditableText ||
        primary.context!.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    // Let path bar and other text fields handle select-all, delete, paste, etc.
    if (_isTextInputFocused) return KeyEventResult.ignored;

    final isMeta =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (isMeta && event.logicalKey == LogicalKeyboardKey.keyA) {
      _selectAllOnFocusedSide();
      return KeyEventResult.handled;
    }
    if (isMeta && event.logicalKey == LogicalKeyboardKey.keyC) {
      _setClipboard(_ClipboardMode.copy);
      return KeyEventResult.handled;
    }
    if (isMeta && event.logicalKey == LogicalKeyboardKey.keyX) {
      _setClipboard(_ClipboardMode.cut);
      return KeyEventResult.handled;
    }
    if (isMeta && event.logicalKey == LogicalKeyboardKey.keyV) {
      final side = _focusedSide;
      if (side != null) _pasteInto(side);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      _deleteSelection();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pathTextStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontFamily: MaidKitFonts.mono,
      color: scheme.onSurfaceVariant,
    );
    final localPane = _FilePane(
      title: 'fileManagerLocal'.tr(),
      path: _localDirectory.path,
      pathTextStyle: pathTextStyle,
      focused: _focusedSide == _FileSide.local,
      dropHighlighted: _dropTargetSide == _FileSide.local,
      canGoUp: _localDirectory.parent.path != _localDirectory.path,
      onGoUp: _goUpLocal,
      onPathTap: _chooseLocalDirectory,
      onRefresh: _refreshLocal,
      onFocus: () => _focusSide(_FileSide.local),
      loading: _loadingLocal,
      error: _localError,
      clipboardHint: _clipboardHint(_FileSide.local),
      backgroundMenu: () => _paneBackgroundMenu(_FileSide.local),
      canAcceptDrop: (data) => data.side == _FileSide.remote,
      onDragEntered: () => setState(() => _dropTargetSide = _FileSide.local),
      onDragExited: () {
        if (_dropTargetSide == _FileSide.local) {
          setState(() => _dropTargetSide = null);
        }
      },
      onAcceptDrop: (data) => _handleInternalDrop(data, _FileSide.local),
      headerActions: [
        IconButton(
          tooltip: 'Hide local',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: () => setState(() {
            _localCollapsed = true;
            if (_focusedSide == _FileSide.local) {
              _focusedSide = _FileSide.remote;
            }
            if (_dropTargetSide == _FileSide.local) {
              _dropTargetSide = null;
            }
          }),
          icon: const Icon(Symbols.left_panel_close, size: 18),
        ),
      ],
      child: _LocalFileList(
        entries: _localEntries,
        selectedPaths: _selectedLocalPaths,
        cutPaths: _cutPathsFor(_FileSide.local),
        onTapEntry: (entry, index) {
          _selectLocal(
            entry,
            index: index,
            toggle: _isMultiModifierPressed,
            range: _isRangeModifierPressed,
          );
        },
        onOpen: _openLocal,
        onEdit: (entry) {
          if (entry is File) unawaited(_editLocal(entry));
        },
        dragDataFor: _dragDataForLocal,
        onContextPrepare: _ensureLocalContextSelection,
        menuProvider: _localEntryMenu,
      ),
    );
    final remotePane = _FilePane(
      title: 'fileManagerRemote'.tr(),
      path: _remotePath,
      pathTextStyle: pathTextStyle,
      focused: _focusedSide == _FileSide.remote,
      dropHighlighted: _dropTargetSide == _FileSide.remote,
      canGoUp: _remotePath != '/',
      onGoUp: _goUpRemote,
      pathInput: TextField(
        controller: _remotePathController,
        focusNode: _remotePathFocusNode,
        style: pathTextStyle,
        maxLines: 1,
        textInputAction: TextInputAction.go,
        onTap: () {
          _focusSide(_FileSide.remote);
          _remotePathController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _remotePathController.text.length,
          );
        },
        onSubmitted: _navigateRemote,
        decoration: const InputDecoration(
          hintText: 'Remote path',
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
      ),
      onCopyPath: _copyRemotePath,
      onOpenTerminal: _openTerminalHere,
      onRefresh: _refreshRemote,
      onFocus: () => _focusSide(_FileSide.remote),
      loading: _loadingRemote,
      error: _remoteError,
      clipboardHint: _clipboardHint(_FileSide.remote),
      backgroundMenu: () => _paneBackgroundMenu(_FileSide.remote),
      canAcceptDrop: (data) => data.side == _FileSide.local,
      onDragEntered: () => setState(() => _dropTargetSide = _FileSide.remote),
      onDragExited: () {
        if (_dropTargetSide == _FileSide.remote) {
          setState(() => _dropTargetSide = null);
        }
      },
      onAcceptDrop: (data) => _handleInternalDrop(data, _FileSide.remote),
      headerActions: [
        if (_localCollapsed)
          IconButton(
            tooltip: 'Show local',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => setState(() => _localCollapsed = false),
            icon: const Icon(Symbols.left_panel_open, size: 18),
          ),
      ],
      child: _RemoteFileList(
        entries: _remoteEntries,
        currentPath: _remotePath,
        selectedPaths: _selectedRemotePaths,
        cutPaths: _cutPathsFor(_FileSide.remote),
        onTapEntry: (entry, index) {
          _selectRemote(
            entry,
            index: index,
            toggle: _isMultiModifierPressed,
            range: _isRangeModifierPressed,
          );
        },
        onOpen: _openRemote,
        onEdit: (entry) {
          if (entry.attr.isFile) unawaited(_editRemote(entry));
        },
        dragDataFor: _dragDataForRemote,
        onContextPrepare: _ensureRemoteContextSelection,
        menuProvider: _remoteEntryMenu,
      ),
    );

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          tween: Tween<double>(end: _localCollapsed ? 0.0 : 1.0),
          builder: (context, localFactor, _) {
            final factor = localFactor.clamp(0.0, 1.0);
            final showLocal = factor > 0.001;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showLocal) ...[
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: factor,
                        child: SizedBox(
                          width: constraints.maxWidth / 2,
                          child: Opacity(opacity: factor, child: localPane),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: factor,
                      child: const VerticalDivider(width: 1),
                    ),
                  ],
                  Expanded(child: remotePane),
                ],
              );
            }
            return Column(
              children: [
                if (showLocal) ...[
                  ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: factor,
                      child: SizedBox(
                        height: constraints.maxHeight / 2,
                        child: Opacity(opacity: factor, child: localPane),
                      ),
                    ),
                  ),
                  Opacity(opacity: factor, child: const Divider(height: 1)),
                ],
                Expanded(child: remotePane),
              ],
            );
          },
        );
      },
    );

    return Focus(
      focusNode: _shortcutFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: DropTarget(
        onDragEntered: (_) => setState(() => _draggingFiles = true),
        onDragExited: (_) => setState(() => _draggingFiles = false),
        onDragDone: (details) async {
          setState(() => _draggingFiles = false);
          await _uploadDroppedFiles(details.files);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            if (_draggingFiles)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    border: Border.all(color: scheme.primary, width: 2),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Symbols.upload_file,
                          size: 32,
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Drop files to upload to $_remotePath',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Set<String> _cutPathsFor(_FileSide side) {
    final clipboard = _clipboard;
    if (clipboard == null || clipboard.mode != _ClipboardMode.cut) {
      return const {};
    }
    return clipboard.entries
        .where((entry) => entry.side == side)
        .map((entry) => entry.path)
        .toSet();
  }

  String? _clipboardHint(_FileSide side) {
    final clipboard = _clipboard;
    if (clipboard == null || clipboard.isEmpty) return null;
    final count = clipboard.entries.length;
    final verb = clipboard.mode == _ClipboardMode.cut
        ? 'fileManagerCut'.tr()
        : 'fileManagerCopied'.tr();
    final source = clipboard.entries.first.side == _FileSide.local
        ? 'local'
        : 'remote';
    return '$verb $count from $source · paste here';
  }
}

class _FilePane extends StatelessWidget {
  const _FilePane({
    required this.title,
    required this.path,
    required this.pathTextStyle,
    required this.focused,
    required this.dropHighlighted,
    required this.canGoUp,
    required this.onGoUp,
    required this.onRefresh,
    required this.onFocus,
    required this.loading,
    required this.error,
    required this.backgroundMenu,
    required this.canAcceptDrop,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onAcceptDrop,
    required this.child,
    this.onPathTap,
    this.pathInput,
    this.onCopyPath,
    this.onOpenTerminal,
    this.clipboardHint,
    this.headerActions = const [],
  });

  final String title;
  final String path;
  final TextStyle? pathTextStyle;
  final bool focused;
  final bool dropHighlighted;
  final bool canGoUp;
  final VoidCallback onGoUp;
  final VoidCallback? onPathTap;
  final VoidCallback onRefresh;
  final VoidCallback onFocus;
  final bool loading;
  final String? error;
  final Menu Function() backgroundMenu;
  final bool Function(_FileDragData data) canAcceptDrop;
  final VoidCallback onDragEntered;
  final VoidCallback onDragExited;
  final Future<void> Function(_FileDragData data) onAcceptDrop;
  final Widget child;
  final Widget? pathInput;
  final Future<void> Function()? onCopyPath;
  final Future<void> Function()? onOpenTerminal;
  final String? clipboardHint;
  final List<Widget> headerActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ContextMenuWidget(
      menuProvider: (_) => backgroundMenu(),
      child: DragTarget<_FileDragData>(
        onWillAcceptWithDetails: (details) {
          if (!canAcceptDrop(details.data)) return false;
          onDragEntered();
          return true;
        },
        onLeave: (_) => onDragExited(),
        onAcceptWithDetails: (details) => onAcceptDrop(details.data),
        builder: (context, candidate, rejected) {
          final highlighted = dropHighlighted || candidate.isNotEmpty;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onFocus,
            child: ColoredBox(
              color: highlighted
                  ? scheme.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
                    child: SizedBox(
                      height: 32,
                      child: Row(
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: focused || highlighted
                                  ? scheme.primary
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child:
                                pathInput ??
                                TextButton(
                                  onPressed: onPathTap,
                                  style: TextButton.styleFrom(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 0,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: Text(
                                    path,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: pathTextStyle,
                                  ),
                                ),
                          ),
                          if (clipboardHint != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                clipboardHint!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ...headerActions,
                          IconButton(
                            tooltip: 'fileManagerGoUp'.tr(),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: canGoUp ? onGoUp : null,
                            icon: const Icon(Symbols.arrow_upward, size: 18),
                          ),
                          if (onCopyPath != null)
                            IconButton(
                              tooltip: 'Copy remote path',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: () => onCopyPath!(),
                              icon: const Icon(Symbols.content_copy, size: 18),
                            ),
                          if (onOpenTerminal != null)
                            IconButton(
                              tooltip: 'Open terminal here',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: () => onOpenTerminal!(),
                              icon: const Icon(Symbols.terminal, size: 18),
                            ),
                          IconButton(
                            tooltip: 'commonRefresh'.tr(),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: loading ? null : onRefresh,
                            icon: const Icon(Symbols.refresh, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(error!),
                            ),
                          )
                        : child,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LocalFileList extends StatelessWidget {
  const _LocalFileList({
    required this.entries,
    required this.selectedPaths,
    required this.cutPaths,
    required this.onTapEntry,
    required this.onOpen,
    required this.onEdit,
    required this.dragDataFor,
    required this.onContextPrepare,
    required this.menuProvider,
  });

  final List<FileSystemEntity> entries;
  final Set<String> selectedPaths;
  final Set<String> cutPaths;
  final void Function(FileSystemEntity entry, int index) onTapEntry;
  final ValueChanged<FileSystemEntity> onOpen;
  final ValueChanged<FileSystemEntity> onEdit;
  final _FileDragData Function(FileSystemEntity entry) dragDataFor;
  final void Function(FileSystemEntity entry, int index) onContextPrepare;
  final Menu Function(FileSystemEntity entry, int index) menuProvider;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _EmptyPane(message: 'This folder is empty.');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isDirectory = entry is Directory;
        final name = _entityName(entry);
        final selected = selectedPaths.contains(entry.path);
        final dimmed = cutPaths.contains(entry.path);
        final dragData = dragDataFor(entry);
        return ContextMenuWidget(
          menuProvider: (_) {
            onContextPrepare(entry, index);
            return menuProvider(entry, index);
          },
          child: _DraggableFileRow(
            dragData: dragData,
            icon: isDirectory ? Symbols.folder : Symbols.description,
            name: name,
            detail: isDirectory ? 'fileManagerFolder'.tr() : null,
            selected: selected,
            dimmed: dimmed,
            onTap: () => onTapEntry(entry, index),
            onDoubleTap: isDirectory
                ? () => onOpen(entry)
                : () => onEdit(entry),
          ),
        );
      },
    );
  }
}

class _RemoteFileList extends StatelessWidget {
  const _RemoteFileList({
    required this.entries,
    required this.currentPath,
    required this.selectedPaths,
    required this.cutPaths,
    required this.onTapEntry,
    required this.onOpen,
    required this.onEdit,
    required this.dragDataFor,
    required this.onContextPrepare,
    required this.menuProvider,
  });

  final List<SftpName> entries;
  final String currentPath;
  final Set<String> selectedPaths;
  final Set<String> cutPaths;
  final void Function(SftpName entry, int index) onTapEntry;
  final ValueChanged<SftpName> onOpen;
  final ValueChanged<SftpName> onEdit;
  final _FileDragData Function(SftpName entry) dragDataFor;
  final void Function(SftpName entry, int index) onContextPrepare;
  final Menu Function(SftpName entry, int index) menuProvider;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _EmptyPane(message: 'This folder is empty.');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isDirectory = entry.attr.isDirectory;
        final path = _joinRemotePath(currentPath, entry.filename);
        final selected = selectedPaths.contains(path);
        final dimmed = cutPaths.contains(path);
        final dragData = dragDataFor(entry);
        return ContextMenuWidget(
          menuProvider: (_) {
            onContextPrepare(entry, index);
            return menuProvider(entry, index);
          },
          child: _DraggableFileRow(
            dragData: dragData,
            icon: isDirectory ? Symbols.folder : Symbols.description,
            name: entry.filename,
            detail: isDirectory
                ? 'fileManagerFolder'.tr()
                : _formatBytes(entry.attr.size),
            selected: selected,
            dimmed: dimmed,
            onTap: () => onTapEntry(entry, index),
            onDoubleTap: isDirectory
                ? () => onOpen(entry)
                : () => onEdit(entry),
          ),
        );
      },
    );
  }
}

class _DraggableFileRow extends StatelessWidget {
  const _DraggableFileRow({
    required this.dragData,
    required this.icon,
    required this.name,
    required this.selected,
    required this.dimmed,
    required this.onTap,
    this.onDoubleTap,
    this.detail,
  });

  final _FileDragData dragData;
  final IconData icon;
  final String name;
  final String? detail;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final count = dragData.entries.length;
    final feedbackLabel = count == 1 ? name : '$count items';
    return Draggable<_FileDragData>(
      data: dragData,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(feedbackLabel),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _FileRow(
          icon: icon,
          name: name,
          detail: detail,
          selected: selected,
          dimmed: true,
          onTap: onTap,
          onDoubleTap: onDoubleTap,
        ),
      ),
      child: _FileRow(
        icon: icon,
        name: name,
        detail: detail,
        selected: selected,
        dimmed: dimmed,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.icon,
    required this.name,
    required this.selected,
    required this.dimmed,
    required this.onTap,
    this.onDoubleTap,
    this.detail,
  });

  final IconData icon;
  final String name;
  final String? detail;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected
          ? scheme.secondaryContainer.withValues(alpha: 0.55)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Opacity(
          opacity: dimmed ? 0.45 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected ? scheme.onSecondaryContainer : null,
                    ),
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    detail!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? scheme.onSecondaryContainer.withValues(alpha: 0.8)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _entityName(FileSystemEntity entry) =>
    entry.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty);

String _joinRemotePath(String directory, String name) =>
    directory == '/' ? '/$name' : '$directory/$name';

String _parentRemotePath(String path) {
  if (path == '/' || path.isEmpty) return '/';
  final normalized = path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  final index = normalized.lastIndexOf('/');
  if (index <= 0) return '/';
  return normalized.substring(0, index);
}

String _formatBytes(int? bytes) {
  if (bytes == null) return 'Unknown size';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
