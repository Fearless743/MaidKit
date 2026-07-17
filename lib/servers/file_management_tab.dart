import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../shared/presentation/task_progress.dart';
import 'server_providers.dart';
import 'terminal_tabs_provider.dart';

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
  Future<SftpClient>? _sftpClient;
  late final TextEditingController _remotePathController;
  late final FocusNode _remotePathFocusNode;

  @override
  void initState() {
    super.initState();
    _localDirectory = Directory.current;
    _remotePathController = TextEditingController(text: _remotePath);
    _remotePathFocusNode = FocusNode();
    _refreshLocal();
    _refreshRemote();
  }

  @override
  void dispose() {
    _remotePathController.dispose();
    _remotePathFocusNode.dispose();
    super.dispose();
  }

  Future<void> _refreshLocal() async {
    setState(() {
      _loadingLocal = true;
      _localError = null;
    });
    try {
      final entries = await _localDirectory.list().toList();
      entries.sort((a, b) => _entityName(a).compareTo(_entityName(b)));
      if (mounted) setState(() => _localEntries = entries);
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
        setState(() {
          _remotePath = absolutePath;
          _remoteEntries = entries;
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
    setState(() => _localDirectory = Directory(path));
    await _refreshLocal();
  }

  Future<void> _openLocal(FileSystemEntity entry) async {
    if (entry is! Directory) return;
    setState(() => _localDirectory = entry);
    await _refreshLocal();
  }

  Future<void> _openRemote(SftpName entry) async {
    if (!entry.attr.isDirectory) return;
    setState(() => _remotePath = _joinRemotePath(_remotePath, entry.filename));
    await _refreshRemote();
  }

  Future<void> _navigateRemote(String path) async {
    final destination = path.trim();
    if (destination.isEmpty) return;
    setState(() => _remotePath = destination);
    _remotePathFocusNode.unfocus();
    await _refreshRemote();
  }

  Future<void> _copyRemotePath() =>
      Clipboard.setData(ClipboardData(text: _remotePath));

  Future<void> _upload(FileSystemEntity entry) async {
    if (entry is! File) return;
    final totalBytes = await entry.length();
    await _runTransfer(
      title: 'Uploading ${_entityName(entry)}',
      totalBytes: totalBytes,
      action: (reportProgress) async {
        final sftp = await _sftp();
        final remotePath = _joinRemotePath(_remotePath, _entityName(entry));
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

  Future<void> _download(SftpName entry) async {
    if (!entry.attr.isFile) return;
    await _runTransfer(
      title: 'Downloading ${entry.filename}',
      totalBytes: entry.attr.size,
      action: (reportProgress) async {
        final sftp = await _sftp();
        final destination = File(
          _localDirectory.uri.resolve(entry.filename).toFilePath(),
        );
        await sftp.download(
          _joinRemotePath(_remotePath, entry.filename),
          destination.openWrite(),
          onProgress: reportProgress,
          closeDestination: true,
        );
        await _refreshLocal();
      },
    );
  }

  Future<void> _runTransfer({
    required String title,
    required int? totalBytes,
    required Future<void> Function(void Function(int)) action,
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
      if (mounted) {
        showStyledSnackBar(
          message: title,
          title: 'Transfer complete',
          icon: Symbols.check_circle,
          accentColor: Theme.of(context).colorScheme.primary,
        );
      }
    } catch (error) {
      ref.read(taskProgressProvider.notifier).fail(taskId);
      if (mounted) {
        showStyledSnackBar(
          message: error.toString(),
          title: 'Transfer failed',
          icon: Symbols.error,
          accentColor: Theme.of(context).colorScheme.error,
        );
      }
    } finally {
      if (mounted) setState(() => _workingPath = null);
    }
  }

  Future<SftpClient> _sftp() => _sftpClient ??= ref
      .read(connectionManagerProvider)
      .withClient(widget.tab.serverId, (client) => client.sftp());

  @override
  Widget build(BuildContext context) {
    final pathTextStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final panes = [
      _FilePane(
        title: 'Local',
        path: _localDirectory.path,
        pathTextStyle: pathTextStyle,
        onPathTap: _chooseLocalDirectory,
        onRefresh: _refreshLocal,
        loading: _loadingLocal,
        error: _localError,
        child: _LocalFileList(
          entries: _localEntries,
          workingPath: _workingPath,
          onOpen: _openLocal,
          onUpload: _upload,
        ),
      ),
      _FilePane(
        title: 'Remote · ${widget.tab.serverName}',
        path: _remotePath,
        pathTextStyle: pathTextStyle,
        pathInput: TextField(
          controller: _remotePathController,
          focusNode: _remotePathFocusNode,
          style: pathTextStyle,
          maxLines: 1,
          textInputAction: TextInputAction.go,
          onTap: () => _remotePathController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _remotePathController.text.length,
          ),
          onSubmitted: _navigateRemote,
          decoration: const InputDecoration(
            hintText: 'Remote path',
            isDense: true,
            border: InputBorder.none,
          ),
        ),
        onCopyPath: _copyRemotePath,
        onRefresh: _refreshRemote,
        loading: _loadingRemote,
        error: _remoteError,
        child: _RemoteFileList(
          entries: _remoteEntries,
          workingPath: _workingPath,
          onOpen: _openRemote,
          onDownload: _download,
        ),
      ),
    ];
    final content = LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 900
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: panes[0]),
                const VerticalDivider(width: 1),
                Expanded(child: panes[1]),
              ],
            )
          : Column(
              children: [
                Expanded(child: panes[0]),
                const SizedBox(height: 12),
                Expanded(child: panes[1]),
              ],
            ),
    );
    return DropTarget(
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
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Symbols.upload_file,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
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
    );
  }
}

class _FilePane extends StatelessWidget {
  const _FilePane({
    required this.title,
    required this.path,
    required this.pathTextStyle,
    required this.onRefresh,
    required this.loading,
    required this.error,
    required this.child,
    this.onPathTap,
    this.pathInput,
    this.onCopyPath,
  });

  final String title;
  final String path;
  final TextStyle? pathTextStyle;
  final VoidCallback? onPathTap;
  final VoidCallback onRefresh;
  final bool loading;
  final String? error;
  final Widget child;
  final Widget? pathInput;
  final Future<void> Function()? onCopyPath;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 8),
            Expanded(
              child:
                  pathInput ??
                  TextButton(
                    onPressed: onPathTap,
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                    ),
                    child: Text(
                      path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: pathTextStyle,
                    ),
                  ),
            ),
            if (onCopyPath != null)
              IconButton(
                tooltip: 'Copy remote path',
                onPressed: () => onCopyPath!(),
                icon: const Icon(Symbols.content_copy),
              ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Symbols.refresh),
            ),
          ],
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
  );
}

class _LocalFileList extends StatelessWidget {
  const _LocalFileList({
    required this.entries,
    required this.workingPath,
    required this.onOpen,
    required this.onUpload,
  });
  final List<FileSystemEntity> entries;
  final String? workingPath;
  final ValueChanged<FileSystemEntity> onOpen;
  final ValueChanged<FileSystemEntity> onUpload;

  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: entries.length,
    itemBuilder: (context, index) {
      final entry = entries[index];
      final isDirectory = entry is Directory;
      final name = _entityName(entry);
      return ListTile(
        dense: true,
        leading: Icon(isDirectory ? Symbols.folder : Symbols.description),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: isDirectory ? () => onOpen(entry) : null,
        trailing: isDirectory
            ? null
            : IconButton(
                tooltip: 'Upload to remote folder',
                onPressed: workingPath == null ? () => onUpload(entry) : null,
                icon: const Icon(Symbols.upload),
              ),
      );
    },
  );
}

class _RemoteFileList extends StatelessWidget {
  const _RemoteFileList({
    required this.entries,
    required this.workingPath,
    required this.onOpen,
    required this.onDownload,
  });
  final List<SftpName> entries;
  final String? workingPath;
  final ValueChanged<SftpName> onOpen;
  final ValueChanged<SftpName> onDownload;

  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: entries.length,
    itemBuilder: (context, index) {
      final entry = entries[index];
      final isDirectory = entry.attr.isDirectory;
      return ListTile(
        dense: true,
        leading: Icon(isDirectory ? Symbols.folder : Symbols.description),
        title: Text(
          entry.filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: isDirectory ? null : Text(_formatBytes(entry.attr.size)),
        onTap: isDirectory ? () => onOpen(entry) : null,
        trailing: isDirectory
            ? null
            : IconButton(
                tooltip: 'Download to local folder',
                onPressed: workingPath == null ? () => onDownload(entry) : null,
                icon: const Icon(Symbols.download),
              ),
      );
    },
  );
}

String _entityName(FileSystemEntity entry) =>
    entry.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty);

String _joinRemotePath(String directory, String name) =>
    directory == '/' ? '/$name' : '$directory/$name';

String _formatBytes(int? bytes) {
  if (bytes == null) return 'Unknown size';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
