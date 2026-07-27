import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Owns vault database files after they have been selected by the user.
///
/// Keeping a private copy in the app's Documents directory makes vaults work
/// the same way on desktop and mobile, where picker paths are not durable.
class VaultFileStorage {
  static const _directoryName = 'vaults';
  static const _extension = '.maidkit';
  final Uuid _uuid = const Uuid();

  Future<String> createVaultPath({String? name}) async {
    final directory = await _vaultDirectory();
    final stem = _safeStem(_fileName(name ?? 'MaidKit vault'));
    return '${directory.path}/$stem-${_uuid.v4()}$_extension';
  }

  Future<String> importVault(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Vault file was not found.', sourcePath);
    }
    final directory = await _vaultDirectory();
    if (_isInDirectory(source.path, directory.path)) return source.path;

    final name = _safeStem(_fileName(source.path));
    final target = File(
      '${directory.path}/$name-${source.path.hashCode.abs()}$_extension',
    );
    if (!await target.exists()) await source.copy(target.path);
    return target.path;
  }

  Future<Directory> _vaultDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(
      '${documents.path}/$_directoryName',
    ).create(recursive: true);
  }

  bool _isInDirectory(String path, String directory) =>
      path == directory ||
      path.startsWith('$directory${Platform.pathSeparator}');

  String _fileName(String path) => path.split(Platform.pathSeparator).last;

  String _safeStem(String value) {
    final withoutExtension = value.replaceFirst(RegExp(r'\.[^.]*$'), '');
    final sanitized = withoutExtension.replaceAll(
      RegExp(r'[^a-zA-Z0-9 _-]'),
      '_',
    );
    return sanitized.trim().isEmpty ? 'Vault' : sanitized.trim();
  }
}
