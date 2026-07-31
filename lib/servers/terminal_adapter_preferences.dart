import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'terminal_color_scheme.dart';

abstract interface class TerminalAdapterSettings {
  String get selectedAdapterId;
  bool get cursorAnimationEnabled;
  bool get brandingEnvironmentEnabled;
  TerminalColorScheme get lightTheme;
  TerminalColorScheme get darkTheme;

  Future<void> saveSelectedAdapterId(String adapterId);
  Future<void> saveCursorAnimationEnabled(bool enabled);
  Future<void> saveBrandingEnvironmentEnabled(bool enabled);
  Future<void> saveLightTheme(TerminalColorScheme theme);
  Future<void> saveDarkTheme(TerminalColorScheme theme);
}

class TerminalAdapterPreferences implements TerminalAdapterSettings {
  TerminalAdapterPreferences(
    this._preferences,
    this.selectedAdapterId,
    this.cursorAnimationEnabled,
    this.brandingEnvironmentEnabled,
    this.lightTheme,
    this.darkTheme,
  );

  static const _adapterIdKey = 'terminal_adapter_id';
  static const _cursorAnimationEnabledKey = 'cursor_animation_enabled';
  static const _brandingEnvironmentEnabledKey =
      'terminal_branding_environment_enabled';
  static const _lightThemeKey = 'terminal_light_theme';
  static const _darkThemeKey = 'terminal_dark_theme';

  final SharedPreferencesAsync _preferences;
  @override
  final String selectedAdapterId;
  @override
  final bool cursorAnimationEnabled;
  @override
  final bool brandingEnvironmentEnabled;
  @override
  final TerminalColorScheme lightTheme;
  @override
  final TerminalColorScheme darkTheme;

  static Future<TerminalAdapterPreferences> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final store = preferences ?? SharedPreferencesAsync();
    return TerminalAdapterPreferences(
      store,
      await store.getString(_adapterIdKey) ?? 'ghostty',
      await store.getBool(_cursorAnimationEnabledKey) ?? true,
      await store.getBool(_brandingEnvironmentEnabledKey) ?? true,
      _decodeTheme(await store.getString(_lightThemeKey)) ??
          TerminalColorSchemes.defaultLightScheme,
      _decodeTheme(await store.getString(_darkThemeKey)) ??
          TerminalColorSchemes.defaultScheme,
    );
  }

  @override
  Future<void> saveSelectedAdapterId(String adapterId) =>
      _preferences.setString(_adapterIdKey, adapterId);

  @override
  Future<void> saveCursorAnimationEnabled(bool enabled) =>
      _preferences.setBool(_cursorAnimationEnabledKey, enabled);

  @override
  Future<void> saveBrandingEnvironmentEnabled(bool enabled) =>
      _preferences.setBool(_brandingEnvironmentEnabledKey, enabled);

  @override
  Future<void> saveLightTheme(TerminalColorScheme theme) =>
      _preferences.setString(_lightThemeKey, _encodeTheme(theme));

  @override
  Future<void> saveDarkTheme(TerminalColorScheme theme) =>
      _preferences.setString(_darkThemeKey, _encodeTheme(theme));

  static String _encodeTheme(TerminalColorScheme theme) => jsonEncode({
    'id': theme.id,
    'label': theme.label,
    'background': theme.background.toARGB32(),
    'foreground': theme.foreground.toARGB32(),
    'cursor': theme.cursor.toARGB32(),
    'selection': theme.selection.toARGB32(),
    'ansi': theme.ansiColors.map((color) => color.toARGB32()).toList(),
  });

  static TerminalColorScheme? _decodeTheme(String? encoded) {
    if (encoded == null) return null;
    try {
      final json = jsonDecode(encoded) as Map<String, dynamic>;
      final ansi = (json['ansi'] as List<dynamic>)
          .map((value) => Color(value as int))
          .toList();
      return TerminalColorScheme(
        id: json['id'] as String? ?? 'custom',
        label: json['label'] as String? ?? 'Custom',
        background: Color(json['background'] as int),
        foreground: Color(json['foreground'] as int),
        cursor: Color(json['cursor'] as int),
        selection: Color(json['selection'] as int),
        ansiColors: ansi,
      );
    } catch (_) {
      return null;
    }
  }
}

class InMemoryTerminalAdapterSettings implements TerminalAdapterSettings {
  InMemoryTerminalAdapterSettings({
    this.selectedAdapterId = 'ghostty',
    this.cursorAnimationEnabled = true,
    this.brandingEnvironmentEnabled = true,
    this.lightTheme = TerminalColorSchemes.defaultLightScheme,
    this.darkTheme = TerminalColorSchemes.defaultScheme,
  });

  @override
  String selectedAdapterId;
  @override
  bool cursorAnimationEnabled;
  @override
  bool brandingEnvironmentEnabled;
  @override
  TerminalColorScheme lightTheme;
  @override
  TerminalColorScheme darkTheme;

  @override
  Future<void> saveSelectedAdapterId(String adapterId) async {
    selectedAdapterId = adapterId;
  }

  @override
  Future<void> saveCursorAnimationEnabled(bool enabled) async {
    cursorAnimationEnabled = enabled;
  }

  @override
  Future<void> saveBrandingEnvironmentEnabled(bool enabled) async {
    brandingEnvironmentEnabled = enabled;
  }

  @override
  Future<void> saveLightTheme(TerminalColorScheme theme) async {
    lightTheme = theme;
  }

  @override
  Future<void> saveDarkTheme(TerminalColorScheme theme) async {
    darkTheme = theme;
  }
}
