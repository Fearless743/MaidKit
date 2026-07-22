# MaidKit patches

This copy is based on `elias8/libghostty` 0.0.11.

For iOS, `packages/libghostty/lib/src/hook/library_provider.dart` bypasses the
prebuilt binary and builds `libghostty-vt` locally with Apple's linker and
`-encryptable`. This emits the `LC_ENCRYPTION_INFO` load command required by
App Store Connect (upstream issue #111).

Remove this patch and return to the published package after upstream ships an
equivalent fix.
