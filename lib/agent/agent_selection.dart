import 'package:shared_preferences/shared_preferences.dart';

/// The agent provider and model the user last selected in the agent page.
/// Saved so the selection survives restarts without being tied to a
/// conversation.
abstract interface class AgentSelectionSettings {
  int? get providerId;
  int? get modelId;

  Future<void> saveSelection({int? providerId, int? modelId});
}

class AgentSelectionPreferences implements AgentSelectionSettings {
  AgentSelectionPreferences(this._preferences, this.providerId, this.modelId);

  static const _providerIdKey = 'agent_selected_provider_id';
  static const _modelIdKey = 'agent_selected_model_id';
  final SharedPreferencesAsync _preferences;

  @override
  int? providerId;
  @override
  int? modelId;

  static Future<AgentSelectionPreferences> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final store = preferences ?? SharedPreferencesAsync();
    return AgentSelectionPreferences(
      store,
      await store.getInt(_providerIdKey),
      await store.getInt(_modelIdKey),
    );
  }

  @override
  Future<void> saveSelection({int? providerId, int? modelId}) async {
    this.providerId = providerId;
    this.modelId = modelId;
    if (providerId == null) {
      await _preferences.remove(_providerIdKey);
    } else {
      await _preferences.setInt(_providerIdKey, providerId);
    }
    if (modelId == null) {
      await _preferences.remove(_modelIdKey);
    } else {
      await _preferences.setInt(_modelIdKey, modelId);
    }
  }
}

class InMemoryAgentSelectionSettings implements AgentSelectionSettings {
  InMemoryAgentSelectionSettings({this.providerId, this.modelId});

  @override
  int? providerId;
  @override
  int? modelId;

  @override
  Future<void> saveSelection({int? providerId, int? modelId}) async {
    this.providerId = providerId;
    this.modelId = modelId;
  }
}
