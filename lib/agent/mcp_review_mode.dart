import 'package:shared_preferences/shared_preferences.dart';

/// How actions requested through the local MCP server are approved before
/// they run.
///
/// Deliberately separate from the in-app chat agent's run policy
/// ([AgentRunPolicy]): the user may want agents connected over MCP to stay
/// on a stricter (or looser) leash than the agent they chat with in the app.
enum McpReviewMode {
  alwaysAsk('mcpReviewModeAlwaysAsk', 'mcpReviewModeAlwaysAskHint'),
  autoReview('mcpReviewModeAutoReview', 'mcpReviewModeAutoReviewHint'),
  alwaysApprove('mcpReviewModeAlwaysApprove', 'mcpReviewModeAlwaysApproveHint');

  const McpReviewMode(this.labelKey, this.descriptionKey);

  final String labelKey;
  final String descriptionKey;

  /// Wire name used by the `get_review_mode` / `set_review_mode` MCP tools.
  String get wireName => switch (this) {
    McpReviewMode.alwaysAsk => 'always_ask',
    McpReviewMode.autoReview => 'auto_review',
    McpReviewMode.alwaysApprove => 'always_approve',
  };

  /// Inverse of [wireName]. Throws [ArgumentError] for unknown names so a
  /// malformed `set_review_mode` call fails loudly instead of silently
  /// changing nothing.
  static McpReviewMode fromWireName(String name) => switch (name) {
    'always_ask' => McpReviewMode.alwaysAsk,
    'auto_review' => McpReviewMode.autoReview,
    'always_approve' => McpReviewMode.alwaysApprove,
    _ => throw ArgumentError(
      'Unknown review mode "$name". Use one of: always_ask, auto_review, '
      'always_approve.',
    ),
  };
}

abstract interface class McpReviewModeSettings {
  McpReviewMode get mode;

  Future<void> saveMode(McpReviewMode mode);
}

/// Persisted MCP review mode. Plain app preference, no secrets.
class McpReviewModePreferences implements McpReviewModeSettings {
  McpReviewModePreferences(this._preferences, this.mode);

  static const _modeKey = 'local_mcp_review_mode';
  final SharedPreferencesAsync _preferences;

  @override
  McpReviewMode mode;

  static Future<McpReviewModePreferences> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final store = preferences ?? SharedPreferencesAsync();
    final name = await store.getString(_modeKey);
    return McpReviewModePreferences(
      store,
      McpReviewMode.values.asNameMap()[name] ?? McpReviewMode.alwaysAsk,
    );
  }

  @override
  Future<void> saveMode(McpReviewMode value) async {
    await _preferences.setString(_modeKey, value.name);
    mode = value;
  }
}

class InMemoryMcpReviewModeSettings implements McpReviewModeSettings {
  InMemoryMcpReviewModeSettings({this.mode = McpReviewMode.alwaysAsk});

  @override
  McpReviewMode mode;

  @override
  Future<void> saveMode(McpReviewMode value) async => mode = value;
}
