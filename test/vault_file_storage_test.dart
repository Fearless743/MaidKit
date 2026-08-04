import 'package:flutter_test/flutter_test.dart';
import 'package:maid_kit/servers/vault_file_storage.dart';

void main() {
  final storage = VaultFileStorage();

  group('VaultFileStorage.fileName', () {
    test('returns the basename for native Windows separators', () {
      expect(
        storage.fileName(r'C:\Users\Me\Documents\vaults\a.maidkit'),
        'a.maidkit',
      );
    });

    test('returns the basename for forward-slash managed paths', () {
      expect(
        storage.fileName('C:/Users/Me/Documents/vaults/a.maidkit'),
        'a.maidkit',
      );
    });

    test('returns the path itself when it has no separators', () {
      expect(storage.fileName('a.maidkit'), 'a.maidkit');
    });
  });

  group('VaultFileStorage.isInDirectory', () {
    test('recognizes a managed vault when separators differ', () {
      // path_provider reports Documents with '\' on Windows while managed
      // vault paths are built with '/'; both must count as in-directory.
      expect(
        storage.isInDirectory(
          'C:/Users/Me/Documents/vaults/a.maidkit',
          r'C:\Users\Me\Documents',
        ),
        isTrue,
      );
    });

    test('recognizes a managed vault with matching separators', () {
      expect(
        storage.isInDirectory(
          r'C:\Users\Me\Documents\vaults\a.maidkit',
          r'C:\Users\Me\Documents',
        ),
        isTrue,
      );
      expect(
        storage.isInDirectory(
          'C:/Users/Me/Documents/vaults/a.maidkit',
          'C:/Users/Me/Documents',
        ),
        isTrue,
      );
    });

    test('tolerates a trailing separator on the directory', () {
      expect(
        storage.isInDirectory(
          'C:/Users/Me/Documents/vaults/a.maidkit',
          r'C:\Users\Me\Documents\',
        ),
        isTrue,
      );
    });

    test('rejects files outside the directory', () {
      expect(
        storage.isInDirectory(
          'C:/Users/Me/Other/a.maidkit',
          'C:/Users/Me/Documents',
        ),
        isFalse,
      );
    });

    test('rejects sibling paths that merely share a prefix', () {
      expect(
        storage.isInDirectory(
          'C:/Users/Me/DocumentsVaults/a.maidkit',
          'C:/Users/Me/Documents',
        ),
        isFalse,
      );
    });
  });
}
