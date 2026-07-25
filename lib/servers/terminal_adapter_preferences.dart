import 'package:shared_preferences/shared_preferences.dart';

abstract interface class TerminalAdapterSettings {
  String get selectedAdapterId;
  bool get cursorAnimationEnabled;
  String get colorSchemeId;

  Future<void> saveSelectedAdapterId(String adapterId);
  Future<void> saveCursorAnimationEnabled(bool enabled);
  Future<void> saveColorSchemeId(String colorSchemeId);
}

class TerminalAdapterPreferences implements TerminalAdapterSettings {
  TerminalAdapterPreferences(
    this._preferences,
    this.selectedAdapterId,
    this.cursorAnimationEnabled,
    this.colorSchemeId,
  );

  static const _adapterIdKey = 'terminal_adapter_id';
  static const _cursorAnimationEnabledKey = 'cursor_animation_enabled';
  static const _colorSchemeIdKey = 'terminal_color_scheme_id';

  final SharedPreferencesAsync _preferences;
  @override
  final String selectedAdapterId;
  @override
  final bool cursorAnimationEnabled;
  @override
  final String colorSchemeId;

  static Future<TerminalAdapterPreferences> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final store = preferences ?? SharedPreferencesAsync();
    return TerminalAdapterPreferences(
      store,
      await store.getString(_adapterIdKey) ?? 'ghostty',
      await store.getBool(_cursorAnimationEnabledKey) ?? true,
      await store.getString(_colorSchemeIdKey) ?? 'default',
    );
  }

  @override
  Future<void> saveSelectedAdapterId(String adapterId) =>
      _preferences.setString(_adapterIdKey, adapterId);

  @override
  Future<void> saveCursorAnimationEnabled(bool enabled) =>
      _preferences.setBool(_cursorAnimationEnabledKey, enabled);

  @override
  Future<void> saveColorSchemeId(String colorSchemeId) =>
      _preferences.setString(_colorSchemeIdKey, colorSchemeId);
}

class InMemoryTerminalAdapterSettings implements TerminalAdapterSettings {
  InMemoryTerminalAdapterSettings({
    this.selectedAdapterId = 'ghostty',
    this.cursorAnimationEnabled = true,
    this.colorSchemeId = 'default',
  });

  @override
  String selectedAdapterId;
  @override
  bool cursorAnimationEnabled;
  @override
  String colorSchemeId;

  @override
  Future<void> saveSelectedAdapterId(String adapterId) async {
    selectedAdapterId = adapterId;
  }

  @override
  Future<void> saveCursorAnimationEnabled(bool enabled) async {
    cursorAnimationEnabled = enabled;
  }

  @override
  Future<void> saveColorSchemeId(String colorSchemeId) async {
    this.colorSchemeId = colorSchemeId;
  }
}
