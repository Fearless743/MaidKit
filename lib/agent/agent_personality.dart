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
