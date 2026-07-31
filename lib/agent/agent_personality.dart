import 'package:shared_preferences/shared_preferences.dart';

/// User-authored guidance appended to the agent's system prompt.
abstract interface class AgentPersonalitySettings {
  String get personality;

  Future<void> savePersonality(String personality);
}

class AgentPersonalityPreferences implements AgentPersonalitySettings {
  AgentPersonalityPreferences(this._preferences, this.personality);

  static const _personalityKey = 'agent_personality';
  final SharedPreferencesAsync _preferences;

  @override
  String personality;

  static Future<AgentPersonalityPreferences> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final store = preferences ?? SharedPreferencesAsync();
    return AgentPersonalityPreferences(
      store,
      (await store.getString(_personalityKey) ?? '').trim(),
    );
  }

  @override
  Future<void> savePersonality(String value) async {
    personality = value.trim();
    if (personality.isEmpty) {
      await _preferences.remove(_personalityKey);
    } else {
      await _preferences.setString(_personalityKey, personality);
    }
  }
}

class InMemoryAgentPersonalitySettings implements AgentPersonalitySettings {
  InMemoryAgentPersonalitySettings({this.personality = ''});

  @override
  String personality;

  @override
  Future<void> savePersonality(String value) async =>
      personality = value.trim();
}

/// The PersonalityCore agent used by the managed Solar Network provider. The
/// user can override the default in settings; the agent page never lets the
/// agent change inline.
abstract interface class AgentPersonalityAgentSettings {
  String get agentId;

  Future<void> saveAgentId(String agentId);
}

class AgentPersonalityAgentPreferences
    implements AgentPersonalityAgentSettings {
  AgentPersonalityAgentPreferences(this._preferences, this.agentId);

  static const defaultAgentId = 'server-maid';
  static const _agentIdKey = 'agent_personality_agent';
  final SharedPreferencesAsync _preferences;

  @override
  String agentId;

  static Future<AgentPersonalityAgentPreferences> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final store = preferences ?? SharedPreferencesAsync();
    final stored = (await store.getString(_agentIdKey) ?? '').trim();
    return AgentPersonalityAgentPreferences(
      store,
      stored.isEmpty ? defaultAgentId : stored,
    );
  }

  @override
  Future<void> saveAgentId(String value) async {
    agentId = value.trim();
    if (agentId.isEmpty) {
      await _preferences.remove(_agentIdKey);
    } else {
      await _preferences.setString(_agentIdKey, agentId);
    }
  }
}

class InMemoryAgentPersonalityAgentSettings
    implements AgentPersonalityAgentSettings {
  InMemoryAgentPersonalityAgentSettings({
    this.agentId = AgentPersonalityAgentPreferences.defaultAgentId,
  });

  @override
  String agentId;

  @override
  Future<void> saveAgentId(String value) async => agentId = value.trim();
}
