import 'package:shared_preferences/shared_preferences.dart';

abstract interface class TerminalAdapterSettings {
  String get selectedAdapterId;

  Future<void> saveSelectedAdapterId(String adapterId);
}

class TerminalAdapterPreferences implements TerminalAdapterSettings {
  TerminalAdapterPreferences(this._preferences, this.selectedAdapterId);

  static const _adapterIdKey = 'terminal_adapter_id';

  final SharedPreferencesAsync _preferences;
  @override
  final String selectedAdapterId;

  static Future<TerminalAdapterPreferences> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final store = preferences ?? SharedPreferencesAsync();
    return TerminalAdapterPreferences(
      store,
      await store.getString(_adapterIdKey) ?? 'xterm',
    );
  }

  @override
  Future<void> saveSelectedAdapterId(String adapterId) =>
      _preferences.setString(_adapterIdKey, adapterId);
}

class InMemoryTerminalAdapterSettings implements TerminalAdapterSettings {
  InMemoryTerminalAdapterSettings([this.selectedAdapterId = 'xterm']);

  @override
  String selectedAdapterId;

  @override
  Future<void> saveSelectedAdapterId(String adapterId) async {
    selectedAdapterId = adapterId;
  }
}
