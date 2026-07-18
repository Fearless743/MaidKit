import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dartssh2/dartssh2.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter/services.dart';
import 'package:highlight/highlight_core.dart' show Mode;
import 'package:highlight/languages/bash.dart' as bash;
import 'package:highlight/languages/css.dart' as css;
import 'package:highlight/languages/dart.dart' as dart;
import 'package:highlight/languages/javascript.dart' as javascript;
import 'package:highlight/languages/json.dart' as json;
import 'package:highlight/languages/python.dart' as python;
import 'package:highlight/languages/typescript.dart' as typescript;
import 'package:highlight/languages/xml.dart' as xml;
import 'package:highlight/languages/yaml.dart' as yaml;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:super_context_menu/super_context_menu.dart';

import 'package:maid_kit/shared/presentation/maidkit_alert.dart';
import 'package:maid_kit/shared/presentation/task_progress.dart';
import 'package:maid_kit/theme.dart';
import 'server_connection_actions.dart';
import 'server_providers.dart';
import 'terminal_tabs_provider.dart';

enum _FileSide { local, remote }

enum _ClipboardMode { copy, cut }

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
      title: mode == _ClipboardMode.copy ? 'Copied' : 'Cut',
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
    if (data.side == targetSide ||
        data.entries.isEmpty ||
        _workingPath != null) {
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
          title: targetSide == _FileSide.remote ? 'Uploaded' : 'Downloaded',
          icon: Symbols.check_circle,
          accentColor: Theme.of(context).colorScheme.primary,
        );
      }
    } catch (error) {
      if (mounted) {
        showStyledSnackBar(
          message: error.toString(),
          title: 'Drop failed',
          icon: Symbols.error,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<void> _pasteInto(_FileSide targetSide) async {
    final clipboard = _clipboard;
    if (clipboard == null || clipboard.isEmpty || _workingPath != null) return;

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
          message: clipboard.mode == _ClipboardMode.cut
              ? 'Items moved'
              : 'Items pasted',
          title: 'Done',
          icon: Symbols.check_circle,
          accentColor: Theme.of(context).colorScheme.primary,
        );
      }
    } catch (error) {
      if (mounted) {
        showStyledSnackBar(
          message: error.toString(),
          title: 'Paste failed',
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
      await _transferLocalToRemote(entry, notify: false);
      if (mode == _ClipboardMode.cut) {
        await _deleteEntry(entry, confirm: false, notify: false);
      }
      return;
    }
    if (entry.side == _FileSide.remote && targetSide == _FileSide.local) {
      await _transferRemoteToLocal(entry, notify: false);
      if (mode == _ClipboardMode.cut) {
        await _deleteEntry(entry, confirm: false, notify: false);
      }
    }
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
  }) async {
    if (entry.isDirectory) {
      await _uploadDirectory(Directory(entry.path), entry.name, notify: notify);
    } else {
      await _upload(File(entry.path), notify: notify);
    }
  }

  Future<void> _transferRemoteToLocal(
    _ClipboardEntry entry, {
    bool notify = true,
  }) async {
    if (entry.isDirectory) {
      await _downloadDirectory(entry.path, entry.name, notify: notify);
    } else {
      final sftpName = _remoteEntries
          .where((item) => item.filename == entry.name)
          .firstOrNull;
      if (sftpName != null) {
        await _download(sftpName, notify: notify);
      } else {
        await _downloadPath(entry.path, entry.name, null, notify: notify);
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
          title: 'Deleted',
          icon: Symbols.delete,
          accentColor: Theme.of(context).colorScheme.primary,
        );
      }
    } catch (error) {
      if (notify && mounted) {
        showStyledSnackBar(
          message: error.toString(),
          title: 'Delete failed',
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

  Future<void> _upload(FileSystemEntity entry, {bool notify = true}) async {
    if (entry is! File) return;
    final totalBytes = await entry.length();
    await _runTransfer(
      title: 'Uploading ${_entityName(entry)}',
      totalBytes: totalBytes,
      notify: notify,
      action: (reportProgress) async {
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
          await remoteFile
              .write(
                entry.openRead().map(Uint8List.fromList),
                onProgress: reportProgress,
              )
              .done;
        } finally {
          await remoteFile.close();
        }
        await _refreshRemote();
      },
    );
  }

  Future<void> _uploadDirectory(
    Directory directory,
    String name, {
    bool notify = true,
  }) async {
    await _runTransfer(
      title: 'Uploading $name',
      totalBytes: null,
      notify: notify,
      action: (_) async {
        final sftp = await _sftp();
        final remoteRoot = await _uniqueRemotePath(sftp, _remotePath, name);
        await _uploadLocalDirectory(sftp, directory, remoteRoot);
        await _refreshRemote();
      },
    );
  }

  Future<void> _uploadLocalDirectory(
    SftpClient sftp,
    Directory local,
    String remotePath,
  ) async {
    await sftp.mkdir(remotePath);
    await for (final entity in local.list(followLinks: false)) {
      final name = _entityName(entity);
      final childRemote = _joinRemotePath(remotePath, name);
      if (entity is Directory) {
        await _uploadLocalDirectory(sftp, entity, childRemote);
      } else if (entity is File) {
        final remoteFile = await sftp.open(
          childRemote,
          mode:
              SftpFileOpenMode.write |
              SftpFileOpenMode.create |
              SftpFileOpenMode.truncate,
        );
        try {
          await remoteFile
              .write(entity.openRead().map(Uint8List.fromList))
              .done;
        } finally {
          await remoteFile.close();
        }
      }
    }
  }

  Future<void> _uploadDroppedFiles(List<DropItem> items) async {
    for (final item in items.whereType<DropItemFile>()) {
      final bookmark = item.extraAppleBookmark;
      final hasSecurityScopedAccess =
          bookmark != null &&
          await DesktopDrop.instance.startAccessingSecurityScopedResource(
            bookmark: bookmark,
          );
      try {
        await _upload(File(item.path));
      } finally {
        if (hasSecurityScopedAccess) {
          await DesktopDrop.instance.stopAccessingSecurityScopedResource(
            bookmark: bookmark,
          );
        }
      }
    }
  }

  Future<void> _download(SftpName entry, {bool notify = true}) async {
    if (!entry.attr.isFile) return;
    await _downloadPath(
      _joinRemotePath(_remotePath, entry.filename),
      entry.filename,
      entry.attr.size,
      notify: notify,
    );
  }

  Future<void> _downloadPath(
    String remotePath,
    String filename,
    int? totalBytes, {
    bool notify = true,
  }) async {
    await _runTransfer(
      title: 'Downloading $filename',
      totalBytes: totalBytes,
      notify: notify,
      action: (reportProgress) async {
        final sftp = await _sftp();
        final destinationPath = await _uniqueLocalPath(
          _localDirectory.path,
          filename,
        );
        final destination = File(destinationPath);
        await sftp.download(
          remotePath,
          destination.openWrite(),
          onProgress: reportProgress,
          closeDestination: true,
        );
        await _refreshLocal();
      },
    );
  }

  Future<void> _downloadDirectory(
    String remotePath,
    String name, {
    bool notify = true,
  }) async {
    await _runTransfer(
      title: 'Downloading $name',
      totalBytes: null,
      notify: notify,
      action: (_) async {
        final sftp = await _sftp();
        final localRoot = await _uniqueLocalPath(_localDirectory.path, name);
        await _downloadRemoteDirectory(sftp, remotePath, Directory(localRoot));
        await _refreshLocal();
      },
    );
  }

  Future<void> _downloadRemoteDirectory(
    SftpClient sftp,
    String remotePath,
    Directory local,
  ) async {
    await local.create(recursive: true);
    final entries = await sftp.listdir(remotePath);
    for (final entry in entries) {
      if (entry.filename == '.' || entry.filename == '..') continue;
      final childRemote = _joinRemotePath(remotePath, entry.filename);
      final childLocal = local.uri.resolve(entry.filename).toFilePath();
      if (entry.attr.isDirectory) {
        await _downloadRemoteDirectory(
          sftp,
          childRemote,
          Directory(childLocal),
        );
      } else if (entry.attr.isFile) {
        await sftp.download(
          childRemote,
          File(childLocal).openWrite(),
          closeDestination: true,
        );
      }
    }
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
    required Future<void> Function(void Function(int)) action,
    bool notify = true,
  }) async {
    final taskId = ref
        .read(taskProgressProvider.notifier)
        .start(title: title, totalBytes: totalBytes);
    setState(() => _workingPath = title);
    try {
      await action(
        (transferredBytes) => ref
            .read(taskProgressProvider.notifier)
            .update(taskId, transferredBytes),
      );
      ref.read(taskProgressProvider.notifier).complete(taskId);
      if (notify && mounted) {
        showStyledSnackBar(
          message: title,
          title: 'Transfer complete',
          icon: Symbols.check_circle,
          accentColor: Theme.of(context).colorScheme.primary,
        );
      }
    } catch (error) {
      ref.read(taskProgressProvider.notifier).fail(taskId);
      if (notify && mounted) {
        showStyledSnackBar(
          message: error.toString(),
          title: 'Transfer failed',
          icon: Symbols.error,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
      // Re-throw for compound ops (paste) that silence notifications and
      // handle failures themselves. Direct upload/download already notified.
      if (!notify) rethrow;
    } finally {
      if (mounted) setState(() => _workingPath = null);
    }
  }

  Future<SftpClient> _sftp() => _sftpClient ??= ref
      .read(connectionManagerProvider)
      .withClient(widget.tab.serverId, (client) => client.sftp());

  Future<void> _editLocal(File file) => _showFileEditor(
    name: _entityName(file),
    location: file.path,
    load: () async {
      final bytes = await file.readAsBytes();
      _validateEditableText(bytes.length, file.path);
      return utf8.decode(bytes);
    },
    save: (text) async {
      await file.writeAsBytes(utf8.encode(text), flush: true);
      await _refreshLocal();
    },
  );

  Future<void> _editRemote(SftpName entry) {
    final path = _joinRemotePath(_remotePath, entry.filename);
    return _showFileEditor(
      name: entry.filename,
      location: path,
      load: () async {
        _validateEditableText(entry.attr.size, path);
        final sftp = await _sftp();
        final file = await sftp.open(path, mode: SftpFileOpenMode.read);
        try {
          final bytes = await file.readBytes();
          _validateEditableText(bytes.length, path);
          return utf8.decode(bytes);
        } finally {
          await file.close();
        }
      },
      save: (text) async {
        final sftp = await _sftp();
        final file = await sftp.open(
          path,
          mode:
              SftpFileOpenMode.write |
              SftpFileOpenMode.create |
              SftpFileOpenMode.truncate,
        );
        try {
          await file.writeBytes(Uint8List.fromList(utf8.encode(text)));
        } finally {
          await file.close();
        }
        await _refreshRemote();
      },
    );
  }

  Future<void> _showFileEditor({
    required String name,
    required String location,
    required Future<String> Function() load,
    required Future<void> Function(String text) save,
  }) => showAttentionModal(
    id: 'file-editor-${widget.tab.id}-$location',
    replaceIfExists: true,
    barrierDismissible: false,
    builder: (context, dismiss) => _FileEditorModal(
      name: name,
      location: location,
      load: load,
      save: save,
      dismiss: dismiss,
    ),
  );

  void _validateEditableText(int? size, String path) {
    const maximumEditableBytes = 1024 * 1024;
    if (size != null && size > maximumEditableBytes) {
      throw FileSystemException(
        'Files larger than 1 MB cannot be edited directly.',
        path,
      );
    }
  }

  Menu _localEntryMenu(FileSystemEntity entry, int index) {
    final selected = _entriesForSelection(_FileSide.local);
    final entries = selected.isEmpty
        ? [_clipboardEntryForLocal(entry)]
        : selected;
    final onlyThis = entries.length == 1 && entries.first.path == entry.path;
    final isDirectory = entry is Directory;
    final busy = _workingPath != null;
    final canPaste = _clipboard?.isNotEmpty == true && !busy;
    final transferLabel = entries.length == 1
        ? 'Upload to remote'
        : 'Upload ${entries.length} items';
    return Menu(
      children: [
        if (onlyThis && isDirectory)
          MenuAction(title: 'Open', callback: () => _openLocal(entry)),
        if (onlyThis && entry is File)
          MenuAction(title: 'Edit', callback: () => _editLocal(entry)),
        MenuAction(
          title: transferLabel,
          attributes: MenuActionAttributes(disabled: busy),
          callback: () async {
            _ensureLocalContextSelection(entry, index);
            for (final item in _entriesForSelection(_FileSide.local)) {
              await _transferLocalToRemote(item);
            }
          },
        ),
        MenuSeparator(),
        MenuAction(
          title: 'Copy',
          activator: const SingleActivator(LogicalKeyboardKey.keyC, meta: true),
          callback: () {
            _ensureLocalContextSelection(entry, index);
            _setClipboard(_ClipboardMode.copy);
          },
        ),
        MenuAction(
          title: 'Cut',
          activator: const SingleActivator(LogicalKeyboardKey.keyX, meta: true),
          callback: () {
            _ensureLocalContextSelection(entry, index);
            _setClipboard(_ClipboardMode.cut);
          },
        ),
        MenuAction(
          title: 'Paste',
          attributes: MenuActionAttributes(disabled: !canPaste),
          activator: const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
          callback: () => _pasteInto(_FileSide.local),
        ),
        MenuSeparator(),
        MenuAction(
          title: entries.length == 1 ? 'Delete' : 'Delete ${entries.length}',
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
    final canPaste = _clipboard?.isNotEmpty == true && !busy;
    final transferLabel = entries.length == 1
        ? 'Download to local'
        : 'Download ${entries.length} items';
    return Menu(
      children: [
        if (onlyThis && isDirectory)
          MenuAction(title: 'Open', callback: () => _openRemote(entry)),
        if (onlyThis && entry.attr.isFile)
          MenuAction(title: 'Edit', callback: () => _editRemote(entry)),
        MenuAction(
          title: transferLabel,
          attributes: MenuActionAttributes(disabled: busy),
          callback: () async {
            _ensureRemoteContextSelection(entry, index);
            for (final item in _entriesForSelection(_FileSide.remote)) {
              await _transferRemoteToLocal(item);
            }
          },
        ),
        MenuSeparator(),
        MenuAction(
          title: 'Copy',
          activator: const SingleActivator(LogicalKeyboardKey.keyC, meta: true),
          callback: () {
            _ensureRemoteContextSelection(entry, index);
            _setClipboard(_ClipboardMode.copy);
          },
        ),
        MenuAction(
          title: 'Cut',
          activator: const SingleActivator(LogicalKeyboardKey.keyX, meta: true),
          callback: () {
            _ensureRemoteContextSelection(entry, index);
            _setClipboard(_ClipboardMode.cut);
          },
        ),
        MenuAction(
          title: 'Paste',
          attributes: MenuActionAttributes(disabled: !canPaste),
          activator: const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
          callback: () => _pasteInto(_FileSide.remote),
        ),
        MenuSeparator(),
        MenuAction(
          title: entries.length == 1 ? 'Delete' : 'Delete ${entries.length}',
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
    final busy = _workingPath != null;
    final canPaste = _clipboard?.isNotEmpty == true && !busy;
    final canGoUp = side == _FileSide.local
        ? _localDirectory.parent.path != _localDirectory.path
        : _remotePath != '/';
    return Menu(
      children: [
        MenuAction(
          title: 'Paste',
          attributes: MenuActionAttributes(disabled: !canPaste),
          activator: const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
          callback: () => _pasteInto(side),
        ),
        MenuSeparator(),
        MenuAction(
          title: 'Go up',
          attributes: MenuActionAttributes(disabled: !canGoUp),
          callback: () =>
              side == _FileSide.local ? _goUpLocal() : _goUpRemote(),
        ),
        if (side == _FileSide.local)
          MenuAction(title: 'Choose folder…', callback: _chooseLocalDirectory),
        MenuAction(
          title: 'Refresh',
          callback: () =>
              side == _FileSide.local ? _refreshLocal() : _refreshRemote(),
        ),
      ],
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
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
      title: 'Local',
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
        dragDataFor: _dragDataForLocal,
        onContextPrepare: _ensureLocalContextSelection,
        menuProvider: _localEntryMenu,
      ),
    );
    final remotePane = _FilePane(
      title: 'Remote',
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
    final verb = clipboard.mode == _ClipboardMode.cut ? 'Cut' : 'Copied';
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
                            tooltip: 'Go up',
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
                            tooltip: 'Refresh',
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
    required this.dragDataFor,
    required this.onContextPrepare,
    required this.menuProvider,
  });

  final List<FileSystemEntity> entries;
  final Set<String> selectedPaths;
  final Set<String> cutPaths;
  final void Function(FileSystemEntity entry, int index) onTapEntry;
  final ValueChanged<FileSystemEntity> onOpen;
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
            detail: isDirectory ? 'Folder' : null,
            selected: selected,
            dimmed: dimmed,
            onTap: () => onTapEntry(entry, index),
            onDoubleTap: isDirectory ? () => onOpen(entry) : null,
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
            detail: isDirectory ? 'Folder' : _formatBytes(entry.attr.size),
            selected: selected,
            dimmed: dimmed,
            onTap: () => onTapEntry(entry, index),
            onDoubleTap: isDirectory ? () => onOpen(entry) : null,
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

class _FileEditorModal extends StatefulWidget {
  const _FileEditorModal({
    required this.name,
    required this.location,
    required this.load,
    required this.save,
    required this.dismiss,
  });

  final String name;
  final String location;
  final Future<String> Function() load;
  final Future<void> Function(String text) save;
  final VoidCallback dismiss;

  @override
  State<_FileEditorModal> createState() => _FileEditorModalState();
}

class _FileEditorModalState extends State<_FileEditorModal> {
  late final CodeController _controller;
  var _loading = true;
  var _saving = false;
  String? _error;
  String _savedText = '';

  bool get _isDirty => !_loading && _controller.text != _savedText;

  @override
  void initState() {
    super.initState();
    _controller = CodeController(language: _languageForFileName(widget.name));
    unawaited(_load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final text = await widget.load();
      if (!mounted) return;
      setState(() {
        _controller.text = text;
        _savedText = text;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_loading || _saving || !_isDirty) return;
    setState(() => _saving = true);
    try {
      await widget.save(_controller.text);
      if (!mounted) return;
      setState(() {
        _savedText = _controller.text;
        _saving = false;
      });
      showStyledSnackBar(
        message: widget.name,
        title: 'Saved',
        icon: Symbols.check_circle,
        accentColor: Theme.of(context).colorScheme.primary,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _saving = false;
      });
    }
  }

  Future<void> _requestDismiss() async {
    if (_saving) return;
    if (_isDirty) {
      final discard = await showMaidKitConfirmAlert(
        'Changes to ${widget.name} have not been saved.',
        'Discard changes?',
        isDanger: true,
      );
      if (!discard || !mounted) return;
    }
    widget.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AttentionModalScaffold(
      titleText: 'Edit ${widget.name}',
      onDismiss: () => unawaited(_requestDismiss()),
      maxWidth: 1080,
      maxHeightFactor: 0.9,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFamily: MaidKitFonts.mono,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildEditor(context)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _saving
                        ? 'Saving…'
                        : _isDirty
                        ? 'Unsaved changes'
                        : 'Saved',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _error == null
                          ? scheme.onSurfaceVariant
                          : scheme.error,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => unawaited(_requestDismiss()),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _loading || _saving || !_isDirty
                      ? null
                      : () => unawaited(_save()),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Symbols.save, size: 18),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.error),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CodeTheme(
          data: CodeThemeData(
            styles: {
              'root': TextStyle(
                color: scheme.onSurface,
                backgroundColor: scheme.surfaceContainerLowest,
                fontFamily: MaidKitFonts.mono,
              ),
              'comment': TextStyle(color: scheme.onSurfaceVariant),
              'keyword': TextStyle(color: scheme.primary),
              'string': TextStyle(color: scheme.tertiary),
              'number': TextStyle(color: scheme.secondary),
            },
          ),
          child: CodeField(
            controller: _controller,
            expands: true,
            wrap: false,
            padding: const EdgeInsets.all(12),
            textStyle: const TextStyle(fontFamily: MaidKitFonts.mono),
            gutterStyle: GutterStyle(
              textStyle: TextStyle(color: scheme.onSurfaceVariant),
              showErrors: false,
              showFoldingHandles: false,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ),
    );
  }
}

Mode? _languageForFileName(String name) {
  final dot = name.lastIndexOf('.');
  final extension = dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  return switch (extension) {
    'dart' => dart.dart,
    'html' || 'htm' || 'xml' || 'svg' => xml.xml,
    'css' || 'scss' => css.css,
    'js' || 'mjs' || 'cjs' => javascript.javascript,
    'ts' => typescript.typescript,
    'json' => json.json,
    'py' => python.python,
    'yaml' || 'yml' => yaml.yaml,
    'sh' || 'bash' || 'zsh' || 'fish' || 'env' => bash.bash,
    _ => null,
  };
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
