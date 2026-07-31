import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Whether the agent prompt input currently holds keyboard focus.
///
/// The workspace shell watches this so it can hide the bottom navigation bar
/// while the user is composing a prompt on narrow layouts.
final agentInputFocusedProvider =
    NotifierProvider<AgentInputFocusNotifier, bool>(
      AgentInputFocusNotifier.new,
    );

class AgentInputFocusNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setFocused(bool value) {
    if (state == value) return;
    state = value;
  }
}
