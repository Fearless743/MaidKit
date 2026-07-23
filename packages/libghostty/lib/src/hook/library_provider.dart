import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';

import 'asset_hashes.dart';
import 'ghostty_source.dart';
import 'zig_target.dart';

/// Returns the dynamic library file extension for [os].
String libraryExtension(OS os) => switch (os) {
  OS.macOS || OS.iOS => 'dylib',
  OS.windows => 'dll',
  _ => 'so',
};

/// Environment variable for local Ghostty source path.
const ghosttySrcEnvKey = 'GHOSTTY_SRC';

const _requiredZigVersion = '0.15.2';

/// Download method for Ghostty source.
enum SourceLocation {
  /// Download tarball from GitHub, extract, apply patches.
  tarball,

  /// Git clone the repository.
  git,
}

sealed class LibraryProvider {
  const LibraryProvider();

  /// Acquires the native library and writes it to [target] file.
  Future<void> provide(File target);

  /// Selects the provider based on use-define hook option.
  ///
  /// Source values:
  /// - `"prebuilt"` (default): Downloads a pre-built binary from GitHub
  ///     Releases.
  /// - `"compile"`: compiles the library from source using Zig. The source
  ///     can be specified via the `GHOSTTY_SRC` environment variable, or it
  ///     will be downloaded based on `downloadMethod`.
  static LibraryProvider resolve(BuildInput input) {
    final source = input.userDefines['source'];

    // Prebuilt iOS binaries are linked by Zig and are rejected by App Store
    // Connect because they lack LC_ENCRYPTION_INFO. Always compile this target
    // locally so _compile can use Apple's linker with -encryptable.
    if (source == 'compile' || input.config.code.targetOS == .iOS) {
      final sourcePath = Platform.environment[ghosttySrcEnvKey];

      return CompileFromSource(
        input,
        sourcePath: sourcePath,
        downloadMethod: switch (input.userDefines['download']) {
          'git' => SourceLocation.git,
          'tarball' || null => SourceLocation.tarball,
          _ => throw ArgumentError(
            'Invalid download method: ${input.userDefines['download']}. '
            'Valid options are "git" or "tarball".',
          ),
        },
      );
    }

    return DownloadPrebuilt(input);
  }

  /// Checks if Zig is installed and available on PATH.
  static bool zigAvailable() {
    try {
      final result = Process.runSync(_zigExecutable(), ['version']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}

final class CompileFromSource extends LibraryProvider {
  final BuildInput input;
  final String? sourcePath;
  final SourceLocation downloadMethod;

  const CompileFromSource(
    this.input, {
    this.sourcePath,
    this.downloadMethod = SourceLocation.tarball,
  });

  @override
  Future<void> provide(File target) async {
    final sourceDir = await _resolveSource();
    await _compile(sourceDir, target);
  }

  Future<void> _compile(Directory sourceDir, File target) async {
    final os = input.config.code.targetOS;
    final arch = input.config.code.targetArchitecture;
    final ios = os == OS.iOS ? input.config.code.iOS.targetSdk : null;

    final installDir = target.parent.parent.uri;
    final zig = zigTarget(os, arch, iOSSdk: ios);
    final zigExecutable = _requireCompatibleZig();

    final zigArgs = [
      'build',
      '-Demit-lib-vt=true',
      '-p',
      Directory.fromUri(installDir).path,
      '--release=fast',
      if (os == .windows) ...['--global-cache-dir', _zigCacheDir(sourceDir)],
      if (os != .current || arch != .current) '-Dtarget=$zig',
      if (ios == .iPhoneSimulator && arch == .arm64) '-Dcpu=apple_a17',
    ];

    final result = Process.runSync(
      zigExecutable,
      zigArgs,
      workingDirectory: sourceDir.path,
    );

    if (result.exitCode != 0) {
      throw Exception(
        'Zig compilation failed (exit code ${result.exitCode}):\n'
        'stdout: ${result.stdout}\n'
        'stderr: ${result.stderr}',
      );
    }

    if (os == OS.iOS) {
      final staticLibrary = File(
        '${installDir.toFilePath()}/lib/libghostty-vt.a',
      );
      _linkIosStaticLibrary(staticLibrary, target, arch, ios!);
      return;
    }

    final srcDir = os == .windows ? 'bin' : 'lib';
    final srcFileName = os.dylibFileName('ghostty-vt');
    final srcFile = File('${installDir.toFilePath()}/$srcDir/$srcFileName');
    if (srcFile.existsSync()) srcFile.renameSync(target.path);
  }

  String _requireCompatibleZig() {
    final executable = _zigExecutable();
    ProcessResult result;
    try {
      result = Process.runSync(executable, ['version']);
    } on ProcessException {
      throw StateError(
        'Zig was not found. Install Zig $_requiredZigVersion and put its '
        'bin directory first in PATH when building.',
      );
    }

    final version = result.stdout.toString().trim();
    if (result.exitCode != 0 || version != _requiredZigVersion) {
      throw StateError(
        'Ghostty requires Zig $_requiredZigVersion, but '
        '$executable reports ${version.isEmpty ? 'an unknown version' : version}. '
        'Install `brew install zig@0.15` and set '
        'PATH=/opt/homebrew/opt/zig@0.15/bin:\$PATH when building.',
      );
    }
    return executable;
  }

  /// Links Ghostty's static archive with Xcode's clang and Apple ld.
  ///
  /// Zig can build the archive but does not emit LC_ENCRYPTION_INFO_64 for its
  /// iOS dynamic libraries. Apple ld adds that command with `-encryptable`.
  void _linkIosStaticLibrary(
    File staticLibrary,
    File target,
    Architecture arch,
    IOSSdk iosSdk,
  ) {
    if (!staticLibrary.existsSync()) {
      throw StateError(
        'Ghostty static library was not produced: ${staticLibrary.path}',
      );
    }

    final sdkName = iosSdk == IOSSdk.iPhoneSimulator
        ? 'iphonesimulator'
        : 'iphoneos';
    final sdkResult = Process.runSync('/usr/bin/xcrun', [
      '--sdk',
      sdkName,
      '--show-sdk-path',
    ]);
    if (sdkResult.exitCode != 0) {
      throw StateError(
        'Unable to locate the $sdkName SDK: ${sdkResult.stderr}',
      );
    }

    final archName = switch (arch) {
      Architecture.arm64 => 'arm64',
      Architecture.x64 => 'x86_64',
      _ => throw ArgumentError('Unsupported iOS architecture: $arch'),
    };
    final targetVersion = input.config.code.iOS.targetVersion;
    final targetTriple = iosSdk == IOSSdk.iPhoneSimulator
        ? '$archName-apple-ios$targetVersion-simulator'
        : '$archName-apple-ios$targetVersion';

    target.parent.createSync(recursive: true);
    final linkResult = Process.runSync('/usr/bin/xcrun', [
      'clang',
      '-dynamiclib',
      '-target',
      targetTriple,
      '-isysroot',
      sdkResult.stdout.toString().trim(),
      if (iosSdk == IOSSdk.iPhoneSimulator)
        '-mios-simulator-version-min=$targetVersion'
      else
        '-mios-version-min=$targetVersion',
      '-Wl,-all_load',
      staticLibrary.path,
      '-Wl,-install_name,@rpath/ghostty.framework/ghostty',
      '-Wl,-headerpad_max_install_names',
      '-Wl,-encryptable',
      '-lc++',
      '-o',
      target.path,
    ]);
    if (linkResult.exitCode != 0) {
      throw StateError(
        'Apple linker failed (exit code ${linkResult.exitCode}):\n'
        'stdout: ${linkResult.stdout}\n'
        'stderr: ${linkResult.stderr}',
      );
    }
  }

  String _zigCacheDir(Directory sourceDir) {
    final envDir = Platform.environment['ZIG_GLOBAL_CACHE_DIR'];
    if (envDir != null && envDir.isNotEmpty) return envDir;
    return '${sourceDir.path}${Platform.pathSeparator}.zig-cache';
  }

  Future<Directory> _downloadTarball() async {
    final sourceDir = await downloadSource(
      input.outputDirectoryShared,
      packageRoot: input.packageRoot,
    );

    final gitDir = Directory.fromUri(sourceDir.uri.resolve('.git'));
    if (!gitDir.existsSync()) gitDir.createSync(recursive: true);

    return sourceDir;
  }

  Future<Directory> _gitClone() async {
    final commit = pinnedCommit(input.packageRoot);
    final cacheDir = Directory.fromUri(
      input.outputDirectoryShared.resolve('ghostty-git-$commit/'),
    );

    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);

      final result = Process.runSync('git', [
        'clone',
        '--depth',
        '1',
        '--branch',
        commit,
        'https://github.com/ghostty-org/ghostty.git',
        '.',
      ], workingDirectory: cacheDir.path);

      if (result.exitCode != 0) {
        cacheDir.deleteSync(recursive: true);
        throw Exception('Git clone failed: ${result.stderr}');
      }
    }

    return cacheDir;
  }

  Future<Directory> _resolveSource() async {
    if (sourcePath != null && sourcePath!.isNotEmpty) {
      final dir = Directory(sourcePath!);
      if (dir.existsSync()) return dir;
    }

    // See if there is a `ghostty/` directory in the workspace root as
    // a fallback for local development without needing to set env vars.
    final workspaceRoot = input.packageRoot.resolve('../../');
    final localGhostty = Directory.fromUri(workspaceRoot.resolve('ghostty/'));
    if (localGhostty.existsSync()) return localGhostty;

    return switch (downloadMethod) {
      .tarball => _downloadTarball(),
      .git => _gitClone(),
    };
  }
}

String _zigExecutable() {
  // Flutter's native-hook runner prepends Xcode's tools to PATH and filters
  // arbitrary environment variables. Prefer Homebrew's pinned Zig formula so
  // an otherwise linked Zig 0.16+ installation cannot break Ghostty builds.
  if (Platform.isMacOS) {
    for (final candidate in const [
      '/opt/homebrew/opt/zig@0.15/bin/zig',
      '/usr/local/opt/zig@0.15/bin/zig',
    ]) {
      if (File(candidate).existsSync()) return candidate;
    }
  }
  return 'zig';
}

final class DownloadPrebuilt extends LibraryProvider {
  static const _repoUrl = 'https://github.com/elias8/libghostty';
  static const _defaultBaseUrl = '$_repoUrl/releases/download';

  final String baseUrl;
  final BuildInput input;
  final Map<String, String> hashes;

  const DownloadPrebuilt(
    this.input, {
    this.baseUrl = _defaultBaseUrl,
    Map<String, String>? hashes,
  }) : hashes = hashes ?? assetHashes;

  @override
  Future<void> provide(File target) async {
    final os = input.config.code.targetOS;
    final targetTriple = input.targetTriple();
    if (targetTriple == null) {
      throw Exception(
        'Cannot determine Zig target for $os. '
        'Prebuilt binaries may not be available for this platform.',
      );
    }

    final cb = input.outputDirectoryShared;
    final extension = libraryExtension(os);

    final fileName = 'libghostty-$targetTriple.$extension';
    final cacheDir = Directory.fromUri(cb.resolve('prebuilt-$releaseTag/'));
    final cachedFile = File('${cacheDir.path}/$fileName');

    if (cachedFile.existsSync() && !_validateHash(cachedFile, fileName)) {
      cachedFile.deleteSync();
    }

    if (!cachedFile.existsSync()) {
      await _download(fileName, cachedFile);
      if (!_validateHash(cachedFile, fileName)) {
        cachedFile.deleteSync();
        throw Exception(
          'SHA256 hash mismatch for downloaded $fileName. '
          'The file may be corrupted. Try again, or file an issue at '
          'https://github.com/elias8/libghostty/issues',
        );
      }
    }

    target.parent.createSync(recursive: true);
    cachedFile.copySync(target.path);
  }

  Future<void> _download(String fileName, File destination) async {
    // https://github.com/elias8/libghostty/releases/download/{releaseTag}/{filename}
    final url = '$baseUrl/$releaseTag/$fileName';

    destination.parent.createSync(recursive: true);
    final tmp = File('${destination.path}.tmp');

    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download pre-built library from $url '
          '(HTTP ${response.statusCode}).\n'
          'Options:\n'
          '  - Install Zig and rebuild from source\n'
          '  - Check https://github.com/elias8/libghostty/releases',
        );
      }
      final sink = tmp.openWrite();
      await response.pipe(sink);
    } on Exception {
      rethrow;
    } on Object {
      throw Exception(
        'Failed to download pre-built library from $url. Please check your '
        'internet connection and try again.',
      );
    } finally {
      httpClient.close();
    }

    tmp.renameSync(destination.path);
  }

  bool _validateHash(File file, String hashKey) {
    final expectedHash = hashes[hashKey];
    if (expectedHash == null) {
      throw Exception(
        'No known hash for $hashKey. '
        'This target is not included in this release.\n'
        'See https://github.com/elias8/libghostty/releases/tag/$releaseTag',
      );
    }

    final bytes = file.readAsBytesSync();
    final digest = sha256.convert(bytes).toString();
    return digest == expectedHash;
  }
}
