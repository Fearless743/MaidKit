/// Cancellation token for an in-flight agent operation. The UI calls [cancel]
/// and registered callbacks (HTTP client close, SSH session close, MCP call
/// abort) run immediately. Lives in its own file so the MCP client can use it
/// without importing the SSH service.
class AgentCancelToken {
  final _callbacks = <void Function()>[];
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void register(void Function() callback) => _callbacks.add(callback);

  void unregister(void Function() callback) => _callbacks.remove(callback);

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final callback in _callbacks.toList()) {
      callback();
    }
  }

  void throwIfCancelled() {
    if (_cancelled) throw const AgentCancelledException();
  }
}

class AgentCancelledException implements Exception {
  const AgentCancelledException();
  @override
  String toString() => 'AgentCancelledException';
}
