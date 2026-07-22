import 'package:shared_preferences/shared_preferences.dart';

abstract interface class TerminalAdapterSettings {
  String get selectedAdapterId;
  bool get cursorAnimationEnabled;

  Future<void> saveSelectedAdapterId(String adapterId);
  Future<void> saveCursorAnimationEnabled(bool enabled);
}

class TerminalAdapterPreferences implements TerminalAdapterSettings {
  TerminalAdapterPreferences(
    this._preferences,
    this.selectedAdapterId,
    this.cursorAnimationEnabled,
  );

  static const _adapterIdKey = 'terminal_adapter_id';
  static const _cursorAnimationEnabledKey = 'cursor_animation_enabled';

  final SharedPreferencesAsync _preferences;
  @override
  final String selectedAdapterId;
  @override
  final bool cursorAnimationEnabled;

  static Future<TerminalAdapterPreferences> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final store = preferences ?? SharedPreferencesAsync();
    return TerminalAdapterPreferences(
      store,
      'xterm',
      await store.getBool(_cursorAnimationEnabledKey) ?? true,
    );
  }

  @override
  Future<void> saveSelectedAdapterId(String adapterId) =>
      _preferences.setString(_adapterIdKey, adapterId);

  @override
  Future<void> saveCursorAnimationEnabled(bool enabled) =>
      _preferences.setBool(_cursorAnimationEnabledKey, enabled);
}

class InMemoryTerminalAdapterSettings implements TerminalAdapterSettings {
  InMemoryTerminalAdapterSettings({
    this.selectedAdapterId = 'xterm',
    this.cursorAnimationEnabled = true,
  });

  @override
  String selectedAdapterId;
  @override
  bool cursorAnimationEnabled;

  @override
  Future<void> saveSelectedAdapterId(String adapterId) async {
    selectedAdapterId = adapterId;
  }

  @override
  Future<void> saveCursorAnimationEnabled(bool enabled) async {
    cursorAnimationEnabled = enabled;
  }
}
