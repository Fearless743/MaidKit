import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Resource categories that can be assembled into one deployment project.
/// Unknown kinds are preserved during import/export for forward compatibility.
enum DeploymentResourceKind {
  server,
  serverFolder,
  container,
  compose,
  webServer,
  firewallRule,
  systemdService,
  database,
  other,
}

DeploymentResourceKind deploymentResourceKindFromId(String id) {
  return DeploymentResourceKind.values.firstWhere(
    (kind) => kind.name == id,
    orElse: () => DeploymentResourceKind.other,
  );
}

/// Short label for UI chips, cards, and resource lists.
String deploymentResourceKindLabel(DeploymentResourceKind kind) =>
    switch (kind) {
      DeploymentResourceKind.server => 'Server',
      DeploymentResourceKind.serverFolder => 'Folder',
      DeploymentResourceKind.compose => 'Compose',
      DeploymentResourceKind.container => 'Container',
      DeploymentResourceKind.webServer => 'Web server',
      DeploymentResourceKind.firewallRule => 'Firewall',
      DeploymentResourceKind.systemdService => 'Systemd',
      DeploymentResourceKind.database => 'Database',
      DeploymentResourceKind.other => 'Other',
    };

IconData deploymentResourceKindIcon(DeploymentResourceKind kind) =>
    switch (kind) {
      DeploymentResourceKind.server => Symbols.dns,
      DeploymentResourceKind.serverFolder => Symbols.folder,
      DeploymentResourceKind.compose => Symbols.deployed_code,
      DeploymentResourceKind.container => Symbols.deployed_code,
      DeploymentResourceKind.webServer => Symbols.language,
      DeploymentResourceKind.firewallRule => Symbols.security,
      DeploymentResourceKind.systemdService => Symbols.settings,
      DeploymentResourceKind.database => Symbols.database,
      DeploymentResourceKind.other => Symbols.extension,
    };

/// Compact one-line summary of portable configuration for list tiles.
String deploymentResourceConfigSummary(Map<String, Object?> config) {
  final parts = <String>[];
  void add(String key, {String? label}) {
    final value = config[key];
    if (value == null) return;
    final text = '$value'.trim();
    if (text.isEmpty) return;
    parts.add(label == null ? text : '$label: $text');
  }

  add('path');
  add('container');
  add('compose_project', label: 'project');
  add('directory');
  add('runtime');
  add('scope');
  add('unit');
  add('rule');
  add('service_unit');
  add('config_path');
  add('adapter_id', label: 'adapter');
  if (parts.isEmpty) return '';
  return parts.take(3).join(' · ');
}

class DeploymentProjectBundle {
  const DeploymentProjectBundle({
    required this.name,
    this.description,
    this.resources = const [],
  });

  final String name;
  final String? description;
  final List<DeploymentResourceBundle> resources;
}

class DeploymentResourceBundle {
  const DeploymentResourceBundle({
    required this.kind,
    required this.name,
    this.serverId,
    this.configuration = const {},
  });

  final String kind;
  final String name;
  final int? serverId;
  final Map<String, Object?> configuration;

  String get configurationJson => jsonEncode(configuration);
}
