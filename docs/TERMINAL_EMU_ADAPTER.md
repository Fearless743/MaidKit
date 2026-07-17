# Terminal emulator adapter plan

## Purpose

MaidKit currently uses `xterm` for its Flutter terminal widget and
`dartssh2` for the SSH transport. Keep SSH lifecycle, PTY ownership, and
terminal rendering separable so another emulator core—such as
`libghostty`—can be evaluated without changing saved servers or live SSH
session behavior.

## Target boundary

Introduce a small terminal adapter contract in `lib/servers/`:

- `TerminalSessionAdapter` owns one terminal emulator instance for one SSH
  shell.
- It accepts incoming bytes from `SSHSession.stdout` and `stderr`.
- It exposes outgoing terminal bytes for `SSHSession.write`.
- It reports column/row and pixel resize events for
  `SSHSession.resizeTerminal`.
- It owns terminal-specific cleanup and exposes a renderer widget or render
  state to the Sessions UI.

`SshConnectionManager` remains transport-only: it opens the authenticated
`SSHSession`, wires its streams to an adapter, and closes all shells when the
parent SSH client disconnects. `SessionsPage` receives an adapter-backed view
and must not import a concrete emulator package.

## First extraction: xterm adapter

When terminal work resumes, move the current `Terminal`, `TerminalView`,
output callback, and resize callback behind `XtermTerminalSessionAdapter`.

- Preserve `xterm-256color`, 10,000 scrollback lines, UTF-8 decoding, and
  the current in-memory lifecycle.
- Move `TerminalView` out of `SessionsPage`; the page renders the adapter’s
  supplied view instead.
- Keep the adapter factory in a Riverpod provider so tests can substitute a
  fake terminal without SSH or Flutter rendering.
- Do not change the Drift schema, credential vault, server records, or host
  fingerprint behavior.

## Future libghostty evaluation

`libghostty` supplies Ghostty VT state and PTY/input callbacks, but not a
drop-in Flutter renderer. Before adopting it, implement a prototype adapter
and renderer with the same contract as the xterm adapter.

Compare both implementations using representative workloads:

- Interactive shell startup, `vim`/`htop`-style full-screen updates, ANSI
  colour, Unicode/CJK, resize handling, mouse input, selection, copy/paste,
  and scrollback.
- Frame time, memory at 10,000+ lines, CPU while idle and under output load,
  and behavior on macOS, Windows, and Linux.
- Input correctness for modifiers, IME, bracketed paste, and terminal escape
  sequences.

Adopt libghostty only if its renderer reaches feature parity and demonstrates
a material performance or correctness improvement on the supported desktop
platforms. Keep `xterm` as the production fallback until then.

## Acceptance criteria for the extraction

- Connecting, disconnecting, host-key verification, and saved-server behavior
  are unchanged.
- A terminal adapter can be replaced through provider overrides in tests.
- Terminal integration tests cover output forwarding, keyboard input, resize,
  shell closure, and cleanup on SSH disconnect.
- The Sessions UI contains no emulator-specific imports.
