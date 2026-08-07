import 'package:shared_preferences/shared_preferences.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'server_models.dart';

abstract interface class PrivacySettings {
  bool get hideServerAddresses;

  Future<void> saveHideServerAddresses(bool value);

  ServerViewMode get serverViewMode;

  Future<void> saveServerViewMode(ServerViewMode value);
}

class PrivacyPreferences implements PrivacySettings {
  PrivacyPreferences(
    this._preferences,
    this.hideServerAddresses,
    this.serverViewMode,
  );

  static const _hideServerAddressesKey = 'hide_server_addresses';
  static const _serverViewModeKey = 'server_view_mode';

  final SharedPreferencesAsync _preferences;
  @override
  final bool hideServerAddresses;
  @override
  final ServerViewMode serverViewMode;

  static Future<PrivacyPreferences> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final store = preferences ?? SharedPreferencesAsync();
    return PrivacyPreferences(
      store,
      await store.getBool(_hideServerAddressesKey) ?? false,
      ServerViewMode.values.asNameMap()[await store.getString(_serverViewModeKey)] ??
          ServerViewMode.grid,
    );
  }

  @override
  Future<void> saveHideServerAddresses(bool value) =>
      _preferences.setBool(_hideServerAddressesKey, value);

  @override
  Future<void> saveServerViewMode(ServerViewMode value) =>
      _preferences.setString(_serverViewModeKey, value.name);
}

class InMemoryPrivacySettings implements PrivacySettings {
  InMemoryPrivacySettings([this.hideServerAddresses = false]);

  @override
  bool hideServerAddresses;

  @override
  ServerViewMode serverViewMode = ServerViewMode.grid;

  @override
  Future<void> saveHideServerAddresses(bool value) async {
    hideServerAddresses = value;
  }

  @override
  Future<void> saveServerViewMode(ServerViewMode value) async {
    serverViewMode = value;
  }
}

/// The address line shown next to a server's name. When address hiding is on
/// (screen recording / streaming), only the username is displayed so no IP
/// ever appears on screen. Serial servers show the local device path instead.
String serverAddressLabel(Server server, {required bool hideAddresses}) {
  if (server.connectionType == ServerConnectionType.serial.name) {
    return decodeSerialConfig(server.serialConfig)?.device ?? server.host;
  }
  return hideAddresses
      ? server.username
      : '${server.username}@${server.host}:${server.port}';
}
