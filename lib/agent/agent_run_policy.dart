import 'package:shared_preferences/shared_preferences.dart';

/// How proposed agent actions are approved before they run.
enum AgentRunPolicy {
  alwaysApprove(
    'agentRunPolicyAlwaysApprove',
    'agentRunPolicyAlwaysApproveHint',
  ),
  autoReview('agentRunPolicyAutoReview', 'agentRunPolicyAutoReviewHint'),
  alwaysAsk('agentRunPolicyAlwaysAsk', 'agentRunPolicyAlwaysAskHint');

  const AgentRunPolicy(this.labelKey, this.descriptionKey);
  final String labelKey;
  final String descriptionKey;
}

abstract interface class AgentRunPolicySettings {
  AgentRunPolicy get policy;

  Future<void> savePolicy(AgentRunPolicy policy);
}

class AgentRunPolicyPreferences implements AgentRunPolicySettings {
  AgentRunPolicyPreferences(this._preferences, this.policy);

  static const _policyKey = 'agent_run_policy';
  final SharedPreferencesAsync _preferences;

  @override
  AgentRunPolicy policy;

  static Future<AgentRunPolicyPreferences> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final store = preferences ?? SharedPreferencesAsync();
    final name = await store.getString(_policyKey);
    return AgentRunPolicyPreferences(
      store,
      AgentRunPolicy.values.asNameMap()[name] ?? AgentRunPolicy.alwaysAsk,
    );
  }

  @override
  Future<void> savePolicy(AgentRunPolicy value) async {
    await _preferences.setString(_policyKey, value.name);
    policy = value;
  }
}

class InMemoryAgentRunPolicySettings implements AgentRunPolicySettings {
  InMemoryAgentRunPolicySettings({this.policy = AgentRunPolicy.alwaysAsk});

  @override
  AgentRunPolicy policy;

  @override
  Future<void> savePolicy(AgentRunPolicy value) async => policy = value;
}
