# MaidKit patches

This copy is based on `elias8/libghostty` 0.0.11.

For iOS, `lib/src/hook/library_provider.dart` bypasses the prebuilt binary,
builds Ghostty's static archive with Zig, then links it into a dynamic library
with Xcode's clang and Apple's `ld -encryptable`. `hook/build.dart` then
verifies the resulting binary contains `LC_ENCRYPTION_INFO_64`, the load
command required by App Store Connect (upstream issue #111).

Remove this patch and return to the published package after upstream ships an
equivalent fix.
