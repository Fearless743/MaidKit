import 'package:shared_preferences/shared_preferences.dart';

abstract interface class TerminalAdapterSettings {
  String get selectedAdapterId;
  bool get cursorAnimationEnabled;
  String get colorSchemeId;
  bool get brandingEnvironmentEnabled;

  Future<void> saveSelectedAdapterId(String adapterId);
  Future<void> saveCursorAnimationEnabled(bool enabled);
  Future<void> saveColorSchemeId(String colorSchemeId);
  Future<void> saveBrandingEnvironmentEnabled(bool enabled);
}

class TerminalAdapterPreferences implements TerminalAdapterSettings {
  TerminalAdapterPreferences(
    this._preferences,
    this.selectedAdapterId,
    this.cursorAnimationEnabled,
    this.colorSchemeId,
    this.brandingEnvironmentEnabled,
  );

  static const _adapterIdKey = 'terminal_adapter_id';
  static const _cursorAnimationEnabledKey = 'cursor_animation_enabled';
  static const _colorSchemeIdKey = 'terminal_color_scheme_id';
  static const _brandingEnvironmentEnabledKey =
      'terminal_branding_environment_enabled';

  final SharedPreferencesAsync _preferences;
  @override
  final String selectedAdapterId;
  @override
  final bool cursorAnimationEnabled;
  @override
  final String colorSchemeId;
  @override
  final bool brandingEnvironmentEnabled;

  static Future<TerminalAdapterPreferences> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final store = preferences ?? SharedPreferencesAsync();
    return TerminalAdapterPreferences(
      store,
      await store.getString(_adapterIdKey) ?? 'ghostty',
      await store.getBool(_cursorAnimationEnabledKey) ?? true,
      await store.getString(_colorSchemeIdKey) ?? 'default',
      await store.getBool(_brandingEnvironmentEnabledKey) ?? true,
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

  @override
  Future<void> saveBrandingEnvironmentEnabled(bool enabled) =>
      _preferences.setBool(_brandingEnvironmentEnabledKey, enabled);
}

class InMemoryTerminalAdapterSettings implements TerminalAdapterSettings {
  InMemoryTerminalAdapterSettings({
    this.selectedAdapterId = 'ghostty',
    this.cursorAnimationEnabled = true,
    this.colorSchemeId = 'default',
    this.brandingEnvironmentEnabled = true,
  });

  @override
  String selectedAdapterId;
  @override
  bool cursorAnimationEnabled;
  @override
  String colorSchemeId;
  @override
  bool brandingEnvironmentEnabled;

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

  @override
  Future<void> saveBrandingEnvironmentEnabled(bool enabled) async {
    brandingEnvironmentEnabled = enabled;
  }
}
